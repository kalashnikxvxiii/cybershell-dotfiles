// HudSonarCard.qml -- the full Sonar, grown out of the HUD tile: its top right corner
// stays where the tile's is and the other sides open up. On its own surface, above the
// windows and able to take the keyboard, on the same tilted plane as the HUD.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../common"
import "../sonar"

Scope {
    id: root

    required property var screen

    // Tile size, and how far it has grown: 0 is the tile, 1 the open card
    readonly property int tileWidth: 220
    readonly property int tileHeight: 210
    property real growth: 0

    onGrowthChanged: {
        const s = Object.assign({}, HudState.sonarShift)
        s[root.screen.name] = root.growWidth * root.growth
        HudState.sonarShift = s
    }

    readonly property int growWidth: card.implicitWidth - root.tileWidth
    readonly property int growHeight: card.implicitHeight - root.tileHeight

    readonly property bool wantOpen: HudState.enabled && SonarState.open
        && (SonarState.screenName === "" || SonarState.screenName === root.screen.name)

    onWantOpenChanged: {
        if (root.wantOpen) {
            shrink.stop()
            grow.restart()
        } else {
            grow.stop()
            shrink.restart()
        }
    }

    NumberAnimation { id: grow; target: root; property: "growth"; to: 1; duration: 480; easing.type: Easing.OutQuart }
    NumberAnimation { id: shrink; target: root; property: "growth"; to: 0; duration: 380; easing.type: Easing.OutCubic }

    PanelWindow {
        screen: root.screen
        anchors.top: true
        anchors.right: true
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: 470
        implicitHeight: 680
        color: "transparent"
        visible: root.wantOpen || root.growth > 0
        WlrLayershell.namespace: "qs-sonar"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: root.wantOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        mask: Region { item: root.wantOpen ? card : null }

        onVisibleChanged: if (visible) card.forceActiveFocus()

        HudStatusFrame {
            // Fixed size around the open card, so growing never reallocates the texture
            HudPlate {
                x: 330 - 6 - width
                y: 8
                width: card.implicitWidth + 4
                height: card.implicitHeight + 4

                SonarCard {
                    id: card
                    // Same place as the tile in HudStatus: the top right corner stays put
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    y: 2
                    width: root.tileWidth + root.growWidth * root.growth
                    height: root.tileHeight + root.growHeight * root.growth
                    morph: root.growth
                    focus: true
                    shown: root.wantOpen
                }
            }
        }
    }
}
