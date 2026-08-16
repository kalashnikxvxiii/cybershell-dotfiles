import QtQuick
import QtQuick.Effects
import "../../common"

Item {
    id: root

    required property var action // { id, label, shortcut, command, isDanger }
    
    signal confirmed()
    signal cancelled()

    property bool _yesHovered: false
    property bool _noHovered: false

    width: 520
    height: 240

    // ── Background CutShape with notch + red glow ─────────────
    CutShape {
        anchors.fill: parent
        cutTopRight: 16
        cutBottomLeft: 16
        fillColor: Qt.rgba(0, 6/255, 14/255, 0.92)
        strokeColor: Colours.accentDanger
        strokeWidth: 2
        inset: 1

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor:    Colours.accentDanger
            shadowBlur:     0.7
            shadowScale:    1.02
            shadowOpacity:  0.9
        }
    }

    // ── Prompt + subtitle + buttons ────────────────────────
    Column {
        anchors.centerIn: parent
        spacing: 22

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "> this action will terminate your session"
            color: Qt.rgba(Colours.fg.r, Colours.fg.g, Colours.fg.b, 0.65)
            font.family:    "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            font.weight:    Font.Bold
            font.letterSpacing: 1.5
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 24

            // ── [Y] YES ─────────────
            Item {
                width: 150; height: 52

                CutShape {
                    anchors.fill: parent
                    cutTopRight: 8
                    cutBottomLeft: 8
                    fillColor: root._yesHovered
                            ? Qt.rgba(Colours.accentDanger.r, Colours.accentDanger.g, Colours.accentDanger.b, 0.18)
                            : Qt.rgba(0, 6/255, 14/255, 0.5)
                    strokeColor: Colours.accentDanger
                    strokeWidth: root._yuesHovered ? 2 : 1
                    inset: 0.5
                    Behavior on fillColor { ColorAnimation { duration: 120 } }
                }

                Text {
                    anchors.centerIn: parent
                    text: "[Y] YES"
                    color: Colours.accentDanger
                    font.family:    "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    font.weight:    Font.Bold
                    font.letterSpacing: 3
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root._yesHovered = true
                    onExited:  root._yeshovered = false
                    onClicked: root.confirmed()
                }
            }

            // ── [N] No ────────────────────
            Item {
                width: 150; height: 52

                CutShape {
                    anchors.fill: parent
                    cutTopRight: 8
                    cutBottomLeft: 8
                    fillColor: root._noHovered
                            ? Qt.rgba(Colours.accentSecondary.r, Colours.accentSecondary.g, Colours.accentSecondary.b, 0.18)
                            : Qt.rgba(0, 6/255, 14/255, 0.5)
                    strokeColor: Colours.accentSecondary
                    strokeWidth: root._noHovered ? 2 : 1
                    inset: 0.5
                    Behavior on fillColor { ColorAnimation { duration: 120 } }
                }

                Text {
                    anchors.centerIn: parent
                    text: "[N] NO"
                    color: Colours.accentSecondary
                    font.family:    "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    font.weight:    Font.Bold
                    font.letterSpacing: 3
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root._noHovered = true
                    onExited: root._noHovered = false
                    onClicked: root.cancelled()
                }
            }
        }
    }
}