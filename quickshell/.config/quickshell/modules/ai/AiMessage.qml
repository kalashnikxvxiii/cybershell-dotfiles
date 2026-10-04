// AiMessage.qml — one turn of the transcript.
//
// The two roles are drawn differently on purpose: what you asked is a framed
// card you can find again by scanning the margin, what came back is plain
// full-width prose with one marker per step in the gutter. The "USER"/"CLAUDE"
// labels are gone — the frame and the markers already say who is speaking, and
// they cost a line each.
//
// Markdown is rendered only on committed text: parsing a whole answer sixty
// times a second while it types would burn the frame budget for nothing. The
// streaming tail is plain text, which is also the right look for a typewriter.
import QtQuick
import "../../common"
import "../../common/Colors.js" as CP
import "AiMarkdown.js" as Md

Item {
    id: root

    required property string role
    required property var    parts
    property string tailText: ""
    // Where the row sits in the transcript: the key its folds open under
    property int rowIndex: -1
    // The reply in flight, with a reasoning block still open at its tail
    property bool live: false
    property bool thinkingLive: false

    readonly property bool  isUser: root.role === "user"
    readonly property color accent: isUser ? CP.cyan : CP.magenta
    readonly property color fg: "#d8e0e8"
    readonly property bool  focusView: AiState.focusView

    implicitHeight: frame.implicitHeight
    height: implicitHeight

    // The full view's blocks. Consecutive tool calls collapse into a single
    // "tools" block: on their own they are noise, as a group they are one
    // step of the answer that can be unfolded
    function _group(list) {
        const out = []
        for (const p of list) {
            if (p.kind === "tool") {
                const last = out.length > 0 ? out[out.length - 1] : null
                if (last !== null && last.kind === "tools") last.calls.push(p)
                else out.push({ kind: "tools", calls: [p] })
            } else if (p.kind === "text") {
                // One block per text part, so one marker per part: its code
                // and its lists are not steps of their own
                out.push({ kind: "md", blocks: Md.parse(p.text) })
            } else {
                out.push(p)
            }
        }
        return out
    }

    // Focus view: every run of reasoning and tool calls between two pieces of
    // text becomes one fold. Unfolded it lists the run step by step, in the
    // order it happened, as the extension does: no groups inside the fold
    function _fold(list) {
        const out = []
        let run = []
        const flush = () => {
            if (run.length === 0) return
            const tools = run.filter(p => p.kind === "tool")
            let running = ""
            for (const t of tools) if (t.state === "running") { running = t.name; break }
            out.push({ kind: "fold",
                parts: run,
                calls: tools.length,
                fails: tools.filter(t => t.state === "error").length,
                ms: run.reduce((n, p) => n + (p.kind === "thinking" ? (p.ms ?? 0) : 0), 0),
                running: running,
                streaming: run.some(p => p.streaming === true),
                thinkingOnly: tools.length === 0 && run.some(p => p.kind === "thinking"),
                steps: run.length })
            run = []
        }
        for (const p of list) {
            if (p.kind === "tool" || p.kind === "thinking") { run.push(p); continue }
            flush()
            out.push(...root._group([p]))
        }
        flush()
        return out
    }

    readonly property var blocks: {
        let list = root.parts ?? []
        // The block being reasoned right now, ahead of its part: it only
        // becomes one when it closes
        if (root.thinkingLive)
            list = list.concat([{ kind: "thinking", text: "", ms: 0, streaming: true }])
        return root.focusView ? root._fold(list) : root._group(list)
    }

    Item {
        id: frame
        anchors.left: parent.left
        anchors.right: parent.right
        implicitHeight: body.implicitHeight + (root.isUser ? 20 : 0)

        CutShape {
            anchors.fill: parent
            visible: root.isUser
            fillColor: CP.alpha(CP.cyan, 0.05)
            strokeColor: CP.alpha(CP.cyan, 0.28)
            strokeWidth: 1
            inset: 0.5
            cutTopLeft: 5
            cutBottomRight: 5
        }

        Column {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.isUser ? 10 : 0
            spacing: 7

            Repeater {
                model: root.blocks

                Item {
                    id: block
                    required property var modelData
                    required property int index
                    readonly property var seg: modelData
                    // The view is part of the key: a fold and a tool group
                    // at the same place are not the same thing to open
                    readonly property string key: (root.focusView ? "f:" : "n:")
                        + root.rowIndex + ":" + block.index
                    readonly property bool open: AiState.chat?.isOpen(block.key) ?? false

                    function toggle() { AiState.chat.toggleOpen(block.key) }

                    width: body.width
                    implicitHeight: Math.max(content.implicitHeight, 14)
                    height: implicitHeight

                    // Step marker. A square on its corner, not a disc: nothing
                    // else in the shell has a round edge. A fold's says how
                    // its step went, the way the extension's dot does
                    Rectangle {
                        visible: !root.isUser && block.seg.kind !== "compact"
                        x: 1
                        y: 5
                        width: 5
                        height: 5
                        rotation: 45
                        color: block.seg.kind === "fold" && content.item
                            ? content.item.dot : root.accent
                        opacity: 0.75
                    }

                    Loader {
                        id: content
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: root.isUser || block.seg.kind === "compact" ? 0 : 14
                        sourceComponent: block.seg.kind === "tools" ? toolsComp
                            : block.seg.kind === "thinking" ? thoughtComp
                            : block.seg.kind === "fold" ? foldComp
                            : block.seg.kind === "compact" ? compactComp
                            : block.seg.kind === "error" ? errComp
                            : mdComp
                    }

                    Component {
                        id: mdComp
                        AiMarkdownView { blocks: block.seg.blocks; fg: root.fg }
                    }

                    Component {
                        id: toolsComp
                        AiToolGroup {
                            calls: block.seg.calls
                            expanded: block.open
                            onToggled: block.toggle()
                        }
                    }

                    Component {
                        id: thoughtComp
                        AiThoughtBlock {
                            streaming: block.seg.streaming === true
                            text: streaming ? AiState.liveThought : (block.seg.text ?? "")
                            ms: block.seg.ms ?? 0
                            expanded: block.open
                            onToggled: block.toggle()
                        }
                    }

                    Component {
                        id: foldComp
                        AiFocusFold {
                            fold: block.seg
                            live: root.live && block.index === root.blocks.length - 1
                            waiting: AiState.session?.pendingPermission != null
                            keyBase: block.key
                            expanded: block.open
                            onToggled: block.toggle()
                        }
                    }

                    Component {
                        id: compactComp
                        AiCompactBlock {
                            part: block.seg
                            expanded: block.open
                            onToggled: block.toggle()
                        }
                    }

                    Component {
                        id: errComp
                        Text {
                            text: block.seg.text
                            wrapMode: Text.Wrap
                            font.family: "Oxanium"
                            font.pixelSize: 10
                            color: CP.red
                        }
                    }
                }
            }

            // The streaming tail: plain text, no markdown pass. The caret is
            // appended to the string rather than drawn as an overlay — finding
            // where the last glyph landed inside a wrapped Text costs more than
            // relaying two hundred characters twice a second
            Text {
                id: tail
                visible: root.tailText !== ""
                width: body.width
                leftPadding: root.isUser ? 0 : 14
                text: root.tailText + (caret.on ? "\u258c" : "\u2002")
                wrapMode: Text.Wrap
                font.family: "Oxanium"
                font.pixelSize: 12
                lineHeight: 1.35
                color: root.fg

                QtObject { id: caret; property bool on: true }
                Timer {
                    interval: 530
                    repeat: true
                    running: tail.visible
                    onTriggered: caret.on = !caret.on
                }
            }
        }
    }
}
