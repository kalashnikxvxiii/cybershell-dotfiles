// AiResumeMenu.qml - /resume: the sessions the CLI has on disk, newest first.
//
// `claude -p` has no /resume of its own, its picker is a terminal screen. This
// is that picker: scripts/ai-sessions.py reads the CLI's transcripts, a pick
// opens the session in a tab. Same frame and keys as the action palette
import QtQuick
import Quickshell
import Quickshell.Io
import "../../common"
import "../../common/Colors.js" as CP

Item {
    id: root

    property var sessions: []
    property int current: 0

    signal picked(string id, string title, string cwd)
    signal dismissed()

    readonly property color fg: "#d8e0e8"
    readonly property int rowH: 22
    readonly property int maxRows: 9

    readonly property var rows: {
        const f = filterField.text.toLowerCase()
        return root.sessions.filter(s => f === "" || s.title.toLowerCase().indexOf(f) >= 0)
    }

    onRowsChanged: root.current = 0

    implicitHeight: filterRow.height + 1 + 8
        + Math.max(1, Math.min(root.maxRows, root.rows.length)) * root.rowH + footer.height
    height: implicitHeight

    // Read fresh at every opening: a session finished elsewhere a minute ago
    // belongs at the top of the list
    function openMenu() {
        filterField.text = ""
        root.sessions = []
        lister.running = true
        filterField.forceActiveFocus()
    }

    function move(delta) {
        const n = root.rows.length
        if (n === 0) return
        root.current = ((root.current + delta) % n + n) % n
        view.positionViewAtIndex(root.current, ListView.Contain)
    }

    function accept() {
        const s = root.rows[root.current]
        if (s) root.picked(s.id, s.title, s.cwd)
    }

    // Minutes, hours, days: the scale that says how stale a session is
    function ago(ms) {
        const m = Math.floor((Date.now() - ms) / 60000)
        if (m < 1) return "NOW"
        if (m < 60) return m + "M"
        if (m < 1440) return Math.floor(m / 60) + "H"
        if (m < 10080) return Math.floor(m / 1440) + "D"
        return Qt.formatDate(new Date(ms), "dd MMM").toUpperCase()
    }

    Process {
        id: lister
        running: false
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/ai-sessions.py",
            "list", AiState.session.defaultCwd, Quickshell.env("HOME") + "/Documenti/DE-docs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const l = JSON.parse(text)
                    if (Array.isArray(l)) root.sessions = l
                } catch (e) {}
            }
        }
        stderr: SplitParser { onRead: l => console.warn("[ai-sessions]", l) }
    }

    CutShape {
        anchors.fill: parent
        fillColor: CP.alpha(CP.void2, 0.97)
        strokeColor: CP.alpha(CP.magenta, 0.45)
        strokeWidth: 1
        inset: 0.5
        cutTopLeft: 12
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
            clip: true

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: filterField.text === ""
                text: "Resume a session\u2026"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                color: CP.alpha(root.fg, 0.30)
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.dismissed()
                    event.accepted = true
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                    root.move(event.key === Qt.Key_Down ? 1 : -1)
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
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

    // ── Sessions ──────────────────────────────────────────────────────────
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
            id: entry

            required property var modelData
            required property int index

            // Already in a tab: picking it brings that tab forward
            readonly property bool isOpen:
                AiState.chats.some(c => c.session.sessionId === modelData.id)

            width: view.width
            height: root.rowH

            Rectangle {
                anchors.fill: parent
                color: CP.alpha(CP.magenta, entry.index === root.current ? 0.13 : 0)
                Behavior on color { ColorAnimation { duration: 90 } }
            }

            Rectangle {
                visible: entry.index === root.current
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: 2
                color: CP.magenta
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 11
                anchors.right: meta.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: entry.modelData.title
                elide: Text.ElideRight
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                color: entry.index === root.current ? root.fg : CP.alpha(root.fg, 0.62)
                Behavior on color { ColorAnimation { duration: 90 } }
            }

            Row {
                id: meta
                anchors.right: parent.right
                anchors.rightMargin: 11
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Filed outside the default directory: it comes back up
                // in that one, named by its last folder
                Text {
                    visible: entry.modelData.cwd !== AiState.session.defaultCwd
                    text: entry.modelData.cwd.split("/").pop()
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    font.bold: true
                    color: CP.alpha(CP.yellow, 0.7)
                }

                Text {
                    visible: entry.isOpen
                    text: "OPEN"
                    font.family: "Oxanium"
                    font.pixelSize: 8
                    font.letterSpacing: 2
                    font.bold: true
                    color: CP.alpha(CP.magenta, 0.75)
                }

                Text {
                    text: root.ago(entry.modelData.mtime)
                    font.family: "Oxanium"
                    font.pixelSize: 9
                    font.letterSpacing: 1
                    color: CP.alpha(CP.cyan, 0.55)
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.current = entry.index
                onClicked: root.picked(entry.modelData.id, entry.modelData.title, entry.modelData.cwd)
            }
        }

        Text {
            anchors.centerIn: parent
            visible: root.rows.length === 0
            text: lister.running ? "READING SESSIONS\u2026" : "NO SESSIONS"
            font.family: "Oxanium"
            font.pixelSize: 9
            font.letterSpacing: 2
            color: CP.alpha(root.fg, 0.35)
        }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 3
            width: 2
            visible: view.contentHeight > view.height
            y: view.visibleArea.yPosition * view.height
            height: Math.max(18, view.visibleArea.heightRatio * view.height)
            color: CP.alpha(CP.magenta, view.moving ? 0.55 : 0.25)
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    Item {
        id: footer
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 18

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 11
            text: root.rows.length + " SESSIONS \u00b7 ENTER TO RESUME"
            font.family: "Oxanium"
            font.pixelSize: 9
            font.letterSpacing: 1
            color: CP.alpha(root.fg, 0.45)
        }
    }
}
