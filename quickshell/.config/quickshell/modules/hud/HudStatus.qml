// HudStatus.qml -- top right: clock, the mini sonar and network. While the Sonar card
// grows out of the tile, the network makes room for it
import QtQuick
import Quickshell
import "../../common"
import "../bar"

HudStatusFrame {
    id: root

    required property var screen
    // From HudSonarCard: how far the card has grown, and by how much in all
    property real growth: 0
    property int growWidth: 0
    property int growHeight: 0

    // The Sonar tile, exposed so the window can give it the pointer
    readonly property alias sonar: sonarTile

    // Same top as the vitals, above the sonar: the card opens downwards and leaves it alone
    HudPlate {
        anchors.right: parent.right
        anchors.rightMargin: -6
        y: -49
        width: clock.implicitWidth + 4
        height: clock.implicitHeight + 4
        // A hidden window's content stays `visible`, and the clock's glitch would keep running
        visible: HudState.enabled

        Clock {
            id: clock
            x: 2
            y: 5
        }
    }

    HudPlate {
        anchors.right: parent.right
        anchors.rightMargin: 6
        y: 8
        width: sonarTile.width + 4
        height: sonarTile.height + 4
        // The card takes over as soon as it starts growing, and hands back at the end
        opacity: root.growth > 0 ? 0 : 1

        HudSonar {
            id: sonarTile
            x: 2
            y: 2
            screen: root.screen
        }
    }

    HudPlate {
        y: 228 + root.growHeight * root.growth
        width: parent.width
        height: 50
        layer.effect: DarkHalo {}

        // Just left of the sonar's left edge, the second line indented
        Row {
            x: 90
            y: 2
            spacing: 8
            Text {
                text: "NETWORK STATUS"
                color: HudState.power
                font { family: HudState.font; pixelSize: 13; bold: true; letterSpacing: 1 }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\u2191 " + HudState.rate(HudState.txMbps)
                color: HudState.tech
                font { family: HudState.font; pixelSize: 10 }
            }
        }
        Row {
            x: 112
            y: 22
            spacing: 6
            CutShape {
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 17
                cutBottomLeft: 6
                fillColor: HudState.power
                Text {
                    anchors.centerIn: parent
                    text: "!"
                    color: "#00060e"
                    font { family: HudState.font; pixelSize: 13; bold: true }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                // A long SSID must not push the rate out of the plate
                width: Math.min(implicitWidth, 120)
                elide: Text.ElideRight
                text: SonarState.activeSsid !== "" ? "WIFI: " + SonarState.activeSsid.toUpperCase() : "LAN: " + HudState.iface.toUpperCase()
                color: HudState.power
                font { family: HudState.font; pixelSize: 12 }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\u2193 " + HudState.rate(HudState.rxMbps)
                color: HudState.danger
                font { family: HudState.font; pixelSize: 10 }
            }
        }
    }
}
