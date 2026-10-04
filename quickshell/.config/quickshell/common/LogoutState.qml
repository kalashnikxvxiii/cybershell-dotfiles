pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick


QtObject {
    id: root

    // ── Visibility + state ──────────────────────────────────
    property bool   visible:        false
    property int    activeIndex:    0
    property int    pendingAction: -1
    property string focusedScreen:  ""  // nome monitor col mouse (snapshot on open)

    function toggle() {
        root.visible = !root.visible
        if (root.visible) _onOpen()
    }

    function open() {
        root.visible = true
        _onOpen()
    }

    function close() {
        root.visible       = false
        root.pendingAction = -1
    }

    function _onOpen() {
        root.activeIndex        = 0
        root.pendingAction      = -1
        _focusedMonQuery.running = true
    }

    function invokeIndex(idx) {
        if (idx < 0 || idx >= actions.length) return
        var act = actions[idx]
        if (act.isDanger) root.pendingAction = idx
        else              _doInvoke(idx)
    }

    function invokeById(id) {
        for (var i = 0; i < actions.length; i++) {
            if (actions[i].id === id) { invokeIndex(i); return }
        }
    }

    function confirmPending() {
        if (root.pendingAction < 0) return
        _doInvoke(root.pendingAction)
    }

    function cancelPending() {
        root.pendingAction = -1
    }

    function _shellEscape(arg) {
        return "'" + String(arg).replace(/'/g, "'\\''") + "'"
    }

    function _soundForAction(id) {
        if (id === "lock")                          return "window-minimize"
        return null
    }

    function _doInvoke(idx) {
        var act = actions[idx]
        root.visible       = false
        root.pendingAction = -1

        var sound = _soundForAction(act.id)
        if (!sound) {
            Quickshell.execDetached(act.command)
            return
        }

        var escaped = act.command.map(_shellEscape).join(" ")
        var wait = (act.id === "lock") ? "" : "sleep 2.5 && "
        Quickshell.execDetached(["sh", "-c",
        "canberra-gtk-play -i " + sound +
        " --property=canberra.xdg-theme.name=cyberpunk-2077 & " +
        wait + "exec " + escaped])
    }

    readonly property var actions: [
        { id: "lock",      label: "LOCK",      shortcut: "L", command: ["hyprlock"],                    isDanger: false },
        { id: "logout",    label: "LOGOUT",    shortcut: "E", command: ["hyprctl", "dispatch", "exit"], isDanger: false },
        { id: "suspend",   label: "SUSPEND",   shortcut: "U", command: ["systemctl", "suspend"],        isDanger: false },
        { id: "hibernate", label: "HIBERNATE", shortcut: "H", command: ["systemctl", "hibernate"],      isDanger: false },
        { id: "reboot",    label: "REBOOT",    shortcut: "R", command: ["systemctl", "reboot"],         isDanger: true  },
        { id: "shutdown",  label: "SHUTDOWN",  shortcut: "S", command: ["systemctl", "poweroff"],       isDanger: true  }
    ]

    // ── Focused monitor detection via hyprctl (on open) ─────
    property Process _focusedMonQuery: Process {
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var arr = JSON.parse(this.text)
                    for (var m of arr) {
                        if (m.focused) {
                            root.focusedScreen = m.name
                            return
                        }
                    }
                } catch (e) {
                    console.warn("LogoutState: focused monitor parse failed:", e)
                }
            }
        }
    }

    // ── IPC trigger via file watch ──────────────────────────
    property FileView _toggleWatch: FileView {
        path: "/tmp/qs-logout-toggle"
        watchChanges: true
        onFileChanged: { reload(); root.toggle() }
    }
}
