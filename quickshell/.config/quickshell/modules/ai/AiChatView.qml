// AiChatView.qml - header, transcript, permission gate, composer.
//
// The composer carries the chrome: the action rail, the execution mode and the
// model live in a toolbar inside the input frame, not in a header bar. That is
// what lets the transcript keep the full width of a 460px drawer.
import QtQuick
import Quickshell
import Quickshell.Io
import "../../common"
import "../../common/Colors.js" as CP

Item {
    id: root

    // The in-flight reply is rendered as one more row at the tail.
    readonly property var rows: AiState.live !== null
        ? AiState.messages.concat([AiState.live])
        : AiState.messages

    readonly property color fg: "#d8e0e8"
    readonly property string scripts:
        (Quickshell.env("HOME") || "") + "/.config/quickshell/scripts/"

    property bool recording: false
    property bool transcribing: false
    property bool cmdOpen: false
    property bool modeOpen: false
    property bool modelOpen: false
    property bool resumeOpen: false
    property bool accountOpen: false
    property bool detailsOpen: false
    // Paths staged for the next message, shown in the attach menu
    property var attachments: []
    property var _toMark: []

    function attach(paths) {
        const cur = root.attachments
        const add = paths.filter(p => p !== "" && cur.indexOf(p) < 0)
        if (add.length > 0) root.attachments = cur.concat(add)
    }

    function detach(p) { root.attachments = root.attachments.filter(x => x !== p) }

    // Every path goes through the shell first: only the filesystem knows a
    // folder from a file, and the model reads a trailing slash the same way
    function attachPaths(paths) {
        root._toMark = root._toMark.concat(paths)
        if (!marker.running) root._runMaker()
    }

    function _runMaker() {
        if (root._toMark.length === 0) return
        marker.command = ["sh", "-c",
            'for p in "$@"; do if [ -d "$p" ]; then printf "%s/\\n" "${p%/}"; '
            + 'else printf "%s\\n" "$p"; fi; done', "sh"].concat(root._toMark)
        root._toMark = []
        marker.running = true
    }

    function send() {
        // The commands the CLI cannot run headless, or that act on the
        // drawer rather than on the conversation: the shell does them
        const cmd = input.text.trim()
        if (cmd === "/resume") { root.openResume(); return }
        if (cmd === "/clear" || cmd === "/focus") {
            if (cmd === "/clear") AiState.clearHistory()
            else AiState.toggleFocusView()
            input.text = ""
            root.cmdOpen = false
            return
        }
        if (!AiState.ask(input.text, root.attachments)) return
        input.text = ""
        root.attachments = []
        root.cmdOpen = false
        root._histIdx = -1
        root._draft = ""
    }

    function focusInput() { input.forceActiveFocus() }

    // -- Prompt history ---------------------------------
    //
    // Up on the first line of the box brings back the previous message, Down
    // on the last line walks forward again, down to what was being typed: a
    // terminal's history, over this conversation's prompts
    property int _histIdx: -1           // -1: not browsing; 0: the latest prompt
    property string _draft: ""
    property bool _histSetting: false

    readonly property var _history: AiState.messages
        .filter(m => m.role === "user")
        .map(m => m.parts[0]?.text ?? "")

    function historyStep(dir) {
        const h = root._history
        const next = root._histIdx + dir
        if (next < -1 || next >= h.length) return false
        if (root._histIdx === -1) root._draft = input.text
        root._histIdx = next
        root._histSetting = true
        input.text = next === -1 ? root._draft : h[h.length - 1 - next]
        root._histSetting = false
        input.cursorPosition = input.length
        return true
    }

    Connections {
        target: AiState
        function onChatChanged() { root._histIdx = -1; root._draft = "" }
        function onFocusComposer(text) {
            input.forceActiveFocus()
            if (text !== "") input.insert(input.cursorPosition, text)
        }
    }

    function insertAtCursor(s) {
        input.insert(input.cursorPosition, s)
        input.forceActiveFocus()
    }

    // Two ways in, one menu: the button hands the menu its own filter field and
    // the focus, typing "/" leaves both with the composer
    readonly property bool cmdTyped:
        input.text.startsWith("/") && input.text.indexOf(" ") < 0
    readonly property string cmdFilter: root.cmdTyped ? input.text.slice(1) : ""
    readonly property bool cmdActive: root.cmdOpen && (cmdMenu.ownFilter || root.cmdTyped)

    onCmdTypedChanged: {
        if (root.cmdTyped) { cmdMenu.ownFilter = false; root.cmdOpen = true }
        else if (!cmdMenu.ownFilter) root.cmdOpen = false
    }

    function closeCommands() {
        root.cmdOpen = false
        cmdMenu.ownFilter = false
        input.forceActiveFocus()
    }

    function openResume() {
        input.text = ""
        root.cmdOpen = false
        cmdMenu.ownFilter = false
        root.modeOpen = false
        root.modelOpen = false
        root.resumeOpen = true
        resumeMenu.openMenu() 
    }

    function closeResume() {
        root.resumeOpen = false
        input.forceActiveFocus()
    }

    // Escape peels one layer at a time, innermost surface first. False when
    // nothing was open: then the drawer is the one the close. Called by the
    // composer and by the panel, which gets the key when the composer has no
    // focus (just opened, or disabled while a reply streams)
    function dismissTop() {
        if (root.detailsOpen) root.detailsOpen = false
        else if (root.accountOpen) root.accountOpen = false
        else if (root.resumeOpen) root.closeResume()
        else if (root.modelOpen) root.modelOpen = false
        else if (root.modeOpen) root.modeOpen = false
        else if (root.cmdOpen) root.closeCommands()
        else return false
        return true
    }

    // -- Attach: a path, not an upload ------------------------------------
    //
    // The model runs on this machine, so attaching a file means telling it
    // where the file IS. zenity gives the native picker, the path goes into the
    // prompt, and Read does the rest
    Process {
        id: filePicker
        running: false
        // The separator is a real newline: paths may contain anything but that
        command: ["zenity", "--file-selection", "--multiple",
            "--separator=\n", "--title=Attach paths"]
        stdout: StdioCollector {
            onStreamFinished: root.attachPaths(text.split("\n").filter(l => l.trim() !== ""))
        }
    }

    Process {
        id: marker
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.attach(text.split("\n").filter(l => l !== ""))
        }
        // Drops that arrived while this batch ran go next
        onExited: root._runMaker()
    }

    // -- Dictation -------------------------------------------------
    //
    // One process for the whole take: it records until the stop signal, then
    // transcribes, and the words arrive as its own output
    Process {
        id: voice
        running: false
        command: [root.scripts + "ai-voice.sh", "record"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim()
                if (t !== "") root.insertAtCursor(t + " ")
            }
        }
        stderr: SplitParser { onRead: l => console.warn("[ai-voice]", l) }
        onExited: {
            root.recording = false
            root.transcribing = false
        }
    }

    function toggleVoice() {
        if (root.recording) {
            root.recording = false
            root.transcribing = true
            Quickshell.execDetached([root.scripts + "ai-voice.sh", "stop"])
        } else {
            root.recording = true
            voice.running = true
        }
    }

    // ── Header ────────────────────────────────────────────────────────────
    Item {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 26

        Rectangle {
            id: accentBar
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            anchors.leftMargin: 12
            width: 4
            color: CP.magenta
        }

        Text {
            id: title
            anchors.left: accentBar.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "NETRUNNER"
            font.family: "Oxanium"
            font.pixelSize: 14
            font.letterSpacing: 4
            font.bold: true
            color: CP.magenta
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // How long the turn took and what it cost, by the account button
            AiChip {
                anchors.verticalCenter: parent.verticalCenter
                visible: AiState.turnLabel !== ""
                label: AiState.turnLabel
                accent: CP.cyan
                interactive: false
                frame: false
            }

            // The account and the plan limits: the menu asks the CLI afresh
            // every time it opens
            AiIconButton {
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 22
                glyph: "\uf2bd"
                glyphSize: 14
                accent: CP.magenta
                frame: root.accountOpen
                onTriggered: {
                    root.accountOpen = !root.accountOpen
                    if (root.accountOpen) {
                        root.detailsOpen = false
                        AiState.session.requestUsage()
                    }
                }
            }
        }

        // Beside the name, on its baseline: the state of the link it names
        Text {
            anchors.left: title.right
            anchors.leftMargin: 10
            anchors.baseline: title.baseline
            text: AiState.thinking ? "\u00b7 LINKING\u2026"
                : AiState.session.busy ? "\u00b7 STREAMING"
                : AiState.session.alive ? "\u00b7 READY"
                : "\u00b7 COLD"
            font.family: "Oxanium"
            font.pixelSize: 12
            font.letterSpacing: 2
            opacity: statePulse.k
            color: CP.alpha(AiState.session.busy ? CP.yellow : CP.magenta, 0.65)
        }

        QtObject { id: statePulse; property real k: 1 }

        // Pending states pulse, idle ones hold still
        SequentialAnimation {
            running: AiState.session.busy
            loops: Animation.Infinite
            onStopped: statePulse.k = 1
            NumberAnimation { target: statePulse; property: "k"; from: 1.0; to: 0.55; duration: 900 }
            NumberAnimation { target: statePulse; property: "k"; from: 0.55; to: 1.0; duration: 900 }
        }
    }

    Rectangle {
        id: headerSep
        anchors { top: header.bottom; left: parent.left; right: parent.right }
        anchors.topMargin: 6
        height: 1
        color: CP.alpha(CP.magenta, 0.22)
    }

    // -- Tabs ------------------------------
    AiTabBar {
        id: tabBar
        anchors { top: headerSep.bottom; left: parent.left; right: parent.right }
        anchors.topMargin: 8
    }

    // -- Transcript ------------------------------------
    ListView {
        id: list
        anchors { top: tabBar.bottom; left: parent.left; right: parent.right; bottom: turnStatus.top }
        anchors.topMargin: 14
        anchors.bottomMargin: 10
        clip: true
        spacing: 18
        model: root.rows
        // The wheel scrolls, a drag selects text: with the left button free
        // to flick, every drag across a paragraph would move the list instead
        acceptedButtons: Qt.NoButton

        // Every row stays built. With rows created and destroyed as they
        // scroll, the list only estimates the height of the ones it has not
        // built: jumping to the end on each change of that estimate build and
        // drops a long answer forever, and the shell freezes
        cacheBuffer: 1000000

        // Follow the tail while the answer types itself, unless the user has
        // scrolled up to read something: then hold position until they come back.
        // Once per frame at most: a burst of height changes is one jump
        property bool pinned: true
        onMovementEnded: pinned = atYEnd
        onCountChanged: if (pinned) Qt.callLater(positionViewAtEnd)
        onContentHeightChanged: if (pinned) Qt.callLater(positionViewAtEnd)

        // Another tab is another transcript: it opens at its end
        Connections {
            target: AiState
            function onChatChanged() {
                list.pinned = true
                Qt.callLater(list.positionViewAtEnd)
            }
        }

        delegate: AiMessage {
            required property var modelData
            required property int index

            width: list.width
            role: modelData.role
            parts: modelData.parts
            rowIndex: index
            live: AiState.live !== null && index === list.count - 1
            thinkingLive: live && AiState.thinkingNow
            // Only the last row can be streaming.
            tailText: (AiState.live !== null && index === list.count - 1)
                    ? AiState.liveTail : ""
        }

        // Under the last turn once the prompt cache has run out
        footer: Item {
            width: list.width
            height: idleNote.shown ? idleNote.height + list.spacing : 0

            AiIdleNote {
                id: idleNote
                y: list.spacing
                x: 14
                width: parent.width - 14
                chat: AiState.chat
            }
        }
    }

    // An empty conversation is a new one: the mascot says so. A sibling of
    // the list, not a child: a ListView reparents children into its content
    // item, which is zero tall while the list is empty
    AiWelcome {
        anchors.centerIn: list
        width: list.width - 40
        visible: list.count === 0 && !AiState.loading
    }

    // The question being answered stays in sight while its answer scrolls
    AiStickyQuestion {
        anchors { top: list.top; left: list.left; right: list.right }
        view: list
        rows: root.rows
    }

    // What the turn is doing, between the transcript and the composer
    AiTurnStatus {
        id: turnStatus
        anchors { left: parent.left; right: parent.right; bottom: gate.top }
        anchors.bottomMargin: visible ? 8 : 0
        chat: AiState.chat
    }

    // ── Command palette ───────────────────────────────────────────────────
    AiCommandMenu {
        id: cmdMenu
        anchors { left: parent.left; right: parent.right; bottom: gate.top }
        anchors.bottomMargin: root.cmdActive ? 8 : 0
        visible: root.cmdActive
        // /resume and /focus are not in what the CLI declares: they are the
        // shell's own. /focus is a switch, and flips without closing the menu
        source: [{ name: "resume", description: "Resume a previous conversation in a tab" },
            { name: "focus", description: "Focus view: show only your prompts and Claude's responses",
            toggle: AiState.focusView }]
            .concat(AiState.session.slashCommands)
        filter: root.cmdFilter
        onDismissed: root.closeCommands()
        onAccepted: name => {
            if (name === "resume") { root.openResume(); return }
            if (name === "focus") { AiState.toggleFocusView(); return }
            input.text = "/" + name + " "
            input.cursorPosition = input.text.length
            root.closeCommands()
        }
    }

    AiResumeMenu {
        id: resumeMenu
        anchors { left: parent.left; right: parent.right; bottom: gate.top }
        anchors.bottomMargin: 8
        visible: root.resumeOpen
        onDismissed: root.closeResume()
        onPicked: (id, title, cwd) => {
            AiState.resume(id, title, cwd)
            root.closeResume()
        }
    }

    AiAttachMenu {
        id: attachMenu
        anchors { left: parent.left; right: parent.right; bottom: promptBox.top }
        anchors.bottomMargin: paths.length > 0 ? 8 : 0
        paths: root.attachments
        onRemoved: p => root.detach(p)
        onCleared: root.attachments = []
    }

    AiModeMenu {
        id: modeMenu
        anchors.right: parent.right
        anchors.bottom: attachMenu.top
        anchors.bottomMargin: 8
        visible: root.modeOpen
        enabled: !AiState.session.busy
        modes: AiState.modes
        info: AiState.modeInfo
        currentMode: AiState.session.permissionMode
        effortLevels: AiState.effortLevels
        currentEffort: AiState.effort
        onModePicked: m => { AiState.setMode(m); root.modeOpen = false; input.forceActiveFocus() }
        onEffortPicked: l => AiState.setEffort(l)
        onDismissed: { root.modeOpen = false; input.forceActiveFocus() }
    }

    AiModelMenu {
        id: modelMenu
        anchors.left: parent.left
        anchors.bottom: attachMenu.top
        anchors.bottomMargin: 8
        visible: root.modelOpen
        enabled: !AiState.session.busy
        catalog: AiState.modelCatalog
        currentModel: AiState.session.model
        effortLevels: AiState.effortLevels
        currentEffort: AiState.effort
        onModelPicked: v => { AiState.setModel(v); root.modelOpen = false; input.forceActiveFocus() }
        onEffortPicked: l => AiState.setEffort(l)
        onDismissed: { root.modelOpen = false; input.forceActiveFocus() }
    }

    // ── Permission gate ───────────────────────────────────────────────────
    AiPermissionCard {
        id: gate
        anchors { left: parent.left; right: parent.right; bottom: attachMenu.top }
        anchors.bottomMargin: request !== null ? 10 : 0
        request: AiState.session.pendingPermission
        onAllow: always => AiState.session.approve(always)
        onRefuse: AiState.session.deny("")
    }

    // ── Composer ──────────────────────────────────────────────────────────
    Item {
        id: promptBox
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: inputWrap.height + toolbar.height + 20

        CutShape {
            anchors.fill: parent
            fillColor: CP.alpha(CP.void2, 0.75)
            strokeColor: input.activeFocus ? CP.alpha(CP.magenta, 0.75)
                        : CP.alpha(CP.magenta, 0.30)
            strokeWidth: input.activeFocus ? 1.5 : 1
            inset: 0.5
            cutTopRight: 15
            cutBottomLeft: 15
            Behavior on strokeColor { ColorAnimation { duration: 120 } }
        }

        Item {
            id: inputWrap
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors.margins: 9
            height: Math.min(110, Math.max(18, input.implicitHeight))
            clip: true

            // Past the cap the box stops growing and scrolls instead, following
            // the caret so the line being typed is always the one in view
            Flickable {
                id: inputFlick
                anchors.fill: parent
                contentWidth: width
                contentHeight: input.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                function follow(r) {
                    if (contentY >= r.y) contentY = r.y
                    else if (contentY + height <= r.y + r.height)
                        contentY = r.y + r.height - height
                }

                // A qrap to a new line moves the caret before the content has
                // grown: follow again once the height catches up, or the jump
                // would be clamped against the old button
                onContentHeightChanged: follow(input.cursorRectangle)

                TextEdit {
                    id: input
                    width: inputFlick.width
                    // Never shorter than the box: a click still focuses it
                    height: Math.max(implicitHeight, inputFlick.height)
                    onCursorRectangleChanged: inputFlick.follow(cursorRectangle)
                    wrapMode: Text.Wrap
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: root.fg
                    selectionColor: CP.alpha(CP.magenta, 0.4)
                    selectByMouse: true
                    // The mic floats over the bottom-right corner: keep the text
                    // out from under it instead of letting the two overlap
                    rightPadding: 20
                    enabled: !AiState.session.busy
                    // Typing over a recalled prompt makes it a new draft
                    onTextChanged: if (!root._histSetting) root._histIdx = -1

                    Text {
                        anchors.fill: parent
                        anchors.rightMargin: 20
                        visible: input.text === ""
                        text: root.recording ? "Listening\u2026"
                            : root.transcribing ? "Transcribing\u2026"
                            : "Plan, search, build anything\u2026"
                        font.family: "Oxanium"
                        font.pixelSize: 11
                        color: CP.alpha(root.recording ? CP.red : CP.magenta, 0.32)
                    }

                    // Enter sends, Shift+Enter breaks the line: the shell convention
                    // for a prompt box, not a text editor. While the palette is up
                    // the arrows and Enter belong to it instead
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            // Innermost surface first: Escape peels one layer at a
                            // time and only closes the drawer once nothing is open
                            if (!root.dismissTop()) AiState.close()
                            event.accepted = true
                        } else if (event.key === Qt.Key_F
                            && (event.modifiers & Qt.ControlModifier)
                            && (event.modifiers & Qt.AltModifier)) {
                            // The extension's binding for the same switch
                            AiState.toggleFocusView()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Backtab
                            || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                            AiState.cycleMode()
                            event.accepted = true
                        } else if (root.cmdActive && cmdMenu.visible
                            && (event.key === Qt.Key_Down || event.key === Qt.Key_Up)) {
                            cmdMenu.move(event.key === Qt.Key_Down ? 1 : -1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up && !root.cmdActive
                            && !(event.modifiers & (Qt.ShiftModifier | Qt.ControlModifier))
                            && input.cursorRectangle.y <= input.positionToRectangle(0).y) {
                            // On the first line only: on any other, Up moves the caret
                            event.accepted = root.historyStep(1)
                        } else if (event.key === Qt.Key_Down && !root.cmdActive && root._histIdx >= 0
                            && !(event.modifiers & (Qt.ShiftModifier | Qt.ControlModifier))
                            && input.cursorRectangle.y >= input.positionToRectangle(input.length).y) {
                            event.accepted = root.historyStep(-1)
                        } else if (root.cmdActive && cmdMenu.visible
                            && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                                || event.key === Qt.Key_Tab)) {
                            cmdMenu.accept()
                            event.accepted = true
                        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                            && !(event.modifiers & Qt.ShiftModifier)) {
                            root.send()
                            event.accepted = true
                        }
                    }
                }
            }

            // Dictation, where the Cursor composer puts it: bottom-right of the
            // field itself, glyph only. It latches red while recording and
            // pulses on its own - no frame needed to say it is a control
            AiIconButton {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -2
                anchors.bottomMargin: -2
                frame: false
                glyphSize: 13
                glyph: "\uf130"
                accent: CP.magenta
                on: root.recording
                busy: root.transcribing
                enabled: !AiState.session.busy && !root.transcribing
                onTriggered: root.toggleVoice()
            }
        }

        Item {
            id: toolbar
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            anchors.leftMargin: 9
            anchors.rightMargin: 9
            anchors.bottomMargin: 8
            height: 18

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                AiIconButton {
                    glyph: "\uf067"
                    accent: CP.cyan
                    frame: false
                    glyphSize: 12
                    enabled: !AiState.session.busy
                    onTriggered: filePicker.running = true
                }

                AiIconButton {
                    glyph: "/"
                    accent: CP.cyan
                    frame: false
                    glyphSize: 12
                    enabled: !AiState.session.busy
                    onTriggered: {
                        if (root.cmdOpen && cmdMenu.ownFilter) root.closeCommands()
                        else { root.cmdOpen = true; cmdMenu.openStandalone() }
                    }
                }

                AiChip {
                    glyph: "\u25c6"
                    label: AiState.modelInfo.displayName
                    accent: CP.magenta
                    enabled: !AiState.session.busy
                    onTriggered: {
                        root.modelOpen = !root.modelOpen
                        if (root.modelOpen) { root.cmdOpen = false; root.modeOpen = false }
                    }
                }

                // How long the prompt cache still holds, and how much is in it.
                // Real numbers: the TTL comes from the usage block of the last turn
                AiChip {
                    visible: AiState.cacheLabel !== ""
                    glyph: "\u25a0"
                    label: AiState.cacheLabel
                    accent: CP.neon
                    interactive: false
                    frame: false
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                AiChip {
                    glyph: AiState.mode.glyph
                    label: AiState.mode.label.toUpperCase()
                    accent: AiState.mode.accent
                    frame: false
                    onTriggered: {
                        root.modeOpen = !root.modeOpen
                        if (root.modeOpen) { root.cmdOpen = false; root.modelOpen = false }
                    }
                }

                // One button, two jobs: it sends, and while a turn runs it
                // stops it. Glyph only, an arrow up or a square
                AiChip {
                    readonly property bool stops: AiState.session.busy
                    glyph: stops ? "\uf04d" : "\uf062"
                    glyphSize: 10
                    accent: stops ? CP.red : CP.magenta
                    filled: true
                    enabled: stops || input.text.trim() !== "" || root.attachments.length > 0
                    onTriggered: stops ? AiState.session.interrupt() : root.send()
                }
            }
        }
    }

    // -- Account ---------------------------------------
    //
    // Over everything below the header, so both come after the composer
    AiAccountMenu {
        anchors { top: headerSep.bottom; right: parent.right }
        anchors.topMargin: 4
        visible: root.accountOpen
        onDetailsRequested: {
            root.accountOpen = false
            root.detailsOpen = true
            AiState.session.requestUsage()
        }
    }

    AiAccountDialog {
        anchors { top: headerSep.bottom; left: parent.left
            right: parent.right; bottom: parent.bottom }
        visible: root.detailsOpen
        onClosed: root.detailsOpen = false
    }

    // -- Drop Zone ----------------------------------
    //
    // Last child on purpose: drags go the topmost item that takes them, and
    // the TextEdit takes drops too - it would paste the raw file:// URL
    DropArea {
        id: dropZone
        anchors.fill: parent
        anchors.topMargin: 45
        anchors.bottomMargin: 70
        onEntered: drag => drag.accepted = drag.hasUrls
        onDropped: drop => {
            const out = []
            for (let i = 0; i < drop.urls.length; i++) {
                const s = String(drop.urls[i])
                if (s.startsWith("file://")) out.push(decodeURIComponent(s.slice(7)))
            }
            if (out.length === 0) return
            root.attachPaths(out)
            drop.acceptProposedAction()
        }

        CutShape {
            anchors.fill: parent
            visible: dropZone.containsDrag
            fillColor: CP.alpha(CP.magenta, 0.08)
            strokeColor: CP.alpha(CP.magenta, 0.70)
            strokeWidth: 1.5
            inset: 0.5
            cutTopLeft: 15
            cutBottomRight: 15

            Text {
                anchors.centerIn: parent
                text: "DROP TO ATTACH"
                font.family: "Oxanium"
                font.pixelSize: 12
                font.letterSpacing: 3
                font.bold: true
                color: CP.magenta
            }
        }
    }
}
