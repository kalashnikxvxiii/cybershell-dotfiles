// AiState.qml - open/close state of the AI chat drawer, plus its open chats.
//
// A singleton and not a per-screen property because the conversations must
// survive moving the drawer from one monitor to the other: the processes and
// the histories belong to the shell, the window only shows them
pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    property bool open: false
    property string screenName: ""
    property string _lastToggle: ""

    // -- Geometry ----------------------------------------
    //
    // Docked, the drawer unrolls out of the dock's AI slot. Dragged by its
    // header it detaches and stays where it is dropped, on any screen, until
    // a double click on the header docks it again. The size holds either way
    property bool detached: false
    // Top-left of the detached drawer, in the panel area of `screenName`
    // (the screen minus the bar)
    property real floatX: 0
    property real floatY: 0
    property real panelW: 460
    // 0: the docked default, 78% of the screen's height
    property real panelH: 0

    function detachAt(screen, x, y) {
        root.screenName = screen
        root.floatX = x
        root.floatY = y
        root.detached = true
    }

    function dock() { root.detached = false }

    // -- Focus view ----------------------------------------
    //
    // The extension's mode of the same name: only the prompts and the answers
    // stay in the transcript, each run of reasoning and tool calls between
    // them folds into one line. A preference of the drawer, not of a chat
    property bool focusView: false

    function toggleFocusView() { root.focusView = !root.focusView }

    // -- Tabs ------------------------------------------
    //
    // One AiChat per open conversation, each with its own process. The drawer
    // shows `chat`; the others keep running behind it. `chat` is the object,
    // not an index: closing a tab then never leaves it pointing at nothing
    property var chats: []
    property AiChat chat: null

    // What a new tab starts with: the last model and effort picked. The mode
    // is not carried over, a new chat starts from the default one
    property string _newModel: "sonnet"
    property string _newEffort: "medium"

    Component {
        id: chatComp
        AiChat {}
    }

    function _make() {
        const c = chatComp.createObject(root, { effort: root._newEffort })
        c.session.model = root._newModel
        c.changed.connect(saveTimer.restart)
        return c
    }

    Component.onCompleted: {
        const c = root._make()
        root.chats = [c]
        root.chat = c
    }

    function select(c) {
        if (!c || root.chats.indexOf(c) < 0) return
        root.chat = c
        if (root.open) c.session.start()
    }

    function newChat() {
        const c = root._make()
        root.chats = root.chats.concat([c])
        root.select(c)
    }

    // The neighbour on the right takes the place of a closed front tab, as in
    // a browser. The last tab never closes into nothing: it becomes a new chat
    function closeChat(c) {
        const i = root.chats.indexOf(c)
        if (i < 0) return
        const rest = root.chats.filter(x => x !== c)
        if (rest.length === 0) rest.push(root._make())
        if (root.chat === c) root.select(rest[Math.min(i, rest.length - 1)])
        root.chats = rest
        c.session.stop()
        c.destroy()
    }

    // A session already open in a tab is brought forward, not opened twice.
    // An untouched front tab is reused instead of leaving an empty one behind
    function resume(id, title, dir) {
        const open = root.chats.find(c => c.session.sessionId === id)
        if (open) { root.select(open); return }
        let c = root.chat
        if (c.messages.length > 0 || c.live !== null || c.session.busy) {
            c = root._make()
            root.chats = root.chats.concat([c])
        }
        c.resume(id, title, dir)
        root.select(c)
    }

    // -- The front chat --------------------------------
    //
    // What the view binds to. Null-safe because these are evaluated once
    // before Component.onCompleted has made the first tab
    readonly property AiSession session: root.chat?.session ?? null
    readonly property var messages: root.chat?.messages ?? []
    readonly property var live: root.chat?.live ?? null
    readonly property string liveTail: root.chat?.liveTail ?? ""
    readonly property bool loading: root.chat?.loading ?? false
    readonly property bool thinking: root.chat?.thinking ?? false
    readonly property bool thinkingNow: root.chat?.thinkingNow ?? false
    readonly property string liveThought: root.chat?.liveThought ?? ""
    readonly property string effort: root.chat?.effort ?? root._newEffort
    readonly property var effortLevels: root.chat?.effortLevels ?? []
    readonly property var modelCatalog: root.session?.models ?? []
    readonly property var modelInfo: root.chat?.modelInfo
        ?? ({ displayName: "", supportedEffortLevels: [] })

    readonly property string turnLabel: {
        const c = root.chat
        if (!c) return ""
        if (c.session.busy) return (c.elapsedMs / 1000).toFixed(1) + "S"
        if (c.lastDurationMs <= 0) return ""
        return (c.lastDurationMs / 1000).toFixed(1) + "S"
            + (c.lastCostUsd > 0 ? " \u00b7 $" + c.lastCostUsd.toFixed(3) : "")
    }

    function ask(text, paths) { return root.chat.ask(text, paths) }

    // A selected block of the transcript holds the keyboard only for Ctrl+C:
    // anything else typed there belongs to the composer, key included
    signal focusComposer(string text)

    function clearHistory() { root.chat.clear() }

    // -- Execution mode ---------------------------------
    //
    // The four that make sense from a GUI. `dontAsk` and `bypassPermissions`
    // are deliberately absent: the permission card is the point of the panel
    readonly property var modes: ["manual", "acceptEdits", "plan", "auto"]

    readonly property var modeInfo: ({
        "manual": { label: "Manual", glyph: "\uf256", accent: "#00ffd2",
            desc: "Claude will ask for approval before each edit" },
        "acceptEdits": { label: "Edit automatically", glyph: "\uf121", accent: "#fcec0c",
            desc: "Claude will apply file edits without asking" },
        "plan": { label: "Plan", glyph: "\uf0f6", accent: "#ea00d9",
            desc: "Claude will explore the code and present a plan before editing" },
        "auto": { label: "Auto", glyph: "\uf0e7", accent: "#39ff14",
            desc: "Claude will approve actions that pass a safety check and pause for anything risky" },
        "default": { label: "Default", glyph: "\u25cb", accent: "#00ffd2",
            desc: "The mode the CLI was launched with" }
    })

    readonly property var mode: root.modeInfo[root.session?.permissionMode]
        ?? root.modeInfo["default"]

    function setMode(m) { root.session.setPermissionMode(m) }

    function cycleMode() {
        const i = root.modes.indexOf(root.session.permissionMode)
        root.setMode(root.modes[(i + 1) % root.modes.length])
    }

    // -- Model and effort -------------------------------
    //
    // Set on the front chat, and remembered as what the next new one gets
    function setModel(v) {
        if (!v || root.session.busy) return
        root.session.setModel(v)
        root._newModel = v
    }

    function cycleModel() {
        const c = root.modelCatalog
        if (c.length === 0 || root.session.busy) return
        let i = 0
        for (let k = 0; k < c.length; k++)
            if (c[k].value === root.session.model) { i = k; break }
        root.setModel(c[(i + 1) % c.length].value)
    }

    function setEffort(level) {
        if (root.chat.setEffort(level)) root._newEffort = level
    }

    // -- Prompt cache window ----------------------------------
    //
    // The entry lives for its TTL from the last time it was touched, and a read
    // refreshes it: the countdown therefore restarts at every turn
    property real _now: 0

    readonly property real cacheLeftMs: {
        const c = root.chat
        if (!c || c.session.cacheTtlMs <= 0) return 0
        return Math.max(0, c.cacheStamp + c.session.cacheTtlMs - root._now)
    }

    readonly property string cacheLabel: {
        if (root.cacheLeftMs <= 0) return ""
        const s = Math.floor(root.cacheLeftMs / 1000)
        const mm = Math.floor(s / 60)
        const ss = s % 60
        const k = root.session.cacheTokens
        const tok = k >= 1000 ? (k / 1000).toFixed(1) + "K" : String(k)
        return tok + " \u00b7 " + mm + ":" + (ss < 10 ? "0" : "") + ss
    }

    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.open && root.cacheLeftMs > 0
        onTriggered: root._now = Date.now()
    }

    function openOn(screen) {
        root.screenName = screen ? screen : (Hyprland.focusedMonitor?.name ?? "DP-1")
        root.open = true
        root.chat.session.start()       // pre-warm: the first message pays no startup
    }

    function close() { root.open = false }

    // Same screen closes, another screen moves the drawer there
    function toggleFrom(screen) {
        // Detached, it has a place its own: any dock toggles it there. A
        // screen that is gone since sends it back to the dock it came from
        if (root.detached && !Quickshell.screens.some(q => q.name === root.screenName))
            root.dock()
        if (root.detached) {
            if (root.open) root.close()
            else root.openOn(root.screenName)
            return
        }
        if (root.open && root.screenName === screen) root.close()
        else root.openOn(screen)
    }

    // -- Persistence ------------------------------------
    //
    // The tabs outlive a shell reload: each transcript is redrawn from here,
    // and each CLI gets its own context back via --resume when it is first
    // brought to the front
    property bool _restored: false

    readonly property FileView _store: FileView {
        path: Quickshell.env("HOME") + "/.cache/qs-ai/state.json"
        printErrors: false          // first run: no file yet, nothing to report
        onLoaded: {
            if (root._restored) return
            try {
                const d = JSON.parse(text())
                if (typeof d.effort === "string" && d.effort) root._newEffort = d.effort
                if (typeof d.model === "string" && d.model) root._newModel = d.model
                if (typeof d.focusView === "boolean") root.focusView = d.focusView
                const g = d.window ?? {}
                if (typeof g.w === "number") root.panelW = g.w
                if (typeof g.h === "number") root.panelH = g.h
                if (g.detached === true && typeof g.screen === "string" && g.screen !== "")
                    root.detachAt(g.screen, g.x ?? 0, g.y ?? 0)
                // Before tabs, the file held one conversation at the top level
                const tabs = Array.isArray(d.tabs) ? d.tabs : [d]
                const made = tabs.map(t => {
                    const c = root._make()
                    if (typeof t.effort === "string" && t.effort) c.effort = t.effort
                    if (typeof t.model === "string" && t.model) c.session.model = t.model
                    if (typeof t.title === "string") c.customTitle = t.title
                    if (Array.isArray(t.messages)) c.messages = t.messages
                    if (typeof t.sessionId === "string" && t.sessionId !== "") {
                        c.session.restore(t.sessionId, t.cwd)
                        // The mode belongs to the conversation: only a resumed
                        // one gets it back, a fresh chat starts from the default
                        if (typeof t.mode === "string") c.session.restoreMode(t.mode)
                    }
                    return c
                })
                const old = root.chats
                root.chats = made
                root.select(made[Math.max(0, Math.min(d.current ?? 0, made.length - 1))])
                for (const c of old) { c.session.stop(); c.destroy() }
            } catch (e) {}
            root._restored = true
        }
        onLoadFailed: root._restored = true
    }

    // Nothing is written before the load lands, or the empty startup state
    // would overwrite the saved one
    function _save() {
        if (!root._restored) return
        root._store.setText(JSON.stringify({
            model: root._newModel,
            effort: root._newEffort,
            focusView: root.focusView,
            window: { detached: root.detached, screen: root.screenName,
                x: root.floatX, y: root.floatY, w: root.panelW, h: root.panelH },
            current: root.chats.indexOf(root.chat),
            tabs: root.chats.map(c => ({
                title: c.customTitle,
                model: c.session.model,
                effort: c.effort,
                mode: c.session.durableMode,
                // The CLI writes a session to disk only after its first turn:
                // the id of one that never had a turn cannot be resumed
                sessionId: c.messages.some(m => m.role === "user") ? c.session.sessionId : "",
                cwd: c.session.cwd,
                messages: c.messages
            }))
        }))
    }

    Timer { id: saveTimer; interval: 400; onTriggered: root._save() }
    onChatsChanged: saveTimer.restart()
    onChatChanged: saveTimer.restart()
    on_NewModelChanged: saveTimer.restart()
    on_NewEffortChanged: saveTimer.restart()
    onFocusViewChanged: saveTimer.restart()
    // Restarted on every step of a drag: it writes once, after the drop
    onDetachedChanged: saveTimer.restart()
    onScreenNameChanged: saveTimer.restart()
    onFloatXChanged: saveTimer.restart()
    onFloatYChanged: saveTimer.restart()
    onPanelWChanged: saveTimer.restart()
    onPanelHChanged: saveTimer.restart()

    // "<screen>|<nanoseconds>", written by scripts/ai-toggle.sh. A toggle left
    // by the previous shell is ignored: replayed at startup it would open the
    // drawer on its own (same guard as SnipState)
    readonly property real _startupMs: Date.now()
    readonly property FileView _toggleReader: FileView {
        path: "/tmp/qs-ai-toggle"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            var content = text().trim()
            if (content === "" || content === root._lastToggle) return
            root._lastToggle = content
            var parts = content.split("|")
            var stampMs = parseFloat(parts[parts.length - 1]) / 1e6
            if (!isFinite(stampMs) || stampMs < root._startupMs) return
            root.toggleFrom(parts[0] || "")
        }
    }
}
