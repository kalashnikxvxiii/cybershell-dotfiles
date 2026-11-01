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
    // Room around the stack for the tilt and the cards sliding out
    readonly property int pad: 28
    // Fixed, whatever is on screen: resizing the surface would move the tilt's pivot, and with it
    // every card. Room for maxToasts cards of three lines
    readonly property int stackHeight: 400

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
        // Above the HUD's Apps Launcher hint, which owns the bottom of this corner
        margins.bottom: HudState.enabled ? 40 : 0

        implicitWidth: root.stackWidth + 2 * root.pad
        implicitHeight: root.stackHeight + 2 * root.pad
        color: "transparent"

        // Mapped only while something is on screen, and kept mapped through the
        // exit animation (implicitHeight only reaches 0 once the cards are gone).
        visible: stack.implicitHeight > 0

        // Only the cards take clicks; everything else falls through.
        mask: Region {
            item: cards
        }

        // The HUD's plane for this corner, drawn flat at twice the size (see HudPlate)
        Item {
            id: plate
            anchors.fill: parent
            transform: Tilt { w: plate.width; h: plate.height; yaw: -14; pitch: -1; roll: 2.5; focal: 1180 }
            layer.enabled: stack.implicitHeight > 0
            layer.smooth: true
            layer.textureSize: Qt.size(width * 2, height * 2)

            Toasts {
                id: stack
                anchors.fill: parent
                anchors.margins: root.pad
                fullscreen: root.fullscreen
            }
            Item {
                id: cards
                anchors.left: stack.left
                anchors.right: stack.right
                anchors.bottom: stack.bottom
                height: stack.implicitHeight
            }
        }
    }
}
