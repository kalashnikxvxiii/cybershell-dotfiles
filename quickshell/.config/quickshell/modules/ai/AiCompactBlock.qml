// AiCompactBlock.qml - where the context was summarized.
//
// The extension's two marks for it, in its order: a line saying how and how
// much, which unfolds into the summary the model now works from, then a wavy
// rule across the transcript. Everything above the rule is still on screen
// but no longer in the model's context
import QtQuick
import "../../common/Colors.js" as CP
import "AiMarkdown.js" as Md

Item {
    id: root

    // { trigger: "manual"|"auto", pre, post, summary }
    required property var part
    property bool expanded: false

    signal toggled()

    readonly property color fg: "#d8e0e8"
    // What the summary gave back. The extension prints the size before it
    // instead; the CLI reports both, so this one is the actual difference
    readonly property real freed: root.part.post > 0
        ? Math.max(0, root.part.pre - root.part.post) : root.part.pre
    readonly property string summary: root.part.summary ?? ""

    implicitHeight: col.implicitHeight
    height: implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 6

        Item {
            width: parent.width
            height: 17

            Row {
                id: head
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "COMPACTED CHAT \u00b7 " + (root.part.trigger === "manual" ? "MANUAL" : "AUTO")
                        + " \u00b7 " + Math.round(root.freed / 1000) + "K TOKENS FREED"
                    font.family: "Oxanium"
                    font.pixelSize: 9
                    font.letterSpacing: 1.5
                    color: CP.alpha(root.fg, ma.containsMouse || root.expanded ? 0.75 : 0.5)
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.expanded ? "\uf077" : "\uf078"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 8
                    color: CP.alpha(root.fg, ma.containsMouse || root.expanded ? 0.75 : 0.5)
                }
            }

            MouseArea {
                id: ma
                width: head.width + 8
                height: parent.height
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggled()
            }
        }

        // Parsed only once unfolded: a summary runs to a few thousand words
        Loader {
            width: parent.width
            active: root.expanded
            visible: active
            sourceComponent: root.summary !== "" ? mdComp : noneComp

            Component {
                id: mdComp
                AiMarkdownView { blocks: Md.parse(root.summary); fg: CP.alpha(root.fg, 0.7) }
            }

            Component {
                id: noneComp
                Text {
                    text: "Conversation was compacted to free up context."
                    font.family: "Oxanium"
                    font.pixelSize: 11
                    color: CP.alpha(root.fg, 0.55)
                }
            }
        }

        // ── The cut ──────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 18

            Text {
                id: cutLabel
                anchors.centerIn: parent
                text: "COMPACTED"
                font.family: "Oxanium"
                font.pixelSize: 9
                font.letterSpacing: 2
                color: CP.alpha(root.fg, 0.4)
            }

            Repeater {
                model: 2

                // A sine of 14px period, as in the extension's mask
                Canvas {
                    required property int index
                    anchors.verticalCenter: parent.verticalCenter
                    x: index === 0 ? 0 : cutLabel.x + cutLabel.width + 10
                    width: Math.max(32, cutLabel.x - 10)
                    height: 7
                    onWidthChanged: requestPaint()
                    onPaint: {
                        const g = getContext("2d")
                        g.reset()
                        g.strokeStyle = CP.alpha(root.fg, 0.3)
                        g.lineWidth = 1
                        g.beginPath()
                        g.moveTo(0, 3.5)
                        for (let x = 0; x < width; x += 14) {
                            g.quadraticCurveTo(x + 3.5, 0, x + 7, 3.5)
                            g.quadraticCurveTo(x + 10.5, 7, x + 14, 3.5)
                        }
                        g.stroke()
                    }
                }
            }
        }
    }
}
