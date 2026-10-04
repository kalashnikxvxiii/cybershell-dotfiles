// ToastOverlay.qml -- the surface the toast stack lives on, one per screen.
//
// Its own layer-shell surface, like SonarPanel: the stack belongs to the corner,
// not to the bar. exclusionMode Normal so it respects the bar's zone; it reserves
// nothing of its own.
//
// Bottom right: the bar owns the top strip, the dashboard drops from top centre,
// Sonar is pinned top right and the workspace preview opens on the left edge under
// the bar. Bottom right is the only corner nothing else claims -- and cards that
// stack upwards from it put the newest one nearest the entry point.
//
// Only the cards take the pointer (mask on the stack), so the desktop underneath
// stays clickable, and the surface never asks for keyboard focus.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../common"

Scope {
    id: root

    required property var screen

    // Verified reactive: hasfullscreen tracks the compositor without any
    // explicit Hyprland.refreshWorkspaces() call.
    readonly property var hlMonitor: Hyprland.monitorFor(root.screen)
    readonly property bool fullscreen: hlMonitor && hlMonitor.activeWorkspace
        && hlMonitor.activeWorkspace.lastIpcObject
        ? hlMonitor.activeWorkspace.lastIpcObject.hasfullscreen === true
        : false

    readonly property int gap: 8
    readonly property int stackWidth: 340

    PanelWindow {
        id: win

        screen: root.screen
        WlrLayershell.namespace: "qs-toasts"
        // Overlay, not Top: in Hyprland a fullscreen window draws OVER the Top
        // layer, so on Top the fullscreen policy could never let anything
        // through. Verified: the cards only reach a fullscreen game from here.
        WlrLayershell.layer: WlrLayer.Overlay
        // Normal, not Ignore: Ignore would make the surface ignore the bar's
        // exclusive zone.
        WlrLayershell.exclusionMode: ExclusionMode.Normal
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusiveZone: 0

        anchors.bottom: true
        anchors.right: true
        margins.bottom: root.gap
        margins.right: root.gap

        implicitWidth: root.stackWidth
        // Never commit a zero-height surface.
        implicitHeight: Math.max(1, stack.implicitHeight)
        color: "transparent"

        // Mapped only while something is on screen, and kept mapped through the
        // exit animation (implicitHeight only reaches 0 once the cards are gone).
        visible: stack.implicitHeight > 0

        // Only the cards take clicks; everything else falls through.
        mask: Region {
            item: stack.implicitHeight > 0 ? stack : null
        }

        Toasts {
            id: stack
            anchors.fill: parent
            fullscreen: root.fullscreen
        }
    }
}
