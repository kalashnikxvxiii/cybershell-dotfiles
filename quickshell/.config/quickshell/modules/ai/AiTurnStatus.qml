// AiTurnStatus.qml - the turn in flight, above the composer, gone once it ends.
//
// The spinner and its verb say the model is still at it; the counter says how
// much machinery it has run and how much of it failed. What the turn leaves
// behind (each reasoning step, each group of tool calls) is written into the
// transcript instead. The chevron unfolds the reasoning in progress, which
// the CLI streams as summaries (--thinking-display summarized).
//
// While the context is being summarized the verb gives way to the CLI's own
// "Compacting conversation", with a bar and the time spent. The bar cannot
// fill: the CLI reports the start and the end of a compaction, nothing in
// between, so it sweeps like a terminal's indeterminate progress
import QtQuick
import "../../common"
import "../../common/Colors.js" as CP
import "AiSpinnerVerbs.js" as Verbs

Item {
    id: root

    required property var chat
    property bool expanded: false

    readonly property color fg: "#d8e0e8"
    readonly property int panelMax: 180

    readonly property bool working: root.chat?.working ?? false
    readonly property int calls: root.chat?.turnCalls ?? 0
    readonly property int fails: root.chat?.turnFails ?? 0
    readonly property string thought: root.chat?.liveThought ?? ""
    readonly property bool compacting: root.chat?.compacting ?? false
    readonly property real compactFrom: root.chat?.compactFrom ?? 0

    property string verb: "Thinking"
    property int dots: 0
    property real now: 0
    // The lit run of the bar, as a cell index
    property int sweep: 0

    function _pickVerb() {
        const l = Verbs.verbs
        let v = root.verb
        while (v === root.verb) v = l[Math.floor(Math.random() * l.length)]
        root.verb = v
    }

    visible: root.working
    height: visible ? col.height : 0

    // Every turn opens on a fresh word, folded
    onWorkingChanged: {
        root.expanded = false
        if (root.working) root._pickVerb()
    }

    // The CLI keeps one word per turn; here they take turns, the way the
    // marquee of a long wait should
    Timer {
        interval: 3600
        repeat: true
        running: root.working
        onTriggered: root._pickVerb()
    }

    Timer {
        interval: 380
        repeat: true
        running: root.working
        onTriggered: root.dots = (root.dots + 1) % 4
    }

    // Stepped, not eased: one cell per tick, like the rest of the HUD
    Timer {
        interval: 70
        repeat: true
        running: root.compacting
        triggeredOnStart: true
        onTriggered: {
            root.sweep = (root.sweep + 1) % (bar.cells + bar.run)
            root.now = Date.now()
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: 6

        // ── The reasoning in progress, unfolded ──────────────────────────
        Item {
            id: panel
            width: parent.width
            visible: root.expanded
            height: visible ? Math.min(Math.max(thinkText.implicitHeight, 14) + 16, root.panelMax) : 0
            clip: true

            CutShape {
                anchors.fill: parent
                fillColor: CP.alpha(CP.void2, 0.85)
                strokeColor: CP.alpha(CP.magenta, 0.30)
                strokeWidth: 1
                inset: 0.5
                cutTopRight: 8
                cutBottomLeft: 8
            }

            Flickable {
                id: flick
                anchors.fill: parent
                anchors.margins: 8
                contentWidth: width
                contentHeight: thinkText.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                // Follows the reasoning as it streams, unless the reader has
                // scrolled up into it
                property bool follow: true
                onMovementEnded: follow = atYEnd
                onContentHeightChanged:
                    if (follow) contentY = Math.max(0, contentHeight - height)

                Text {
                    id: thinkText
                    width: flick.width
                    visible: root.thought !== ""
                    text: root.thought
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.italic: true
                    lineHeight: 1.15
                    color: CP.alpha(root.fg, 0.55)
                }
            }

            // Not every step reasons out loud
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                visible: root.thought === ""
                text: "NO REASONING IN THIS STEP YET"
                font.family: "Oxanium"
                font.pixelSize: 9
                font.letterSpacing: 1.5
                color: CP.alpha(root.fg, 0.35)
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 3
                width: 2
                visible: flick.contentHeight > flick.height
                y: flick.y + flick.visibleArea.yPosition * flick.height
                height: Math.max(18, flick.visibleArea.heightRatio * flick.height)
                color: CP.alpha(CP.magenta, flick.moving ? 0.55 : 0.25)
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }

        // ── Status line ──────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 18

            Row {
                id: line
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7

                // The asterisk breathing into a dot and back, a frame at a time
                Text {
                    id: spinner
                    readonly property var frames:
                        ["\u00b7", "\u2722", "\u2733", "\u2736", "\u273b", "\u273d",
                         "\u273b", "\u2736", "\u2733", "\u2722"]
                    property int frame: 0
                    width: 12
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenter: parent.verticalCenter
                    text: frames[frame]
                    font.family: "DejaVu Sans"
                    font.pixelSize: 13
                    color: CP.magenta

                    Timer {
                        interval: 110
                        repeat: true
                        running: root.working
                        onTriggered: spinner.frame = (spinner.frame + 1) % spinner.frames.length
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: root.compacting ? "COMPACTING CONVERSATION" : root.verb.toUpperCase()
                        font.family: "Oxanium"
                        font.pixelSize: 10
                        font.letterSpacing: 1.5
                        font.bold: true
                        color: CP.yellow
                    }

                    // A fixed slot: the word does not shuffle as the dots fill
                    Text {
                        width: dotsMetrics.width
                        text: "...".slice(0, root.dots)
                        font: dotsMetrics.font
                        color: CP.yellow

                        TextMetrics {
                            id: dotsMetrics
                            text: "..."
                            font.family: "Oxanium"
                            font.pixelSize: 10
                            font.letterSpacing: 1.5
                            font.bold: true
                        }
                    }
                }

                // -- Compaction: a sweep and the seconds it has taken ----------
                Row {
                    id: bar
                    readonly property int cells: 16
                    readonly property int run: 5
                    visible: root.compacting
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Repeater {
                        model: bar.cells

                        Rectangle {
                            required property int index
                            readonly property bool lit: index <= root.sweep
                                && index > root.sweep - bar.run
                            width: 4
                            height: 7
                            color: lit ? CP.yellow : CP.alpha(CP.yellow, 0.14)
                        }
                    }
                }

                Text {
                    visible: root.compacting
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.max(0, Math.floor((root.now - root.compactFrom) / 1000)) + "S"
                    font.family: "Oxanium"
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                    color: CP.alpha(root.fg, 0.5)
                }

                Rectangle {
                    visible: root.calls > 0 && !root.compacting
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 10
                    color: CP.alpha(root.fg, 0.25)
                }

                Text {
                    visible: root.calls > 0 && !root.compacting
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.StyledText
                    text: root.calls + (root.calls === 1 ? " TOOL CALL" : " TOOL CALLS")
                        + (root.fails > 0
                            ? " \u00b7 <font color='" + CP.red + "'>" + root.fails + " FAILED</font>"
                            : "")
                    font.family: "Oxanium"
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                    color: CP.alpha(CP.cyan, 0.7)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.expanded ? "\uf077" : "\uf078"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 9
                    color: CP.alpha(CP.magenta, hover.containsMouse ? 1 : 0.65)
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
            }

            MouseArea {
                id: hover
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: line.width + 8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expanded = !root.expanded
            }
        }
    }
}
