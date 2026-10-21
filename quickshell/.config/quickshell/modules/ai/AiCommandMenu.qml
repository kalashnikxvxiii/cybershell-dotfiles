// AiCommandMenu.qml - the action palette.
//
// Shaped after the Cursor action menu: a filter field on top, entries grouped
// under section headers, one continuous scroll. The entries are whatever the
// live session declared in its `init` event minus the terminal-only ones, so a
// new plugin or skill appears here on the next session without touching a list.
import QtQuick
import "../../common"
import "../../common/Colors.js" as CP

Item {
    id: root

    property var source: []
    property string filter: ""      // driven by the composer when "/" was typed
    property bool ownFilter: false  // true when opened from the button
    property int current: -1

    signal accepted(string name)
    signal dismissed()

    readonly property color fg: "#d8e0e8"
    readonly property string activeFilter:
        root.ownFilter ? filterField.text : root.filter

    // Sections, in the order they are shown. `keys` is matched exactly; `ns`
    // catches a whole namespace ("plugin:command"); the leftovers fall through
    // to the last section, so a command is never silently lost
    readonly property var groups: [
        { title: "CONTEXT", accent: CP.cyan, ns: "",
        keys: ["resume", "clear", "compact", "autocompact", "context", "recap",
            "rename", "import", "init", "goal"] },
        { title: "MODEL", accent: CP.magenta, ns: "",
        keys: ["model", "effort", "fast", "output-style", "loop", "schedule"] },
        { title: "REVIEW", accent: CP.yellow, ns: "",
        keys: ["code-review", "security-review", "ultrareview", "verify",
            "simplify", "debug", "skill-doctor", "batch"] },
        { title: "SKILLS", accent: CP.neon, ns: "*",
        keys: ["run", "run-skill-generator", "reload-skills", "advisor"] },
        { title: "CUSTOMIZE", accent: CP.cyan, ns: "",
        keys: ["focus", "ctrl-enter", "config", "update-config", "mcp", "agents", "list-agents",
            "workflow-launch-exec", "auto-mode-setup",
            "fewer-permission-prompts", "reload-plugins", "team-onboarding"] },
        { title: "USAGE", accent: CP.yellow, ns: "",
        keys: ["usage", "usage-credits", "extra-usage", "insights"] },
        { title: "OTHER", accent: CP.cyan, ns: "", keys: [] }
    ]

    // Flat list of rows: headers travel in the same model as the entries, which
    // is what lets one ListView scroll through both. Keyboard nav skips headers
    readonly property var rows: {
        const f = root.activeFilter.toLowerCase()
        // Match the description too: "cache" should find /compact even though
        // the word is not in its name
        const all = (root.source ?? []).filter(c => f === ""
            || c.name.toLowerCase().indexOf(f) >= 0
            || (c.description ?? "").toLowerCase().indexOf(f) >= 0)

        const taken = {}
        const out = []
        for (let g = 0; g < root.groups.length; g++) {
            const grp = root.groups[g]
            const last = g === root.groups.length - 1
            const mine = []
            for (const c of all) {
                if (taken[c.name]) continue
                const hit = last
                    || grp.keys.indexOf(c.name) >= 0
                    || (grp.ns === "*" && c.name.indexOf(":") >= 0)
                if (hit) { mine.push(c); taken[c.name] = true }
            }
            if (mine.length === 0) continue
            out.push({ header: true, name: grp.title, accent: grp.accent,
                desc: "", hint: "" })
            for (const c of mine)
                out.push({ header: false, name: c.name, accent: grp.accent,
                    desc: c.description ?? "", hint: c.argumentHint ?? "",
                    // A setting of the drawer: 1 on, 0 off, -1 not a switch
                    toggle: c.toggle === undefined ? -1 : (c.toggle ? 1 : 0) })
        }
        return out
    }

    property real _keepY: -1

    function _pick(name) {
        root._keepY = view.contentY
        root.accepted(name)
    }

    // The highlight follows its entry across a rebuild: flipping a setting
    // rebuilds the list, and the row just used must stay the one lit. A new
    // filter still starts from the top
    property string _currentName: ""
    property string _rowsFilter: ""
    onCurrentChanged: if (root.current >= 0 && root.current < root.rows.length)
        root._currentName = root.rows[root.current].name
    onRowsChanged: {
        const same = root.activeFilter === root._rowsFilter
        root._rowsFilter = root.activeFilter
        const i = same ? root.rows.findIndex(r => !r.header && r.name === root._currentName) : -1
        root.current = i >= 0 ? i : root._firstEntry()
        if (same && root._keepY >= 0) {
            const y = root._keepY
            root._keepY = -1
            Qt.callLater(() => { view.contentY = y })
        }
    }

    readonly property int rowH: 22
    readonly property int headerH: 20

    // Measured from the model, never from view.contentHeight: the ListView is
    // anchored to this item's bottom, so reading its contentHeight here makes
    // the height depend on the delegates and the delegates depend on the
    // height. It settles at zero and the menu never opens
    readonly property int contentH: {
        let h = 8
        for (const r of root.rows) h += r.header ? root.headerH : root.rowH
        return h
    }

    readonly property int footerH: 18

    implicitHeight: filterRow.height + 1
        + Math.min(212, root.contentH) + root.footerH
    height: implicitHeight
    visible: root.rows.length > 0 || root.ownFilter

    function _firstEntry() {
        for (let i = 0; i < root.rows.length; i++)
            if (!root.rows[i].header) return i
        return -1
    }

    function move(delta) {
        const n = root.rows.length
        if (n === 0) return
        let i = root.current < 0 ? (delta > 0 ? -1 : n) : root.current
        for (let step = 0; step < n; step++) {
            i = ((i + delta) % n + n) % n
            if (!root.rows[i].header) { root.current = i; break }
        }
        view.positionViewAtIndex(root.current, ListView.Contain)
    }

    function accept() {
        if (root.current >= 0 && root.current < root.rows.length
            && !root.rows[root.current].header)
            root._pick(root.rows[root.current].name)
    }

    // Opened from the button: the menu owns the filter and the focus, exactly
    // like the Cursor palette. Opened by typing "/", the composer keeps both
    function openStandalone() {
        root.ownFilter = true
        filterField.text = ""
        filterField.forceActiveFocus()
    }

    CutShape {
        anchors.fill: parent
        fillColor: CP.alpha(CP.void2, 0.97)
        strokeColor: CP.alpha(CP.magenta, 0.45)
        strokeWidth: 1
        inset: 0.5
        cutTopRight: 12
        cutBottomRight: 12
    }

    // ── Filter field ──────────────────────────────────────────────────────
    Item {
        id: filterRow
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 26

        TextInput {
            id: filterField
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 11
            verticalAlignment: Text.AlignVCenter
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            color: root.fg
            selectionColor: CP.alpha(CP.magenta, 0.4)
            selectByMouse: true
            enabled: root.ownFilter
            clip: true

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: filterField.text === "" || !root.ownFilter
                text: root.ownFilter ? "Filter actions\u2026"
                    : "/" + root.filter
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                color: root.ownFilter ? CP.alpha(root.fg, 0.30)
                    : CP.alpha(CP.magenta, 0.70)
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.dismissed()
                    event.accepted = true
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                    root.move(event.key === Qt.Key_Down ? 1 : -1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                    || event.key === Qt.Key_Tab) {
                    root.accept()
                    event.accepted = true
                }
            }
        }
    }

    Rectangle {
        id: filterSep
        anchors { top: filterRow.bottom; left: parent.left; right: parent.right }
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        height: 1
        color: CP.alpha(CP.magenta, 0.22)
    }

    // ── Entries ───────────────────────────────────────────────────────────
    ListView {
        id: view
        anchors { top: filterSep.bottom; left: parent.left
            right: parent.right; bottom: footer.top }
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        clip: true
        model: root.rows
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            required property var modelData
            required property int index

            width: view.width
            height: modelData.header ? root.headerH : root.rowH

            // Section header: dim, small, no interaction
            Text {
                visible: modelData.header
                anchors.left: parent.left
                anchors.leftMargin: 11
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                text: modelData.name
                font.family: "Oxanium"
                font.pixelSize: 8
                font.letterSpacing: 2
                font.bold: true
                color: CP.alpha(modelData.accent, 0.42)
            }

            Rectangle {
                visible: !modelData.header
                anchors.fill: parent
                color: CP.alpha(modelData.accent, index === root.current ? 0.13 : 0)
                Behavior on color { ColorAnimation { duration: 90 } }
            }

            Rectangle {
                visible: !modelData.header && index === root.current
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: 2
                color: modelData.accent
            }

            // "namespace:command" splits so the namespace reads as a prefix and
            // the command itself keeps the weight
            readonly property int sep: modelData.header
                ? -1 : modelData.name.lastIndexOf(":")

            Row {
                visible: !modelData.header
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 11
                spacing: 0

                Text {
                    text: "/"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: CP.alpha(modelData.accent, 0.50)
                }
                Text {
                    visible: sep >= 0
                    text: sep >= 0 ? modelData.name.slice(0, sep + 1) : ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: CP.alpha(modelData.accent, 0.40)
                }
                Text {
                    text: sep >= 0 ? modelData.name.slice(sep + 1) : modelData.name
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: index === root.current ? root.fg : CP.alpha(root.fg, 0.62)
                    Behavior on color { ColorAnimation { duration: 90 } }
                }
                Text {
                    visible: modelData.hint !== ""
                    text: " " + modelData.hint
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: CP.alpha(root.fg, 0.28)
                }
            }

            // A setting flips in place, the way the extension's menu does it
            Item {
                visible: !modelData.header && modelData.toggle >= 0
                anchors.right: parent.right
                anchors.rightMargin: 11
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 10

                Rectangle {
                    anchors.fill: parent
                    color: modelData.toggle === 1 ? CP.alpha(modelData.accent, 0.25) : "transparent"
                    border.width: 1
                    border.color: CP.alpha(modelData.accent, modelData.toggle === 1 ? 0.8 : 0.35)
                }

                Rectangle {
                    x: modelData.toggle === 1 ? parent.width - width - 2 : 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6
                    height: 6
                    color: modelData.toggle === 1 ? modelData.accent : CP.alpha(root.fg, 0.4)
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: !modelData.header
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.current = index
                onClicked: root._pick(modelData.name)
            }
        }

        // Thin scrollbar, auto-hiding: the list is 70 entries long and the
        // thumb is the only thing that says so
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 3
            width: 2
            radius: 0
            visible: view.contentHeight > view.height
            y: view.contentHeight > 0
               ? view.visibleArea.yPosition * view.height : 0
            height: Math.max(18, view.visibleArea.heightRatio * view.height)
            color: CP.alpha(CP.magenta, view.moving ? 0.55 : 0.25)
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    // The description of the highlighted entry. One line at the bottom instead
    // of one per row: 70 rows each carrying ther own sentence is inreadable
    Item {
        id: footer
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: root.footerH

        readonly property var row: (root.current >= 0 && root.current < root.rows.length)
            ? root.rows[root.current] : null

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 11
            anchors.rightMargin: 11
            elide: Text.ElideRight
            text: footer.row ? footer.row.desc : ""
            font.family: "Oxanium"
            font.pixelSize: 9
            color: CP.alpha(root.fg, 0.45)
        }
    }
}
