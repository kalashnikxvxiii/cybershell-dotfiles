// QuickWheel.qml -- radial menu over the Hyprland submaps of keybindings-v2.lua.
//
// Hyprland owns the menus: the keys are real submap binds and they work even if
// the shell is down. The wheel only shows them (read from `hyprctl binds`, so
// there is no second list to keep in sync) and adds the mouse. It takes no
// keyboard focus and the surface exists only while a menu is open.
//
// Driven from Lua through `qs ipc call wheel`.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../common"
import "../../common/effects"
import "../../common/Colors.js" as CP

Scope {
    id: root

    property string menu: ""
    property string screenName: ""
    property var items: []
    property string selectedKey: ""
    property bool wanted: false
    property bool shown: false

    readonly property var accents: ({
        "wallpaper": CP.cyan,
        "look": CP.magenta,
        "system": CP.red
    })

    function dismiss() {
        wanted = false
        shown = false
    }

    function cancel() {
        dismiss()
        HL.dispatch('hl.dsp.submap("reset")')
    }

    // Hold the selected card on screen for a moment before the exit glitch
    function select(key) {
        flashHold.stop()
        if (selectedKey === key) return
        selectedKey = key
        wanted = false
        selectHold.restart()
    }

    function pick(key) {
        HL.run('HL_MENU_FIRE("' + menu + '", "' + key + '")')
    }

    IpcHandler {
        target: "wheel"

        function open(name: string, screen: string): void {
            selectHold.stop()
            flashHold.stop()
            root.selectedKey = ""
            root.screenName = screen
            root.menu = name
            root.wanted = true
            bindsReader.running = true
        }

        function pick(key: string): void {
            root.select(key)
        }

        // For actions that keep the menu open: same highlight, no exit
        function flash(key: string): void {
            root.selectedKey = key
            flashHold.restart()
        }

        function close(): void {
            root.dismiss()
        }
    }

    Timer {
        id: selectHold
        interval: 170
        onTriggered: root.shown = false
    }

    Timer {
        id: flashHold
        interval: 320
        onTriggered: root.selectedKey = ""
    }

    Process {
        id: bindsReader
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.wanted) return
                root.items = JSON.parse(text)
                    .filter(b => b.submap === root.menu && b.key !== "escape")
                    .map(b => ({ key: b.key, label: b.description.split("|")[1] || b.description }))
                root.shown = root.items.length > 0
            }
        }
    }

    PanelWindow {
        screen: Quickshell.screens.find(s => s.name === root.screenName) || null
        visible: root.shown || fx.visible
        color: "transparent"

        WlrLayershell.namespace: "qs-wheel"
        // Overlay, so the wheel also reaches a fullscreen window
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors { top: true; bottom: true; left: true; right: true }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 6/255, 14/255, 0.35)
            opacity: root.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: root.cancel()
            }
        }

        GlitchReveal {
            id: fx
            anchors.centerIn: parent
            width: 860
            height: 560
            shown: root.shown

            WheelFace {
                anchors.fill: parent
                items: root.items
                title: root.menu
                accent: root.accents[root.menu] || CP.cyan
                selectedKey: root.selectedKey
                onPicked: key => root.pick(key)
                onCancelled: root.cancel()
            }
        }
    }
}
