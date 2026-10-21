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
}
