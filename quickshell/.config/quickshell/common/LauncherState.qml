pragma Singleton
// LauncherState.qml — open/close state of the menu (launcher) and of the
// standalone radioport. Both open on the focused monitor; reached through
// `qs ipc call launcher|mediapanel toggle|open|close` (handlers in shell.qml).

import Quickshell
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    property bool open: false
    property string screenName: ""

    // Esc during a keybind capture: Hyprland eats it, and calls back through IPC
    signal captureCancelled()

    property bool mediaOpen: false
    property string mediaScreen: ""

    function _focusedScreen() {
        var m = Hyprland.focusedMonitor
        return m ? m.name : ""
    }

    function openMenu() {
        root.screenName = root._focusedScreen()
        root.open = true
    }
    function closeMenu() { root.open = false }
    function toggleMenu() { root.open ? root.closeMenu() : root.openMenu() }

    function openMedia() {
        root.mediaScreen = root._focusedScreen()
        root.mediaOpen = true
    }
    function closeMedia() { root.mediaOpen = false }
    function toggleMedia() { root.mediaOpen ? root.closeMedia() : root.openMedia() }

    // The Radioport runs in its own process (media.qml), which keeps the media*
    // state above in its own copy of this singleton; the main shell drives it
    // and the Radioport reaches back to the menu through IPC. cmd: toggle|open|close
    readonly property string _config: Quickshell.env("HOME") + "/.config/quickshell/"
    function mediaPanel(cmd) {
        Quickshell.execDetached(["qs", "ipc", "-p", root._config + "media.qml", "call", "mediapanel", cmd])
    }
    function launcher(cmd) {
        Quickshell.execDetached(["qs", "ipc", "-p", root._config + "shell.qml", "call", "launcher", cmd])
    }
}
