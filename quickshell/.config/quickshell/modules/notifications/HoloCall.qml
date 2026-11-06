// HoloCall.qml -- a notification as the game's holo call, top left of the focused screen. Left
// click opens it, right click dismisses it; its other actions get their own buttons.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Wayland
import "../../common"
import "../../common/effects"
import "../hud"

Scope {
    id: root

    required property var screen

    readonly property bool focused: Hyprland.focusedMonitor?.name === root.screen.name
    readonly property bool shown: NotifState.current !== null && focused
    // Kept while the card glitches out
    property var showing: null
    readonly property var buttons: root.showing ? root.showing.actions.filter(a => a.identifier !== "default") : []
    readonly property bool urgent: root.showing?.urgency === NotificationUrgency.Critical
    readonly property color tone: urgent ? HudState.danger : HudState.power
    readonly property string picture: NotifState.picture(root.showing)

    Connections {
        target: NotifState
        function onCurrentChanged() {
            if (NotifState.current) {
                root.showing = NotifState.current
                barIn.restart()
            }
        }
    }

    PanelWindow {
        screen: root.screen
        visible: root.shown || fx.visible
        color: "transparent"
        anchors { top: true; left: true }
        margins { top: 150; left: 24 }
        implicitWidth: 520
        implicitHeight: 190
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-holo"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region { item: root.shown ? plate : null }

        GlitchReveal {
            id: fx
            anchors.fill: parent
            shown: root.shown

            Item {
                id: plate
                anchors.fill: parent
                transform: Tilt { w: plate.width; h: plate.height; yaw: 16; pitch: 2; roll: 0.5; focal: 2100 }
                layer.enabled: true
                layer.smooth: true
                layer.textureSize: Qt.size(width * 2, height * 2)
                layer.effect: DarkHalo {}

                // Phone, ringing
                Text {
                    x: 10
                    y: 58
                    text: ""
                    color: HudState.danger
                    opacity: ring.k
                    font { family: HudState.icons; pixelSize: 30 }
                }
                Pulse {
                    id: ring
                    running: root.shown
                    from: 1
                    to: 0.5
                    halfMs: 400
                }

                Text {
                    x: 40
                    y: 14
                    text: "CONNECTION " + (root.showing?.appName ?? "").toUpperCase()
                    color: HudState.alpha(HudState.danger, 0.8)
                    font { family: HudState.font; pixelSize: 9; letterSpacing: 1 }
                }

                HudGhosts {
                    target: shard
                    center: Qt.point(-root.screen.width / 2, root.screen.height / 2 - 150)
                    ghost: ContactShard { ghost: true }
                }

                ContactShard {
                    id: shard
                    x: 40
                    y: 30
                    picture: root.picture
                }

                Text {
                    x: 100
                    y: 26
                    text: "  " + (root.urgent ? "PRIORITY MESSAGE" : "NEW MESSAGE")
                    color: root.tone
                    font { family: HudState.icons; pixelSize: 14; bold: true }
                }
                Text {
                    x: 100
                    y: 48
                    width: 380
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: (root.showing?.summary ?? "").toUpperCase()
                    color: HudState.tech
                    font { family: HudState.font; pixelSize: 20; bold: true; letterSpacing: 1 }
                }

                // Body: a speech bubble, its tail the spike at the top left
                Item {
                    id: bar
                    readonly property int tail: 7
                    x: 100
                    y: 71
                    width: 0
                    height: Math.max(42, bodyText.implicitHeight + 18) + tail

                    HudGhosts {
                        target: bubble
                        center: Qt.point(-root.screen.width / 2, root.screen.height / 2 - 150)
                    }

                    Shape {
                        id: bubble
                        anchors.fill: parent
                        antialiasing: true
                        layer.enabled: true
                        layer.smooth: true
                        layer.samples: 4
                        ShapePath {
                            fillColor: HudState.alpha(root.tone, 0.5)
                            strokeColor: root.tone
                            strokeWidth: 1
                            PathSvg {
                                path: {
                                    const w = bar.width - 0.5, h = bar.height - 0.5, t = bar.tail
                                    return `M 0.5 0.5 L ${t + 2} ${t} L ${w} ${t} L ${w} ${h} L 6 ${h} L 0.5 ${h - 6} Z`
                                }
                            }
                        }
                    }
                    Item {
                        anchors.fill: parent
                        anchors.topMargin: bar.tail
                        clip: true

                        Text {
                            id: bodyText
                            x: 14
                            width: 380 - 28
                            anchors.verticalCenter: parent.verticalCenter
                            textFormat: Text.PlainText
                            text: root.showing?.body ?? ""
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            color: HudState.paper
                            font { family: HudState.font; pixelSize: 14 }
                        }
                    }
                }
                NumberAnimation {
                    id: barIn
                    target: bar
                    property: "width"
                    from: 0
                    to: 380
                    duration: 220
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: e => {
                        if (e.button === Qt.RightButton)
                            NotifState.current.dismiss()
                        else
                            NotifState.open(NotifState.current)
                    }
                }

                // The notification's own actions
                Row {
                    x: 100
                    y: bar.y + bar.height + 8
                    spacing: 8
                    Repeater {
                        model: root.buttons
                        CutShape {
                            id: action
                            required property var modelData
                            width: actionText.implicitWidth + 20
                            height: 22
                            cutBottomRight: 6
                            fillColor: actionHit.containsMouse ? HudState.alpha(HudState.tech, 0.2) : "transparent"
                            strokeColor: HudState.tech
                            inset: 0.5
                            Text {
                                id: actionText
                                anchors.centerIn: parent
                                text: action.modelData.text.toUpperCase()
                                color: HudState.tech
                                font { family: HudState.font; pixelSize: 10; bold: true; letterSpacing: 1 }
                            }
                            MouseArea {
                                id: actionHit
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: action.modelData.invoke()
                            }
                        }
                    }
                }
            }
        }
    }
}
