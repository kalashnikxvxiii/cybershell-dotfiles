// AiMessage.qml — one turn of the transcript.
//
// The two roles are drawn differently on purpose: what you asked is a framed
// card you can find again by scanning the margin, what came back is plain
// full-width prose with one marker per step in the gutter. The "USER"/"CLAUDE"
// labels are gone — the frame and the markers already say who is speaking, and
// they cost a line each.
//
// The streaming tails is formatted as it types, as the extension does. It is
// parsed a dozen times a second, not on every character, and split in two:
// the blocks that can no longer change are rebuilt only when one more joins
// them, the one still being typed is the only item redrawn on each pass
import QtQuick
import "../../common"
import "../../common/Colors.js" as CP
import "AiMarkdown.js" as Md

Item {
    id: root

    required property string role
    required property var    parts
    property real at: 0
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

    function _stamp() {
        const d = new Date(root.at)
        return Qt.formatDateTime(d, d.toDateString() === new Date().toDateString()
            ? "HH:mm" : "dd/MM HH:mm")
    }

    // What ask() writes under the words of a prompt: "Attached paths:" and a
    // "- " line per path. On screen the paths are chips at the top of the
    // card and the words are what was typed; a prompt the drawer did not
    // write that way stays as it is
    function _splitPaths(text) {
        const tag = "Attached paths:\n"
        const at = text.startsWith(tag) ? 0 : text.lastIndexOf("\n\n" + tag)
        if (at < 0) return { words: text, paths: [] }
        const lines = text.slice(at === 0 ? tag.length : at + 2 + tag.length).split("\n")
        if (!lines.every(l => l.startsWith("- "))) return { words: text, paths: [] }
        return { words: text.slice(0, at), paths: lines.map(l => l.slice(2)) }
    }

    readonly property var attached: root.isUser && (root.parts?.length ?? 0) > 0
        ? root._splitPaths(root.parts[0].text ?? "").paths : []

    // A text part is parsed once: the reply in flight rebuilds its block list
    // on every step, and a part whose blocks keep the same object is not laid
    // out again. Only what the last pass used is kept. A plain holder, not a
    // property of its own: writing it must not re-run the binding that reads it
    readonly property var _memo: ({ map: {} })

    function _md(text, next) {
        const k = (root.isUser ? "u" : "a") + text
        const b = root._memo.map[k] ?? Md.parse(text, null, root.isUser)
        next[k] = b
        return b
    }

    // The full view's blocks. Consecutive tool calls collapse into a single
    // "tools" block: on their own they are noise, as a group they are one
    // step of the answer that can be unfolded
    function _group(list, next) {
        const out = []
        for (const p of list) {
            if (p.kind === "tool") {
                const last = out.length > 0 ? out[out.length - 1] : null
                if (last !== null && last.kind === "tools") last.calls.push(p)
                else out.push({ kind: "tools", calls: [p] })
            } else if (p.kind === "text") {
                // One block per text part, so one marker per part: its code
                // and its lists are not steps of their own
                const t = root.isUser ? root._splitPaths(p.text).words : p.text
                if (t !== "") out.push({ kind: "md", blocks: root._md(t, next) })
            } else {
                out.push(p)
            }
        }
        return out
    }

    // Focus view: every run of reasoning and tool calls between two pieces of
    // text becomes one fold. Unfolded it lists the run step by step, in the
    // order it happened, as the extension does: no groups inside the fold
    function _fold(list, next) {
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
            out.push(...root._group([p], next))
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
        const next = {}
        const out = root.focusView ? root._fold(list, next) : root._group(list, next)
        root._memo.map = next
        return out
    }

    // The blocks are drawn from a model that only grows and shrinks at its
    // end, never from the array itself: a new array in a Repeater rebuilds
    // every item of it, and the reply in flight gets a new one at each step.
    // That rebuild is what made the transcript flash while tools ran
    ListModel { id: blockModel }

    function _syncBlocks() {
        const n = root.blocks.length
        while (blockModel.count < n) blockModel.append({ k: 0 })
        if (blockModel.count > n) blockModel.remove(n, blockModel.count - n)
    }

    onBlocksChanged: root._syncBlocks()
    Component.onCompleted: root._syncBlocks()

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

        HoverHandler { id: hover }

        // A prompt's actions: fork from it, rewind the code to before it. In
        // the corner, on hover, as the extension shows them; the menu itself
        // is the chat view's, over everything
        AiIconButton {
            id: actions
            visible: root.isUser && root.rowIndex >= 0
                && (hover.hovered || AiState.menuRow === root.rowIndex)
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 4
            anchors.topMargin: 4
            frame: false
            glyph: "\uf0e2"
            glyphSize: 11
            accent: CP.cyan
            onTriggered: AiState.messageMenuRequested(root.rowIndex, actions)
        }

        // When it was said: on hover, in the corne, ahead of the actions
        Rectangle {
            visible: hover.hovered && root.at > 0
            anchors.right: root.isUser ? actions.left : parent.right
            anchors.top: parent.top
            anchors.rightMargin: 6
            anchors.topMargin: root.isUser ? 6 : 0
            width: stamp.implicitWidth + 8
            height: stamp.implicitHeight + 2
            color: CP.alpha(CP.void2, 0.92)

            Text {
                id: stamp
                anchors.centerIn: parent
                text: root._stamp()
                font.family: "Oxanium"
                font.pixelSize: 9
                font.letterSpacing: 1
                color: CP.alpha(root.fg, 0.55)
            }
        }

        Column {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.isUser ? 10 : 0
            // Clear of the actions button
            anchors.rightMargin: root.isUser ? 26 : 0
            spacing: 7

            // The paths sent with the prompt, ahead of its words
            Flow {
                visible: root.attached.length > 0
                width: body.width
                spacing: 5

                Repeater {
                    model: root.attached

                    AiPathChip {
                        required property string modelData
                        path: modelData
                        maxWidth: body.width
                    }
                }
            }

            Repeater {
                model: blockModel

                Item {
                    id: block
                    required property int index
                    readonly property var seg: root.blocks[block.index] ?? { kind: "md", blocks: [] }
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

                    // The thread to the next marker: a hairline that stops
                    // short of both diamonds
                    Rectangle {
                        readonly property bool linked: block.index < blockModel.count - 1
                            ? (root.blocks[block.index + 1]?.kind ?? "") !== "compact"
                            : root.tailText !== ""
                        visible: !root.isUser && block.seg.kind !== "compact" && linked
                        x: 3
                        y: 14
                        width: 1
                        height: Math.max(0, block.height + body.spacing - 13)
                        color: root.accent
                        opacity: 0.3
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

            // The streaming tail, laid out like a committed text part: same
            // marker, same margin, so nothing moves when it is sealed
            Item {
                id: tail
                visible: root.tailText !== ""
                width: body.width
                height: visible ? Math.max(tailDone.height + tailLast.height, 14) : 0
                
                property var done: []
                property var last: []
                property string _doneKey: ""

                function reparse() {
                    if (root.tailText === "") {
                        tail.done = []
                        tail.last = []
                        tail._doneKey = ""
                        return
                    }
                    const b = Md.parse(root.tailText)
                    const d = b.slice(0, -1)
                    const k = JSON.stringify(d)
                    if (k !== tail._doneKey) {
                        tail._doneKey = k
                        tail.done = d
                    }
                    tail.last = b.slice(-1)
                }

                // Throttle, not debounce: a steady stream must still redraw
                Timer {
                    id: parseTick
                    interval: 80
                    onTriggered: tail.reparse()
                }
                Connections {
                    target: root
                    function onTailTextChanged() {
                        // The first characters show at once, the rest is passes
                        if (root.tailText === "" || tail.last.length === 0) tail.reparse()
                        else if (!parseTick.running) parseTick.start()
                    }
                }
                Component.onCompleted: tail.reparse()

                Rectangle {
                    visible: !root.isUser
                    x: 1
                    y: 5
                    width: 5
                    height: 5
                    rotation: 45
                    color: root.accent
                    opacity: 0.75
                }

                AiMarkdownView {
                    id: tailDone
                    x: root.isUser ? 0 : 14
                    width: parent.width - x
                    blocks: tail.done
                    fg: root.fg
                }

                AiMarkdownView {
                    id: tailLast
                    x: tailDone.x
                    y: tailDone.height
                    width: tailDone.width
                    blocks: tail.last
                    prevBlock: tail.done.length > 0 ? tail.done[tail.done.length - 1] : null
                    fg: root.fg
                }
            }
        }
    }
}
