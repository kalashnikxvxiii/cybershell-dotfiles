// MediaPanel.qml — standalone RADIOPORT overlay, as in AndreaNec/Cyberpunk-quickshell
// (mediaplayer/MediaPanel.qml). Hosts the same component as the dashboard's
// media tab. Opened from the menu ("Media") or:
//   qs ipc call mediapanel toggle | open | close
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../common/Colors.js" as CP
import "../../common"
import "../../common/effects"
import "../hud"

Scope {
    id: root

    required property var screen

    readonly property bool shown: LauncherState.mediaOpen && LauncherState.mediaScreen === root.screen.name

    PanelWindow {
        screen: root.screen
        visible: root.shown || fx.visible
        color: "transparent"
        anchors {
            top: true
            left: true
            bottom: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "qs-mediapanel"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Frosted glass (blur from the qs-mediapanel layer rule)
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 6/255, 14/255, 0.6)
            opacity: root.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            Image {
                anchors.fill: parent
                source: "file:///home/kalashnikxv/.config/wlogout/grain.png"
                fillMode: Image.Tile
                opacity: 0.07
            }

            ScanlineOverlay {
                opacity: 0
            }

            MouseArea {
                anchors.fill: parent
                onClicked: LauncherState.closeMedia()
            }
        }

        GlitchReveal {
            id: fx
            anchors.centerIn: parent
            width: radioport.width
            height: radioport.height
            shown: root.shown

            // Swallows clicks inside the panels; wider than them, as the tilt moves their corners
            MouseArea {
                anchors.fill: panels
                anchors.margins: -40
            }
            // Offset by the plates' margins, so that the Radioport itself stays centered
            Row {
                id: panels
                x: -audioPlate.width - spacing - radioportPlate.margin - radioportPlate.backRoom
                y: -radioportPlate.margin
                spacing: 8

                // The inside of a curved visor: the centered Radioport only bows, the panels at
                // its sides also turn towards the viewer. Each is one texture, see HudPlate
                HudPlate {
                    id: audioPlate
                    width: audioPanel.implicitWidth + 8
                    height: radioportPlate.height
                    transform: [
                        Tilt { w: audioPlate.width; h: audioPlate.height; yaw: 24; focal: 800 },
                        Scale { origin.x: audioPlate.width / 2; origin.y: audioPlate.height / 2; yScale: 1.05 }
                    ]
                    layer.effect: BowEffect { amount: 8 }

                    RadioportAudio {
                        id: audioPanel
                        x: 4
                        y: 4
                        width: implicitWidth
                        height: radioport.height
                        active: root.shown
                    }
                }

                HudPlate {
                    id: radioportPlate
                    readonly property int margin: 4
                    // Room on the left for the arrow back to the menu
                    readonly property int backRoom: 28
                    width: radioport.width + margin * 2 + backRoom
                    height: radioport.height + margin * 2
                    layer.effect: BowEffect { amount: 14 }

                    // The audio tabs' number keys; what the Radioport doesn't use comes up here
                    Keys.onPressed: e => {
                        if (e.key >= Qt.Key_1 && e.key <= Qt.Key_3) {
                            audioPanel.tab = e.key - Qt.Key_1
                            e.accepted = true
                        }
                    }

                    Radioport {
                        id: radioport
                        x: radioportPlate.margin + radioportPlate.backRoom
                        y: radioportPlate.margin
                        active: root.shown
                        Keys.onEscapePressed: LauncherState.closeMedia()
                    }
                    Text {
                        x: radioportPlate.margin
                        y: radioportPlate.margin + 26
                        text: "\uf060"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 18
                        color: backArea.containsMouse ? CP.neon : CP.cyan

                        MouseArea {
                            id: backArea
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                LauncherState.closeMedia();
                                LauncherState.openMenu();
                            }
                        }
                    }
                }
                HudPlate {
                    id: eqPlate
                    width: eq.implicitWidth + 8
                    height: radioportPlate.height
                    transform: [
                        Tilt { w: eqPlate.width; h: eqPlate.height; yaw: -24; focal: 800 },
                        Scale { origin.x: eqPlate.width / 2; origin.y: eqPlate.height / 2; yScale: 1.05 }
                    ]
                    layer.effect: BowEffect { amount: 8 }

                    RadioportEq {
                        id: eq
                        x: 4
                        y: 4
                        width: implicitWidth
                        height: radioport.height
                        station: radioport.stationName(radioport.player)
                    }
                }
            }
        }
    }
}
