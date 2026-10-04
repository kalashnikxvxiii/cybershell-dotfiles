pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // -- State ------------------
    // Monitors name array currently hidden. Screen visible if not included
    property var hiddenScreens: []

    // Workspace under the cursor, for preview. Runtime-only
    property var previewWorkspace: null

    // Cursor hover preview's popup: avoid closing
    property bool previewPopupHovered: false

    // -- Query API (used in bindings) ---------------
    function isVisibleOn(screenName) {
        return root.hiddenScreens.indexOf(screenName) === -1
    }

    // -- Actions ------------------
    function toggleFocused() { _focusedQuery.running = true }

    function toggleAll() {
        if (root.hiddenScreens.length > 0) {
            root.hiddenScreens = []
        } else {
            var names = []
            for (var i = 0; i < Quickshell.screens.length; i++)
                names.push(Quickshell.screens[i].name)
            root.hiddenScreens = names
        }
    }

    function showAll() { root.hiddenScreens = [] }

    function _flipScreen(name) {
        var next = root.hiddenScreens.slice()
        var idx = next.indexOf(name)
        if (idx >= 0) next.splice(idx, 1)
        else next.push(name)
        root.hiddenScreens = next
    }

    // -- Hyprland: figure out which monitor has the cursor -----------------
    Process {
        id: _focusedQuery
        command: ["hyprctl", "monitors", "-j"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var monitors = JSON.parse(text)
                    for (var i = 0; i < monitors.length; i++) {
                        if (monitors[i].focused) {
                            root._flipScreen(monitors[i].name)
                            return
                        }
                    }
                } catch (e) { console.warn("Barstate focused query failed:", e) }
            }
        }
    }

    // -- IPC: touch triggers ------------------------------------
    FileView {
        path: "/tmp/qs-bar-toggle-focused"
        watchChanges: true
        onFileChanged: { reload(); root.toggleFocused() }
    }
    FileView {
        path: "/tmp/qs-bar-toggle-all"
        watchChanges: true
        onFileChanged: { reload(); root.toggleAll() }
    }
}