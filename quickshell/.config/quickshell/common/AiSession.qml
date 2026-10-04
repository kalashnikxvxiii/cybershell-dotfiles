// AiSession.qml - persistent headless `claude` process, NDJSON both ways.
//
// One long-lived process per shell instance: turns go in on stdin, events come
// back on stdout one JSON object per line. Keeping the process alive is what
// makes follow-up turns cheap (the prompt cache stays warm) and removes the
// ~1.5s CLI startup from every message.
//
// Tool permissions travel over the same pipes. `--permission-prompt-tool stdio`
// is what turns them on: without it the CLI denies anything that would prompt
// and just tells the model it has no permission. Verified on CLI 2.1.283
import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    property string model: "sonnet"
    // Where it thinks from: CLAUDE.md and the memory index live here. The CLI
    // also files its sessions by cwd, and --resume only finds them from there:
    // a session picked up from elsewhere runs in its own directory
    readonly property string defaultCwd: Quickshell.env("HOME") + "/Documenti/DE-docs"
    property string cwd: defaultCwd
    readonly property string sessionId: _sessionId
    readonly property bool busy: _busy
    readonly property bool alive: proc.running

    // Pending tool authorization, or null. The UI binds to this
    readonly property var pendingPermission: _pending

    // What the session reports about itself. The `init` EVENT only arrives when
    // the first turn starts, so it cannot fill a palette on a panel that was
    // just opened: the list below comes from the `initialize` control request,
    // which is answered immediately and carries descriptions as well as names
    readonly property var slashCommands: {
        const t = root._termCommands
        return (root._allCommands ?? []).filter(c => t.indexOf(c.name) < 0)
    }
    readonly property string permissionMode: _permissionMode

    // Prompt-cache telemetry from the last `result`
    readonly property real cacheTokens: _cacheTokens
    readonly property real cacheTtlMs: _cacheTtlMs
    // The prompt of the last request, cached or not: what the next message
    // has to send again once the cache is gone. Read per request, from the
    // assistant message, because `result` sums every request of the turn
    readonly property real contextTokens: _contextTokens

    // The tools the model is given. --tools is a whitelist: anything left
    // out does not exist for the model, which is why it once answered it
    // had no way to search the web
    readonly property string tools: "Read,Write,Edit,Glob,Grep,Bash,WebSearch,WebFetch"

    // -- Account and plan limits ----------------------------
    //
    // The login, from the initialize response: { email, organization,
    // subscriptionType, apiProvider }. null until the CLI has answered
    readonly property var account: _account
    // `get_usage` as the CLI answers it: the plan windows, plus what local
    // sessions say is eating into them. The extension calls it through an
    // API marked experimental: verified on CLI 2.1.288. null until asked
    readonly property var usage: _usage
    readonly property bool usageLoading: _usageId !== ""
    readonly property string usageError: _usageError

    // The bars, in the extension's order: the 5h session, the week, the
    // weekly Sonnet cap on the plans that have one, then any per-model cap
    readonly property var usageWindows: {
        const l = root._usage?.rate_limits
        if (!l) return []
        const plan = root._usage.subscription_type
        const out = [{ label: "Session (5hr)", w: l.five_hour },
            { label: "Weekly (7 days)", w: l.seven_day }]
        if (plan === "max" || plan === "team" || plan === null)
            out.push({ label: "Weekly Sonnet", w: l.seven_day_sonnet })
        for (const m of (l.model_scoped ?? []))
            out.push({ label: "Weekly " + m.display_name,
                w: { utilization: m.utilization, resets_at: m.resets_at } })
        return out.filter(x => x.w && x.w.utilization !== null && x.w.utilization !== undefined)
            .map(x => ({ label: x.label, utilization: x.w.utilization, resetsAt: x.w.resets_at ?? "" }))
    }

    // What to sat instead of the bars, or "" when the bars say it all
    readonly property string usageNote: {
        if (root._usageError !== "") return "Failed to load usage data"
        if (root._usage === null) return root.usageLoading ? "Loading usage data\u2026" : ""
        if (root._usage.rate_limits_available !== true)
            return "Plan limits aren't available for this login method."
        return ""
    }

    signal deltaReceived(string text)   // token chunk, for the typewriter
    signal blockFinished()              // content_block_stop: safe to render markdown
    signal thinkingStarted()            // a reasoning block opens
    signal thinkingReceived(string text)    // its summary, as it streams
    signal toolStarted(string name, var input, string id)
    signal toolResult(string id, string text, bool isError)
    signal turnFinished(var result)
    signal sessionError(string message)
    // The context was summarized, by /compact or because it was full:
    // { trigger, pre_tokens, post_tokens, duration_ms }
    signal compacted(var meta)
    signal compactSummary(string text)      // what the model will remember of it

    // A summary is being written. The CLI says when it starts and when it
    // ends, nothing in between: there is no progress to report
    readonly property bool compacting: _compacting
    readonly property real compactFrom: _compactFrom

    // Read only at launch: `/effort` moves it afterwards, this is what a
    // restart (CLEAR, a crash, a shell reload) comes back up with
    property string effort: ""
    property string _sessionId: ""
    property bool _busy: false
    property var _pending: null
    property var _queue: []         // messages written before the process is up
    // Tools the user approved for the whole session, via "ALWAYS ALLOW"
    property var _allowlist: ({})
    property var _allCommands: []
    property var _models: []
    // The model catalog the CLI advertises, with display names and the effort
    // levels each one actually supports
    readonly property var models: _models
    // Commands whose UX is bound to a terminal: dead weight in a drawer
    property var _termCommands: ["doctor", "color", "focus", "reload-plugins"]
    property string _permissionMode: "manual"
    property real _cacheTokens: 0
    property real _cacheTtlMs: 0
    property real _contextTokens: 0
    property var _account: null
    property var _usage: null
    property string _usageId: ""
    property string _usageError: ""
    // request_id -> what to put back if the CLI refuses the change
    property var _ctl: ({})
    // This launch passed --resume and the CLI has not confirmed it yet
    property bool _resuming: false
    // A mode to put back once the CLI anwers initialize. A launch flag would
    // not do: the response reports "default" even when launched with manual
    property string _wantMode: ""
    // What a save must record: a mode still waiting to be put back counts,
    // or a save before the drawer is first opened would overwrite it
    readonly property string durableMode: _wantMode !== "" ? _wantMode : _permissionMode
    // What the last launch flushed from the queue, to replay if the resume dies
    property var _replay: []
    // The kill in reset() is ours: its exit is not a crash to report
    property bool _stopping: false
    property bool _compacting: false
    property real _compactFrom: 0
    // The next synthetic user message is the summary of this boundary
    property bool _awaitSummary: false

    // -- Public API ---------------------------------------------

    // Pre-warm on drawer open so the first message does not pay for startup
    function start() { if (!proc.running) proc.running = true }

    function send(text) {
        if (!text) return
        root._busy = true
        _push({
            type: "user",
            message: { role: "user", content: [ { type: "text", text: text }] }
        })
    }

    function interrupt() {
        if (!proc.running) return
        _push({
            type: "control_request",
            request_id: "int_" + Date.now(),
            request: { subtype: "interrupt" }
        })
    }

    function approve(alwaysAllow) {
        if (!root._pending) return
        const p = root._pending
        if (alwaysAllow) {
            const l = root._allowlist
            l[p.tool_name] = true
            root._allowlist = l         // reassign: nested writes do not notify
        }
        root._pending = null
        _respondPermission(p.request_id, { behavior: "allow", updateInput: p.input })
    }

    function deny(reason) {
        if (!root._pending) return
        const p = root._pending
        root._pending = null
        _respondPermission(p.request_id, {
            behavior: "deny",
            message: reason ? reason : "Denied by the user."
        })
    }

    // Both of these travel on the same stdin the turns do, so neither costs a
    // restart and neither wipes the conversation. The value is applied
    // optimistically and rolled back if the control_response says no.
    // Verified against the control_request schema of CLI 2.1.284
    function setModel(name) {
        if (!name || name === root.model) return
        const id = "md_" + Date.now()
        root._track(id, "model", root.model)
        root.model = name
        _push({ type: "control_request", request_id: id,
            request: { subtype: "set_model", model: name } })
    }

    function setPermissionMode(mode) {
        if (!mode || mode === root._permissionMode) return
        const id = "pm_" + Date.now()
        root._track(id, "mode", root._permissionMode)
        root._permissionMode = mode
        _push({ type: "control_request", request_id: id,
            request: { subtype: "set_permission_mode", mode: mode } })
    }

    function _track(id, what, prev) {
        const m = root._ctl
        m[id] = { what: what, prev: prev }
        root._ctl = m       // reassign: nested writes do not notify
    }

    // Costs no turn and no tokens: the CLI answers from the API and from its
    // own transcripts. The last answer stays up while the next one is coming
    function requestUsage() {
        if (root._usageId !== "") return
        root._usageError = ""
        root._usageId = "usage_" + Date.now()
        _push({ type: "control_request", request_id: root._usageId,
            request: { subtype: "get_usage" } })
    }

    // Picks a previous conversation back up: the next launch passes --resume
    // and the CLI reloads the context from its own transcript
    function restore(id, dir) {
        if (proc.running) return
        root._sessionId = id ?? ""
        root.cwd = dir || root.defaultCwd
    }

    function restoreMode(m) { if (!proc.running) root._wantMode = m ?? ""}

    readonly property string _initId: "boot_initialize"

    // Asked once, as soon as the process is up: this is what the palette is
    // built from, and it costs no turn and no tokens
    function _requestInit() {
        _push({ type: "control_request", request_id: root._initId,
            request: { subtype: "initialize" } })
    }

    // Ends the process for good: the tab it belonged to is gone
    function stop() {
        root._busy = false
        root._pending = null
        root._compacting = false
        if (proc.running) {
            root._stopping = true
            proc.running = false
        }
    }

    // Wipes the conversation: the process is the conversation, so it restarts.
    // Given an id, it come back up as that session instead (/resume)
    function reset(id, dir) {
        root._pending = null
        root._sessionId = id ?? ""
        root.cwd = dir || root.defaultCwd
        root._resuming = false
        root._wantMode = ""         // a new chat starts from the default mode
        root._busy = false
        root._compacting = false
        root._awaitSummary = false
        root._queue = []
        root._ctl = ({})
        root._cacheTtlMs = 0
        root._contextTokens = 0
        if (proc.running) {
            root._stopping = true
            proc.running = false
        }
        proc.running = true
    }

    // -- Internals -----------------------------------------

    // Writes are queued until the process is actually up: writing to a QProcess
    // that has not started yet loses the data silently
    function _push(obj) {
        if (!proc.running) {
            root._queue = root._queue.concat([obj])
            proc.running = true
            return
        }
        proc.write(JSON.stringify(obj) + "\n")
    }

    function _flush() {
        const q = root._queue
        root._queue = []
        root._replay = q
        for (const m of q) proc.write(JSON.stringify(m) + "\n")
    }

    function _respondPermission(requestId, response) {
        proc.write(JSON.stringify({
            type: "control_response",
            response: { subtype: "success", request_id: requestId, response: response }
        }) + "\n")
    }

    Process {
        id: proc
        running: false
        stdinEnabled: true          // keeps stdin open: no EOF, no early exit
        // CLAUDE.md and the memory index live here, so this is where it thinks from
        workingDirectory: root.cwd

        command: [
            "claude", "-p",
            "--input-format", "stream-json",
            "--output-format", "stream-json",
            "--include-partial-messages",
            "--verbose",            // required by stream-json output
            "--strict-mcp-config",  // no MCP servers: ~4k tokens saved
            "--tools", root.tools,
            "--permission-mode", "manual",
            "--permission-prompts", "host",
            "--permission-prompt-tool", "stdio",    // undocumented in the option list,
                                                    // and required for can_use_tool
            // Without it the thinking deltas arrive empty. Not in --help either:
            // verified on CLI 2.1.288
            "--thinking-display", "summarized",
            "--add-dir", "/home/kalashnikxv/.config",
            "--add-dir", "/home/kalashnikxv/.local/bin",
            "--model", root.model
        ].concat(root.effort ? ["--effort", root.effort] : [])
        .concat(root._sessionId ? ["--resume", root._sessionId] : [])

        onStarted: {
            root._resuming = root._sessionId !== ""
            root._flush()
            root._requestInit()
        }

        // NDJSON: one event per line. Newlines inside model text arrive escaped
        // as \n inside JSON strings, so splitting on newline is always safe
        stdout: SplitParser {
            splitMarker: "\n"      // set it explicitly, don't rely on the default
            onRead: line => {
                if (!line) return
                let ev
                // A stray non-JSON line must never take the parser down
                try { ev = JSON.parse(line) } catch (e) { return }  // never throw in the parser

                if (ev.session_id && !root._sessionId) root._sessionId = ev.session_id

                switch (ev.type) {
                    case "stream_event": {
                        const e = ev.event
                        if (e?.type === "content_block_delta" && e.delta?.type === "text_delta")
                            root.deltaReceived(e.delta.text)
                        else if (e?.type === "content_block_delta" && e.delta?.type === "thinking_delta")
                            root.thinkingReceived(e.delta.thinking ?? "")
                        else if (e?.type === "content_block_start" && e.content_block?.type === "thinking")
                            root.thinkingStarted()
                        else if (e?.type === "content_block_stop")
                            root.blockFinished()
                        break
                    }

                    case "control_request": {
                        if (ev.request?.subtype !== "can_use_tool") break
                        const r = ev.request
                        // Session allowlist: approved once, never asked again
                        if (root._allowlist[r.tool_name]) {
                            root._respondPermission(ev.request_id,
                                { behavior: "allow", updateInput: r.input })
                            break
                        }
                        root._pending = {
                            request_id: ev.request_id,
                            tool_name: r.tool_name,
                            display_name: r.display_name ?? r.tool_name,
                            description: r.description ?? "",
                            input: r.input ?? {},
                            suggestions: r.permission_suggestions ?? []
                        }
                        break
                    }

                    case "assistant": {
                        // Full message, delivered after the deltas. Using its text
                        // as well as the deltas would print everything twice: read
                        // only the tool calls from here
                        for (const c of (ev?.message?.content ?? []))
                            if (c.type === "tool_use") root.toolStarted(c.name, c.input, c.id)
                        const u = ev?.message?.usage
                        if (u) root._contextTokens = (u.input_tokens ?? 0)
                            + (u.cache_read_input_tokens ?? 0) + (u.cache_creation_input_tokens ?? 0)
                        break
                    }

                    case "user":
                        // The summary travels as a synthetic prompt, plain string
                        // content, right after its boundary. Verified on CLI 2.1.288
                        if (typeof ev.message?.content === "string") {
                            if (root._awaitSummary && ev.isSynthetic) {
                                root._awaitSummary = false
                                root.compactSummary(ev.message.content)
                            }
                            break
                        }
                        for (const c of (ev.message?.content ?? []))
                            if (c.type === "tool_result")
                                root.toolResult(c.tool_use_id,
                                    typeof c.content === "string" ? c.content : "",
                                    c.is_error === true)
                        break

                    case "system": {
                        // `compacting` opens it; the next status, null with a
                        // compact_result, closes it, failed or not
                        if (ev.subtype === "status") {
                            const on = ev.status === "compacting"
                            if (on && !root._compacting) root._compactFrom = Date.now()
                            root._compacting = on
                            break
                        }
                        if (ev.subtype === "compact_boundary") {
                            root._awaitSummary = true
                            root.compacted(ev.compact_metadata ?? {})
                            break
                        }
                        if (ev.subtype !== "init") break
                        // The only thing this event adds: which commands the
                        // CLI considers terminal-bound. The names themselves
                        // already came from the initialize response
                        if (ev.terminal_slash_commands)
                            root._termCommands = ev.terminal_slash_commands
                        if (ev.permissionMode) root._permissionMode = ev.permissionMode
                        break
                    }

                    case "control_response": {
                        const r = ev.response
                        if (!r) break
                        if (r.request_id === root._initId) {
                            if (r.subtype !== "success") break
                            root._resuming = false
                            const info = r.response ?? {}
                            root._allCommands = info.commands ?? []
                            root._models = info.models ?? []
                            root._account = info.account ?? null
                            if (info.current_permission_mode)
                                root._permissionMode = info.current_permission_mode
                            if (root._wantMode !== "") {
                                const w = root._wantMode
                                root._wantMode = ""
                                root.setPermissionMode(w)
                            }
                            break
                        }
                        const t = root._ctl[r.request_id]
                        if (r.request_id === root._usageId) {
                            root._usageId = ""
                            if (r.subtype === "success") root._usage = r.response ?? null
                            else root._usageError = r.error ?? "get_usage refused"
                            break
                        }
                        if (!t) break
                        const m = root._ctl
                        delete m[r.request_id]
                        root._ctl = m
                        if (r.subtype === "success") break
                        // Refused: put back what the chip is already showing
                        if (t.what === "model") root.model = t.prev
                        else root._permissionMode = t.prev
                        root.sessionError(r.error ?? "control request refused")
                        break
                    }

                    case "result": {
                        // A resume of a transcript the CLI no longer has dies at
                        // once with this: onExited starts over, it is not a turn
                        if (root._resuming && ev.is_error && (ev.num_turns ?? 0) === 0) break
                        const u = ev.usage ?? {}
                        root._cacheTokens = (u.cache_read_input_tokens ?? 0)
                            + (u.cache_creation_input_tokens ?? 0)
                        // A turn that only READS the cache writes no entry, so
                        // the TTL of the last write is still the one in force
                        const c = u.cache_creation ?? {}
                        if ((c.ephemeral_1h_input_tokens ?? 0) > 0) root._cacheTtlMs = 3600000
                        else if ((c.ephemeral_5m_input_tokens ?? 0) > 0) root._cacheTtlMs = 300000
                        else if (root._cacheTtlMs <= 0) root._cacheTtlMs = 300000
                        root._busy = false
                        root.turnFinished(ev)
                        break
                    }
                }
            }
        }

        stderr: SplitParser { onRead: l => console.warn("[ai]", l) }

        onExited: (code, status) => {
            // An answer that was still due will never come
            root._usageId = ""
            if (root._stopping) {
                root._stopping = false
                return
            }
            if (root._resuming && code !== 0) {
                // The id points at a transcript the CLI has pruned: forget it
                // and replay this launch's writes on a fresh conversation
                root._resuming = false
                root._sessionId = ""
                root.cwd = root.defaultCwd
                root._queue = root._replay
                proc.running = true
                return
            }
            root._busy = false
            root._pending = null
            root._compacting = false
            if (code !== 0)
                root.sessionError("claude exited with code " + code)
        }
    }
}