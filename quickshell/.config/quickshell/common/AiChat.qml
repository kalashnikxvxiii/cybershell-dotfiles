// AiChat.qml - one conversation: its process, its transcript, its stream.
//
// A tab of the drawer. Everything that belongs to one exchange lives here, so
// several can run side by side: a reply keeps streaming into its own tab while
// another one is in front. AiState owns the list and picks the one shown
import Quickshell
import Quickshell.Io
import QtQuick

// A Scope, not an Item: it draws nothing, and an Item made by createObject()
// under the singleton warns that it was never placed in a scene
Scope {
    id: root

    // messages: committed turns. Each is { role, parts }, each part is one of
    //      { kind: "text", text }
    //      { kind: "tool", name, input, id, state: "running"|"done"|"error" }
    //      { kind: "error", text }
    //      { kind: "thinking", text, ms }
    //      { kind: "compact", trigger, pre, post, summary }
    // live: the reply being streamed, same shape, or null.
    // liveTail: characters of the trailing text part revealed so far.
    //
    // liveTail is kept OUT of live.parts on purpose: the typewriter rewrites it
    // sixty times a second, and reassigning live.parts at that rate would re-run
    // every delegate in the transcript instead of one Text
    property var messages: []
    property var live: null
    property string liveTail: ""
    property string _pending: ""
    property bool _turnDone: false
    property var todos: []
    property string suggestion: ""

    // Read only at launch: `/effort` moves it afterwards, this is what a
    // restart comes back up with
    property string effort: "medium"
    // The name the CLI gave a session picked up with /resume
    property string customTitle: ""

    readonly property string title: {
        if (root.customTitle !== "") return root.customTitle
        for (const m of root.messages)
            if (m.role === "user")
                return (m.parts[0]?.text ?? "").trim().split("\n")[0]
        return ""
    }

    // A resumed transcript is still being read back
    readonly property bool loading: loader.running

    // -- Turn telemetry ----------------------------
    //
    // What the `result` event reports about the turn just ended. The
    // composer shows the same numbers Cursor puts under its input
    property real lastDurationMs: 0
    property real lastCostUsd: 0
    property real elapsedMs: 0
    property real cacheStamp: 0
    property real _turnStart: 0
    // A turn whose only purpose is to carry a local CLI command: it must not
    // show up as a bubble, and its confirmation must not be typed out
    property bool _silent: false

    readonly property bool thinking: session.busy && !root._silent && root.live === null

    // A turn the user asked for is running: a silent command turn is not one
    readonly property bool working: session.busy && !root._silent

    // -- Turn activity -------------------------------------
    //
    // What the line above the composer reports while a turn runs: the
    // reasoning step in progress and what the tools have done so far
    property string liveThought: ""
    property real _thinkFrom: 0
    property int turnCalls: 0
    property int turnFails: 0

    // A reasoning block is open: the transcript shows it as in progress
    readonly property bool thinkingNow: root._thinkFrom > 0
    readonly property bool compacting: root.session.compacting
    readonly property real compactFrom: root.session.compactFrom

    // Which folded steps the reader has opened, by "<view>:<row>:<block>".
    // Kept here and not in the rows: the transcript rebuilds them whenever
    // the reply grows, and a step opened mid-turn must stay open
    property var openFolds: ({})

    function isOpen(key) { return root.openFolds[key] === true }

    // A copy, not the same object written back: assigning a var the object
    // it already holds is no change, and nothing bound to it would notice
    function toggleOpen(key) {
        const m = Object.assign({}, root.openFolds)
        if (m[key]) delete m[key]
        else m[key] = true
        root.openFolds = m
    }

    // -- Away: cache expiry and recap ---------------------------
    //
    // When the prompt cache runs out, the transcript says so under its last
    // turn, as the extension does: idle for how long, and how much the next
    // message will send again. With it, as the CLI does for a user coming
    // back, a recap of what was going on
    property bool cacheExpired: false
    property string recap: ""
    readonly property bool recapping: recapProc.running
    // User turns at the last recap: the CLI waits for two more before the
    // next one, and wants three before the first
    property int _recapTurns: -1

    readonly property int userTurns: root.messages.filter(m => m.role === "user").length

    // Anything a save has to record moved: one signal for AiState to listen
    // to, instead of one handler per field per tab
    signal changed()

    readonly property AiSession session: AiSession { effort: root.effort }

    readonly property var modelInfo: {
        for (const m of (root.session.models ?? []))
            if (m.value === root.session.model) return m
        // Before the initialize response lands there is no catalog yet
        return ({ value: root.session.model,
            displayName: root.session.model.toUpperCase(),
            description: "", supportedEffortLevels: [] })
    }

    // Which levels exist is a property of the model: Haiku has none at all, and
    // the 4.6 models stop at `high` + `max`
    readonly property var effortLevels: root.modelInfo.supportedEffortLevels ?? []

    onMessagesChanged: root.changed()
    // Saved with the tab: a restart must not forget when the cache dies
    onCacheStampChanged: { root._armExpiry(); root.changed() }
    onRecapChanged: root.changed()
    onEffortChanged: root.changed()
    onCustomTitleChanged: root.changed()

    Timer {
        interval: 100
        repeat: true
        // A silent command turn is not a turn the user asked for: it must not
        // start the stopwatch in the composer
        running: root.session.busy && !root._silent
        onTriggered: root.elapsedMs = Date.now() - root._turnStart
    }

    // There is no control request for effort: `set_model` does not carry it
    // and --effort is a launch flag. `/effort <level>` is handled locally by
    // the CLI and answers without calling the model, so it is the only hot path
    function setEffort(level) {
        if (!level || level === root.effort || root.session.busy) return false
        root.effort = level
        root._silent = true
        root.session.send("/effort " + level)
        return true
    }

    // -- Queue ---------------------------------------------
    //
    // What is sent while a turn runs (a compaction included) waits here and
    // goes out once the turn is over, one per turn, in order. The CLI would
    // take it at once and fold it into the turn in flight: the transcript
    // here has one reply per prompt, so the shell holds it instead
    property var queued: []
    property real liveAt: 0

    function unqueue(i) { root.queued = root.queued.filter((_, k) => k !== i) }

    function _uuid() {
        return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, c => {
            const r = Math.random() * 16 | 0
            return (c === "x" ? r : (r & 0x3 | 0x8)).toString(16)
        })
    }

    // paths travel as a list under the words, or alone: the model runs on this
    // machine and opens each one with its own tools
    function ask(text, paths) {
        const t = (text ?? "").trim()
        const p = paths ?? []
        if ((t === "" && p.length === 0) || root.loading) return false
        const body = p.length === 0 ? t
            : (t === "" ? "" : t + "\n\n")
            + "Attached paths:\n" + p.map(x => "- " + x).join("\n")
        if (root.session.busy) {
            root.queued = root.queued.concat([body])
            return true
        }
        root._dispatch(body)
        return true
    }

    function _dispatch(body) {
        const id = root._uuid()
        root.messages = root.messages.concat([
            { role: "user", uuid: id, at: Date.now(), parts: [{ kind: "text", text: body }] }
        ])
        root._clearAway()
        root._clearStream()
        root._resetTurn()
        root._turnStart = Date.now()
        root.elapsedMs = 0
        root.session.send(body, id)
        root.suggestion = ""
    }

    // -- /btw ------------------------------------------------
    //
    // A side question: answered from the context as it stands, a turn in
    // flight included, and never part of the conversation. The earlier ones
    // go with it, as the CLI does, so a follow-up makes sense
    property var side: null             // { question, answer, error, pending }
    property string _sideId: ""
    property var _sideHistory: []

    function askSide(question) {
        const q = (question ?? "").trim()
        if (q === "") return false
        root._sideId = root.session.askSide(q, root._sideHistory)
        root.side = { question: q, answer: "", error: "", pending: true }
        return true
    }

    function dismissSide() {
        root._sideId = ""
        root.side = null
    }

    // -- Rewind and fork ------------------------------------
    //
    // Both start from a prompt of this transcript. The CLI names it by the
    // uuid it was sent with; a row saved before rows kept one is found by its
    // words. A rewind is previewed first (a dry run): what it would undo is
    // on screen before anything is undone
    property var rewindPreview: null    // { row, action, uuid, pending, ok, files, ins, del, error }
    property string _rwPreviewId: ""
    property string _rwId: ""
    property var _rwDone: null
    property var _anchorDone: null

    function anchor(row, done) {
        const m = root.messages[row]
        if (!m || m.role !== "user" || anchorProc.running || root.session.sessionId === "") {
            done({})
            return
        }
        const text = m.parts[0]?.text ?? ""
        let n = 0
        for (let i = 0; i < row; i++)
            if (root.messages[i].role === "user" && (root.messages[i].parts[0]?.text ?? "") === text) n++
        root._anchorDone = done
        anchorProc.command = ["python3", Quickshell.env("HOME")
            + "/.config/quickshell/scripts/ai-sessions.py", "anchor", root.session.cwd,
            root.session.sessionId, m.uuid ?? "", String(n), text]
        anchorProc.running = true
    }

    // `action` is what the confirmation will do: "rewind" or "fork-rewind"
    function previewRewind(row, action) {
        root.rewindPreview = { row: row, action: action, pending: true }
        root.anchor(row, a => {
            if (!root.rewindPreview || root.rewindPreview.row !== row) return
            if (!a.uuid) {
                root.rewindPreview = { row: row, action: action, pending: false, ok: false,
                    error: "Prompt not found in the session transcript" }
                return
            }
            root.rewindPreview = { row: row, action: action, uuid: a.uuid, before: a.before, pending: true }
            root._rwPreviewId = root.session.rewindFiles(a.uuid, true)
        })
    }

    function cancelRewind() {
        root._rwPreviewId = ""
        root.rewindPreview = null
    }

    function rewindFiles(uuid, done) {
        root._rwDone = done ?? null
        root._rwId = root.session.rewindFiles(uuid, false)
    }

    Process {
        id: anchorProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let a = {}
                try { a = JSON.parse(text) } catch (e) {}
                const done = root._anchorDone
                root._anchorDone = null
                if (done) done(a)
            }
        }
    }

    function clear() {
        root.queued = []
        root.dismissSide()
        root._sideHistory = []
        root.cancelRewind()
        root.messages = []
        root.openFolds = ({})
        root.customTitle = ""
        root._forgetAway()
        root._clearStream()
        root._resetTurn()
        root.session.reset()
        root.todos = []
        root.suggestion = ""
    }

    // Not before the reply is committed: a new prompt clears the stream, and
    // the tail of the last answer may still be typing itself out
    function _dequeue() {
        if (root.session.busy || root.queued.length === 0
            || root.live !== null || root._turnDone) return
        const next = root.queued[0]
        root.queued = root.queued.slice(1)
        root._dispatch(next)
    }

    // Picks up a session the CLI has on disk: the process comes back with its
    // context, the transcript is read back from the same file for the eyes
    function resume(id, title, dir) {
        root.suggestion = ""
        root.todos = []
        root.queued = []
        root.messages = []
        root.openFolds = ({})
        root.customTitle = title ?? ""
        root._forgetAway()
        root._clearStream()
        root._resetTurn()
        root.stampFromTranscript(id, dir || root.session.defaultCwd)
        loader.command = ["python3", Quickshell.env("HOME")
            + "/.config/quickshell/scripts/ai-sessions.py", "load", dir || root.session.defaultCwd, id]
        loader.running = true
        root.session.reset(id, dir)
    }

    // The expiry is armed from the turn that wrote the cache: one shot, at
    // the moment the entry dies. A turn running by then restamps it anyway
    function _armExpiry() {
        root.cacheExpired = false
        const ttl = root.session.cacheTtlMs
        if (root.cacheStamp <= 0 || ttl <= 0) { expiry.stop(); return }
        expiry.interval = Math.max(1, root.cacheStamp + ttl - Date.now())
        expiry.restart()
    }

    function _expire() {
        if (root.session.busy) return
        root.cacheExpired = true
    }

    // Asked by the note once someone can read it, not at expiry: a tab
    // nobody looks at gets no recap, and a restart does not write one for
    // every expired tab at once
    function requestRecap() {
        if (!root.cacheExpired || recapProc.running || root.recap !== "") return
        const n = root.userTurns
        if (n < 3 || (root._recapTurns >= 0 && n - root._recapTurns < 2)) return
        root._recapTurns = n
        recapProc.command = ["claude", "-p", "--model", "haiku",
            "--tools", "", "--strict-mcp-config", "--setting-sources", "",
            "--no-session-persistence", "--output-format", "json",
            "--system-prompt", "You recap a conversation between a user and a coding "
            + "assistant, for the user coming back to it. Write in the language the user writes in."]
        recapProc.running = true
    }

    // The CLI's own instruction, word for word (2.1.289)
    readonly property string _recapPrompt: "The user stepped away and is coming back. "
        + "Recap in under 40 words, 1-2 plain sentences, no markdown. Lead with the overall "
        + "goal and current task, then the one next action. Skip root-cause narrative, fix "
        + "internals, secondary to-dos, and em-dash tangents."

    // The CLI recaps from inside the conversation, reusing its cache. Here the
    // cache is already gone when the recap is due, and reading the whole
    // context again would cost the very re-cache the note warns about: a
    // small model reads the tail of the transcript instead, a few hundred
    // tokens, and the conversation's cache is left alone
    function _digest() {
        const out = []
        let budget = 6000
        for (let i = root.messages.length - 1; i >= 0 && budget > 0; i--) {
            const m = root.messages[i]
            const bits = []
            for (const p of m.parts) {
                if (p.kind === "text") bits.push(p.text)
                else if (p.kind === "tool") bits.push("[" + p.name + "]")
                else if (p.kind === "compact" && p.summary) bits.push("[summary of the earlier conversation] " + p.summary)
            }
            let t = bits.join("\n").trim()
            if (t === "") continue
            if (t.length > 1500) t = t.slice(0, 500) + " [...] " + t.slice(-1000)
            out.unshift((m.role === "user" ? "USER: " : "ASSISTANT: ") + t)
            budget -= t.length
        }
        return out.join("\n\n")
    }

    // A new message: the note and the recap were about the pause it ends
    function _clearAway() {
        root.cacheExpired = false
        root.recap = ""
        recapProc.running = false
    }

    // A tab saved before the stamp was, or a session picked up with /resume:
    // the transcript says when the last request ran and what it cached
    function stampFromTranscript(id, dir) {
        if (!id || root.cacheStamp > 0) return
        stamper.command = ["python3", Quickshell.env("HOME")
            + "/.config/quickshell/scripts/ai-sessions.py", "usage", dir, id]
        stamper.running = true
    }

    // Another conversation in this tab: nothing of the last one carries over
    function _forgetAway() {
        root._clearAway()
        root._recapTurns = -1
        root.cacheStamp = 0
    }

    function _clearStream() {
        root.live = null
        root.liveTail = ""
        root._pending = ""
        root._turnDone = false
    }

    function _resetTurn() {
        root.liveThought = ""
        root._thinkFrom = 0
        root.turnCalls = 0
        root.turnFails = 0
    }

    // Closes the reasoning block in flight into the answer, with its timing
    function _endThinking() {
        if (root._thinkFrom <= 0) return
        root._appendPart({ kind: "thinking", text: root.liveThought,
            ms: Date.now() - root._thinkFrom })
        root._thinkFrom = 0
    }

    function _ensureLive() {
        if (root.live === null) {
            root.live = { role: "assistant", parts: [] }
            root.liveAt = Date.now()
        }
    }

    function _appendPart(part) {
        root._ensureLive()
        root.live = { role: "assistant", parts: root.live.parts.concat([part]) }
    }

    // Closes the trailing text part: whatever is still queued lands at once.
    // A new part arriving is what ends the typewriter on the previous one
    function _sealTail() {
        const full = root.liveTail + root._pending
        root.liveTail = ""
        root._pending = ""
        if (full.trim() !== "") root._appendPart({ kind: "text", text: full })
    }

    Process {
        id: loader
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const rows = JSON.parse(text)
                    if (Array.isArray(rows)) root.messages = rows
                } catch (e) {}
            }
        }
        stderr: SplitParser { onRead: l => console.warn("[ai-sessions]", l) }
    }

    Process {
        id: stamper
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                // A turn ended meanwhile: its numbers are the newer ones
                if (root.cacheStamp > 0) return
                try {
                    const r = JSON.parse(text)
                    if (!(r.at > 0)) return
                    // No TTL on record: the longer one, so the note may come
                    // late but never claims a cache that is still warm
                    root.session.restoreUsage(r.ttl > 0 ? r.ttl : 3600000, r.tokens ?? 0)
                    root.cacheStamp = r.at
                } catch (e) {}
            }
        }
        stderr: SplitParser { onRead: l => console.warn("[ai-sessions]", l) }
    }

    Timer {
        id: expiry
        repeat: false
        onTriggered: root._expire()
    }

    Process {
        id: recapProc
        running: false
        // Away from the project: no CLAUDE.md to load for a forty-word answer
        workingDirectory: "/tmp"
        // The prompt goes in on stdin, which is then closed: left open, the
        // CLI waits three seconds for more before it starts
        stdinEnabled: true
        onStarted: {
            recapProc.write(root._digest() + "\n\n" + root._recapPrompt)
            recapProc.stdinEnabled = false
        }
        stdout: StdioCollector {
            onStreamFinished: {
                // Killed by a new message: whatever came out is not wanted
                if (!root.cacheExpired) return
                try {
                    const r = JSON.parse(text)
                    if (r.is_error !== true && typeof r.result === "string")
                        root.recap = r.result.trim()
                } catch (e) {}
            }
        }
        stderr: SplitParser { onRead: l => console.warn("[ai-recap]", l) }
    }

    Connections {
        target: root.session

        // Late ones are dropped: the user has already moved on
        function onSuggested(text) {
            if (!root.session.busy && root.queued.length === 0) root.suggestion = text
        }

        function onPermissionModeChanged() { root.changed() }

        function onSessionIdChanged() { root.changed() }

        // Once a turn is over the next queued prompt goes. A beat later: the
        // turn's own handlers commit its reply first
        function onBusyChanged() {
            if (!root.session.busy && root.queued.length > 0) Qt.callLater(root._dequeue)
        }

        function onSideAnswered(id, text, error) {
            if (id !== root._sideId) return
            root._sideId = ""
            const q = root.side?.question ?? ""
            root.side = { question: q, answer: text, error: error, pending: false }
            if (error === "" && text !== "")
                root._sideHistory = root._sideHistory.concat([{ question: q, response: text }])
        }

        function onFilesRewound(id, dry, res, error) {
            if (id === root._rwPreviewId) {
                root._rwPreviewId = ""
                const p = root.rewindPreview
                if (!p) return
                root.rewindPreview = Object.assign({}, p, { pending: false,
                    ok: error === "" && res.canRewind === true,
                    files: (res.filesChanged ?? []).length,
                    ins: res.insertions ?? 0, del: res.deletions ?? 0,
                    error: error !== "" ? error : (res.error ?? "") })
                return
            }
            if (id !== root._rwId) return
            root._rwId = ""
            const ok = error === "" && res.canRewind === true
            if (ok) Toaster.success("CODE REWOUND", "Files restored to before the prompt", "\uf0e2")
            else Toaster.error("REWIND FAILED", error !== "" ? error : (res.error ?? "Nothing to rewind"), "\uf0e2")
            const done = root._rwDone
            root._rwDone = null
            if (done) done(ok)
        }

        // A model that does not offer the level in force would leave the UI
        // showing an effort the CLI is not running at
        function onModelChanged() {
            root.changed()
            const l = root.effortLevels
            // "medium" only when the model has it: the 4.6 models stop at
            // high + max, and asking for medium there changed nothing
            if (l.length > 0 && l.indexOf(root.effort) < 0)
                root.setEffort(l.indexOf("medium") >= 0 ? "medium" : l[0])
        }

        function onDeltaReceived(text) {
            if (root._silent) return
            root._ensureLive()
            root._pending += text
        }

        // Each reasoning block becomes a step of the answer once it closes:
        // the text that came before it is sealed first, so the order holds
        function onThinkingStarted() {
            if (root._silent) return
            root._sealTail()
            // The reply may open with it: the row must exist to show it
            root._ensureLive()
            root._thinkFrom = Date.now()
            root.liveThought = ""
        }

        function onThinkingReceived(text) {
            if (root._silent || text === "") return
            root.liveThought += text
        }

        function onBlockFinished() { root._endThinking() }

        function onToolStarted(name, input, id) {
            if (root._silent) return
            if (name === "TodoWrite") root.todos = input?.todos ?? []
            root.turnCalls++
            root._sealTail()
            root._appendPart({ kind: "tool", name: name, input: input,
                id: id, state: "running" })
        }

        function onToolResult(id, text, isError) {
            if (root._silent) return
            if (isError) root.turnFails++
            if (root.live === null) return
            root.live = { role: "assistant", parts: root.live.parts.map(p =>
                (p.kind === "tool" && p.id === id)
                    ? { kind: "tool", name: p.name, input: p.input, id: p.id,
                        state: isError ? "error" : "done" }
                    : p) }
        }

        function onTurnFinished(result) {
            // A command turn has no usage and no cost: it must not reset the
            // cache countdown nor overwrite the last real turn's numbers
            if (root._silent) { root._silent = false; return }
            root._endThinking()
            root.cacheStamp = Date.now()
            root.lastDurationMs = result?.duration_ms ?? 0
            root.lastCostUsd = result?.total_cost_usd ?? 0
            root._turnDone = true
        }

        // The summary closes everything before it: the text in flight is
        // sealed first, so the marker lands where the context was cut
        function onCompacted(meta) {
            root._endThinking()
            root._sealTail()
            root._appendPart({ kind: "compact", trigger: meta.trigger ?? "auto",
                pre: meta.pre_tokens ?? 0, post: meta.post_tokens ?? 0, summary: "" })
        }

        function onCompactSummary(text) {
            if (root.live === null) return
            root.live = { role: "assistant", parts: root.live.parts.map(p =>
                p.kind === "compact" && p.summary === ""
                    ? Object.assign({}, p, { summary: text }) : p) }
        }

        function onSessionError(message) {
            root._endThinking()
            root._sealTail()
            root._appendPart({ kind: "error", text: message })
            root._turnDone = true
        }
    }

    // 16ms/char is the feel we want, but the model emits in bursts far faster
    // than that: draining one character per tick would fall minutes behind on a
    // long answer. The rate scales with the backlog, so it never lags more than
    // about forty ticks while short replies still type one character at a time
    Timer {
        interval: 16
        repeat: true
        running: root._pending.length > 0 || root._turnDone
        onTriggered: {
            if (root._pending.length > 0) {
                const n = Math.max(1, Math.ceil(root._pending.length / 40))
                root.liveTail += root._pending.slice(0, n)
                root._pending = root._pending.slice(n)
                return
            }
            // Backlog drained and the turn is over: commit and go idle
            root._sealTail()
            if (root.live !== null) {
                root.messages = root.messages.concat(
                    [Object.assign({}, root.live, { at: root.liveAt })]
                )
                root.live = null
            }
            root._turnDone = false
            if (root.queued.length > 0) Qt.callLater(root._dequeue)
        }
    }
}
