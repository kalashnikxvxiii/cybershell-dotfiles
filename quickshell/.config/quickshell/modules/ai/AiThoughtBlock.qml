// AiThoughtBlock.qml - one reasoning step of an answer, folded to one line.
//
// What the model weighed before acting stays in the transcript, between the
// text and the tool calls it led to, so a turn reads back in the order it
// happened. Folded it says only how long; unfolded, the summary the CLI
// streamed. Same grammar as AiToolGroup, its neighbour
import QtQuick
import "../../common/effects"
import "../../common/Colors.js" as CP
import "AiHighlight.js" as Hl

Item {
    id: root

    required property string text
    // 0 when unknown: a transcript read back from disk has no timings
    property real ms: 0
    // Still open: the text grows under the reader's eyes
    property bool streaming: false
    // Owned by the transcript, which outlives this row: see AiChat.openFolds
    property bool expanded: false

    signal toggled()

    readonly property color fg: "#d8e0e8"
    readonly property bool hasText: root.text !== ""

    implicitHeight: col.implicitHeight
    height: implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 4

        Item {
            width: parent.width
            height: 17

            Row {
                id: head
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.hasText
                    text: root.expanded ? "\u25be" : "\u25b8"
                    font.family: "Oxanium"
                    font.pixelSize: 9
                    color: CP.magenta
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.streaming ? "THINKING\u2026"
                        : root.ms > 0
                        ? "THOUGHT FOR " + Math.max(1, Math.round(root.ms / 1000)) + "S"
                        : "THOUGHT"
                    font.family: "Oxanium"
                    font.pixelSize: 9
                    font.letterSpacing: 1.5
                    opacity: root.streaming ? pulse.k : 1
                    color: ma.containsMouse ? CP.magenta : CP.alpha(CP.magenta, 0.72)
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
            }

            Pulse { id: pulse; running: root.visible && root.streaming; from: 1.0; to: 0.5; halfMs: 600 }

            MouseArea {
                id: ma
                width: head.width + 8
                height: parent.height
                enabled: root.hasText
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggled()
            }
        }

        Item {
            visible: root.expanded && root.hasText
            width: parent.width
            height: visible ? thought.implicitHeight : 0

            Rectangle {
                x: 3
                width: 1
                height: parent.height
                color: CP.alpha(CP.magenta, 0.3)
            }

            AiRichText {
                id: thought
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 14
                html: '<div style="white-space:pre-wrap">' + Hl.esc(root.text) + "</div>"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                font.italic: true
                lineHeight: 1.15
                color: CP.alpha(root.fg, 0.55)
            }
        }
    }
}
