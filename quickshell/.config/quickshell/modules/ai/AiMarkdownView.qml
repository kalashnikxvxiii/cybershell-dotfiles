// AiMarkdownView.qml - draws the blocks AiMarkdown.parse() returns.
//
// One item per block, so lists, quotes and the rest look like the shell and
// not like QTextDocument's defaults. Quotes and <details> hold blocks of their
// own and load this file again for them.
import QtQuick
import "../../common"
import "../../common/Colors.js" as CP

Column {
    id: root

    property var blocks: []
    property color fg: "#d8e0e8"

    // A list level, and the column its text starts at: a block nested in an
    // item lines up with the item's text
    readonly property int step: 18

    // Room above a block: lists stay tight, headings get air
    function gapOf(b, prev) {
        if (!prev) return 0
        if (b.t === "li" && prev.t === "li") return 3
        if (b.t === "dd") return 2
        if (b.t === "h") return b.level <= 2 ? 14 : 10
        return 8
    }

    Repeater {
        // Laid out only once it has a real width: a Loader hands it a negative
        // one first, and a long answer wrapped one glyph per line takes seconds
        model: root.width > 0 ? root.blocks : []

        Item {
            id: blk

            required property var modelData
            required property int index
            readonly property var b: modelData
            readonly property int gap: root.gapOf(b, index > 0 ? root.blocks[index - 1] : null)
            readonly property int indent: b.depth * root.step

            width: root.width
            height: gap + loader.height

            Loader {
                id: loader
                y: blk.gap
                x: blk.indent
                width: blk.width - blk.indent
                sourceComponent: ({
                    h: headComp, p: paraComp, li: itemComp, code: codeComp, table: paraComp,
                    hr: ruleComp, math: mathComp, dt: termComp, dd: defComp, quote: quoteComp,
                    details: detailsComp, notes: notesComp
                })[blk.b.t] ?? paraComp
            }

            Component {
                id: headComp
                Column {
                    spacing: 4
                    AiRichText {
                        width: parent.width
                        html: blk.b.html
                        color: blk.b.level <= 2 ? "#f2f6f8" : root.fg
                        font.pixelSize: [12, 19, 16, 14, 13, 12, 11][blk.b.level]
                        font.bold: true
                        font.letterSpacing: blk.b.level <= 2 ? 0.6 : 0.3
                        opacity: blk.b.level === 6 ? 0.75 : 1
                    }
                    // The two top levels get a rule: sections, not just bold lines
                    Rectangle {
                        visible: blk.b.level <= 2
                        width: parent.width
                        height: 1
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: CP.alpha(CP.magenta, 0.55) }
                            GradientStop { position: 1; color: "transparent" }
                        }
                    }
                }
            }

            Component {
                id: paraComp
                AiRichText { html: blk.b.html; color: root.fg }
            }

            Component {
                id: itemComp
                Item {
                    implicitHeight: itemText.implicitHeight

                    // Ordered: the number. Tasks: a box. Otherwise a mark that
                    // changes with the level, square, hollow square, dash
                    Text {
                        visible: blk.b.ordered && blk.b.task < 0
                        width: root.step - 4
                        horizontalAlignment: Text.Right
                        text: blk.b.marker
                        font.family: "Oxanium"
                        font.pixelSize: 11
                        font.bold: true
                        color: CP.cyan
                        y: 1
                    }
                    Rectangle {
                        visible: !blk.b.ordered && blk.b.task < 0
                        readonly property int kind: blk.b.depth % 3
                        x: 5
                        y: kind === 2 ? 8 : 6
                        width: kind === 2 ? 6 : 5
                        height: kind === 2 ? 1 : 5
                        color: kind === 1 ? "transparent" : CP.cyan
                        border.width: kind === 1 ? 1 : 0
                        border.color: CP.cyan
                    }
                    Rectangle {
                        visible: blk.b.task >= 0
                        x: 2
                        y: 3
                        width: 10
                        height: 10
                        color: "transparent"
                        border.width: 1
                        border.color: blk.b.task === 1 ? CP.neon : CP.alpha(CP.cyan, 0.6)
                        Rectangle {
                            visible: blk.b.task === 1
                            anchors.centerIn: parent
                            width: 4
                            height: 4
                            color: CP.neon
                        }
                    }

                    AiRichText {
                        id: itemText
                        x: root.step
                        width: parent.width - root.step
                        html: blk.b.html
                        color: root.fg
                        // Done is done: it steps back
                        opacity: blk.b.task === 1 ? 0.5 : 1
                    }
                }
            }

            Component {
                id: codeComp
                AiCodeBlock { lang: blk.b.lang; code: blk.b.text }
            }

            Component {
                id: ruleComp
                Item {
                    implicitHeight: 9
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 1
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: "transparent" }
                            GradientStop { position: 0.5; color: CP.alpha(CP.cyan, 0.45) }
                            GradientStop { position: 1; color: "transparent" }
                        }
                    }
                }
            }

            Component {
                id: mathComp
                AiRichText {
                    html: blk.b.html
                    horizontalAlignment: TextEdit.AlignHCenter
                    font.pixelSize: 15
                    topPadding: 4
                    bottomPadding: 4
                }
            }

            Component {
                id: termComp
                AiRichText { html: blk.b.html; color: root.fg; font.bold: true }
            }

            Component {
                id: defComp
                Item {
                    implicitHeight: defText.implicitHeight
                    Rectangle {
                        x: 4
                        width: 1
                        height: parent.height
                        color: CP.alpha(CP.cyan, 0.4)
                    }
                    AiRichText {
                        id: defText
                        x: 14
                        width: parent.width - 14
                        html: blk.b.html
                        color: root.fg
                        opacity: 0.85
                    }
                }
            }

            Component {
                id: quoteComp
                Item {
                    id: quote

                    // GitHub alerts: > [!NOTE] and friends
                    readonly property color tone: ({
                        note: CP.cyan2, tip: CP.neon, important: CP.magenta, warning: CP.yellow, caution: CP.red
                    })[blk.b.kind] ?? CP.magenta

                    implicitHeight: quoteBody.y + quoteBody.height

                    Rectangle {
                        width: 2
                        height: parent.height
                        color: CP.alpha(quote.tone, blk.b.kind ? 0.85 : 0.55)
                    }
                    Rectangle {
                        visible: blk.b.kind !== ""
                        anchors.fill: parent
                        color: CP.alpha(quote.tone, 0.05)
                    }
                    Text {
                        id: alertTitle
                        visible: blk.b.kind !== ""
                        x: 12
                        y: visible ? 2 : 0
                        height: visible ? implicitHeight : 0
                        text: "\u25e2 " + blk.b.kind.toUpperCase()
                        font.family: "Oxanium"
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 1.6
                        color: quote.tone
                    }
                    Loader {
                        id: quoteBody
                        x: 12
                        y: blk.b.kind !== "" ? alertTitle.height + 6 : 0
                        width: parent.width - 12
                        Component.onCompleted: setSource("AiMarkdownView.qml",
                            { blocks: blk.b.blocks, fg: Qt.binding(() => blk.b.kind ? root.fg : "#aebcc6") })
                    }
                }
            }

            Component {
                id: detailsComp
                Column {
                    id: det
                    property bool open: blk.b.open
                    spacing: 6

                    Item {
                        width: det.width
                        height: summary.implicitHeight + 8

                        CutShape {
                            anchors.fill: parent
                            fillColor: CP.alpha(CP.cyan, summaryMa.containsMouse ? 0.10 : 0.05)
                            strokeColor: CP.alpha(CP.cyan, det.open ? 0.45 : 0.25)
                            strokeWidth: 1
                            inset: 0.5
                            cutTopLeft: 5
                        }
                        Text {
                            id: chevron
                            x: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: det.open ? "\u25be" : "\u25b8"
                            font.pixelSize: 11
                            color: CP.cyan
                        }
                        AiRichText {
                            id: summary
                            x: 22
                            width: parent.width - 30
                            anchors.verticalCenter: parent.verticalCenter
                            html: blk.b.summary
                            color: root.fg
                            font.bold: true
                        }
                        // Over the summary: the whole bar toggles, links in it included
                        MouseArea {
                            id: summaryMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: det.open = !det.open
                        }
                    }

                    Loader {
                        x: 12
                        width: det.width - 12
                        active: det.open
                        visible: det.open
                        Component.onCompleted: setSource("AiMarkdownView.qml",
                            { blocks: blk.b.blocks, fg: Qt.binding(() => root.fg) })
                    }
                }
            }

            Component {
                id: notesComp
                Column {
                    spacing: 3
                    Rectangle {
                        width: Math.min(parent.width, 120)
                        height: 1
                        color: CP.alpha(CP.cyan, 0.35)
                    }
                    Item { width: 1; height: 2 }
                    Repeater {
                        model: blk.b.items
                        AiRichText {
                            required property var modelData
                            width: parent.width
                            html: '<span style="color:' + CP.cyan + '">[' + modelData.n + ']</span>&nbsp;' + modelData.html
                            font.pixelSize: 10
                            color: root.fg
                            opacity: 0.75
                        }
                    }
                }
            }
        }
    }
}
