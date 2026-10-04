// SonarPanel.qml — the window that pins the Sonar card to the screen's
// top-right corner, under the bar.
//
// Its own layer-shell surface rather than a child of the drawers window: the
// panel belongs to the corner, not to the bar. It respects the bar's exclusive
// zone (so it sits under it) and reserves none of its own.
//
// The way in is the media tab's track badge: the card drops down closed, holds,
// then opens sideways — here from the right edge towards the left, since that
// is the edge it is pinned to — and settles with a short glitch.
//
// Opened from scripts/sonar-toggle.sh (keybind) or from the bar modules, both
// through SonarState. Scanning follows the view, so nothing probes the radios
// while the panel is closed.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../common"

Scope {
    id: root

    required property var screen

    readonly property bool wantOpen: SonarState.open
        && (SonarState.screenName === "" || SonarState.screenName === root.screen.name)

    // Breathing room from the bar above and from the screen's right edge.
    readonly property int gap: 6
    // Width of the closed sliver: the card's left border, before it opens.
    readonly property int shutWidth: 6

    PanelWindow {
        id: win
        screen: root.screen
        WlrLayershell.namespace: "qs-sonar"
        WlrLayershell.layer: WlrLayer.Top
        // Normal, not Ignore: Ignore makes the surface disregard the bar's
        // exclusive zone and it lands on top of the bar.
        WlrLayershell.exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0
        WlrLayershell.keyboardFocus: root.wantOpen ? WlrKeyboardFocus.OnDemand
                                                   : WlrKeyboardFocus.None
        anchors.top: true
        anchors.right: true
        margins.top: root.gap
        margins.right: root.gap
        implicitWidth: card.implicitWidth
        // Room above for the card to drop in from, plus the card itself.
        implicitHeight: card.implicitHeight
        color: "transparent"
        // Kept mapped until the card has slid back out of sight.
        visible: root.wantOpen || reveal.y > -card.implicitHeight || openAnim.running || shutAnim.running

        // Only the open card takes the pointer.
        mask: Region {
            item: root.wantOpen && reveal.width > root.shutWidth ? reveal : null
        }

        // The reveal window: pinned to the right, its width is what opens.
        Item {
            id: reveal
            anchors.right: parent.right
            width: root.shutWidth
            height: card.implicitHeight
            y: -card.implicitHeight - 12
            clip: true

            transform: Translate { id: revealShift }

            SonarCard {
                id: card
                anchors.right: parent.right
                width: implicitWidth
                height: implicitHeight
                focus: true
                shown: root.wantOpen
            }
        }

        onVisibleChanged: if (visible) card.forceActiveFocus()
    }

    onWantOpenChanged: {
        if (root.wantOpen) {
            shutAnim.stop()
            openAnim.restart()
        } else {
            openAnim.stop()
            shutAnim.restart()
        }
    }

    // ── Opening ──────────────────────────────────────────────────────────
    // Same shape as the media badge: drop in closed, hold, open sideways, then
    // a burst of flicker and jitter so it arrives like a signal, not a window.
    SequentialAnimation {
        id: openAnim

        PropertyAction { target: reveal; property: "width"; value: root.shutWidth }
        PropertyAction { target: reveal; property: "opacity"; value: 1 }

        NumberAnimation {
            target: reveal; property: "y"; to: 0
            duration: 700; easing.type: Easing.OutCubic
        }

        PauseAnimation { duration: 500 }

        NumberAnimation {
            target: reveal; property: "width"; to: card.implicitWidth
            duration: 800; easing.type: Easing.OutQuart
        }

        ParallelAnimation {
            SequentialAnimation {
                NumberAnimation { target: reveal; property: "opacity"; to: 1.0; duration: 130 }
                NumberAnimation { target: reveal; property: "opacity"; to: 0.6; duration: 100 }
                NumberAnimation { target: reveal; property: "opacity"; to: 0.9; duration: 80 }
                NumberAnimation { target: reveal; property: "opacity"; to: 0.4; duration: 120 }
                NumberAnimation { target: reveal; property: "opacity"; to: 0.7; duration: 50 }
                NumberAnimation { target: reveal; property: "opacity"; to: 1.0; duration: 130 }
            }

            // Stepped, never eased: the jitter is a fault, not a movement.
            SequentialAnimation {
                PropertyAction { target: revealShift; property: "x"; value: -4 }
                PauseAnimation { duration: 35 }
                PropertyAction { target: revealShift; property: "x"; value: 3 }
                PropertyAction { target: reveal; property: "width"; value: card.implicitWidth - 14 }
                PauseAnimation { duration: 28 }
                PropertyAction { target: revealShift; property: "x"; value: -6 }
                PropertyAction { target: reveal; property: "width"; value: card.implicitWidth + 6 }
                PauseAnimation { duration: 20 }
                PropertyAction { target: revealShift; property: "x"; value: 2 }
                PropertyAction { target: reveal; property: "width"; value: card.implicitWidth }
                PauseAnimation { duration: 30 }
                PropertyAction { target: revealShift; property: "x"; value: 0 }
            }
        }
    }

    // ── Closing ──────────────────────────────────────────────────────────
    SequentialAnimation {
        id: shutAnim

        NumberAnimation {
            target: reveal; property: "width"; to: root.shutWidth
            duration: 300; easing.type: Easing.InQuart
        }

        PauseAnimation { duration: 150 }

        NumberAnimation {
            target: reveal; property: "y"; to: -card.implicitHeight - 12
            duration: 280; easing.type: Easing.InCubic
        }
    }
}
