// AiMessageMenu.qml - what a prompt of the transcript offers: fork the
// conversation from it, rewind the code to before it, or both.
//
// A rewind undoes edits on disk, so it is never one click: the first one runs
// a dry run and the menu shows what would go back, the second one confirms.
// The state of that preview lives in the chat (rewindPreview), the menu only
// draws it
import QtQuick
import "../../common"
import "../../common/Colors.js" as CP

Item {
    id: root

    property int row: -1
    readonly property var chat: AiState.chat
    readonly property bool busy: root.chat?.session.busy ?? true
    // The preview of this row, if there is one
    readonly property var preview: {
        const p = root.chat?.rewindPreview ?? null
        return p !== null && p.row === root.row ? p : null
    }

    readonly property color fg: "#d8e0e8"
    readonly property int rowH: 24

    readonly property var items: [
        { id: "fork", label: "FORK CONVERSATION", glyph: "\ue0a0" },
        { id: "rewind", label: "REWIND CODE TO HERE", glyph: "\uf0e2" },
        { id: "fork-rewind", label: "FORK AND REWIND CODE", glyph: "\uf1da" }
    ]

    visible: root.row >= 0
    width: 230
    height: col.implicitHeight + 8

    // Under the button, right-aligned to it, flipped above when it would
    // spill over the bottom of the parent
    function openAt(r, px, py, below) {
        root.row = r
        const p = root.parent
        root.x = Math.max(4, Math.min(px - root.width, p.width - root.width - 4))
        root.y = below + root.height + 4 > p.height ? Math.max(4, py - root.height - 4) : below + 4
    }

    function close() {
        if (root.preview !== null) root.chat.cancelRewind()
        root.row = -1
    }

    function run(id) {
        if (id === "fork") {
            const r = root.row
            root.close()
            AiState.fork(root.chat, r, false)
        } else {
            root.chat.previewRewind(root.row, id)
        }
    }

    function confirm() {
        const p = root.preview
        if (!p || !p.ok) return
        const r = root.row
        root.row = -1
        if (p.action === "fork-rewind") {
            root.chat.cancelRewind()
            AiState.fork(root.chat, r, true)
        } else {
            root.chat.rewindFiles(p.uuid, null)
            root.chat.cancelRewind()
        }
    }

    // Any change of the view under it makes the row index stale
    Connections {
        target: AiState
        function onChatChanged() { root.close() }
    }

    CutShape {
        anchors.fill: parent
        fillColor: CP.alpha(CP.void2, 0.97)
        strokeColor: CP.alpha(CP.magenta, 0.45)
        strokeWidth: 1
        inset: 0.5
        cutTopRight: 10
        cutBottomLeft: 10
    }

    Column {
        id: col
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.topMargin: 4

        Repeater {
            model: root.items

            delegate: Item {
                id: item
                required property var modelData

                readonly property bool on: !root.busy && root.preview === null
                readonly property bool picked: root.preview?.action === item.modelData.id

                width: col.width
                height: root.rowH

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    color: CP.alpha(CP.cyan, item.picked ? 0.08
                        : ma.containsMouse && item.on ? 0.1 : 0)
                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                Text {
                    id: glyph
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    text: item.modelData.glyph
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: item.picked ? CP.cyan
                        : !item.on ? CP.alpha(root.fg, 0.2)
                        : ma.containsMouse ? CP.cyan : CP.alpha(CP.magenta, 0.8)
                }

                Text {
                    anchors.left: glyph.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: item.modelData.label
                    font.family: "Oxanium"
                    font.pixelSize: 10
                    font.letterSpacing: 1.6
                    font.bold: true
                    color: item.picked ? CP.cyan
                        : !item.on ? CP.alpha(root.fg, 0.25)
                        : ma.containsMouse ? CP.cyan : CP.alpha(root.fg, 0.85)
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: item.on ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (item.on) root.run(item.modelData.id)
                }
            }
        }

        // -- The dry run, and the confirmation ---------------------------
        Item {
            id: confirmBox
            visible: root.preview !== null
            width: col.width
            height: visible ? summary.implicitHeight + buttons.height + 22 : 0

            readonly property var p: root.preview ?? ({})
            readonly property bool nothing: confirmBox.p.ok === true && (confirmBox.p.files ?? 0) === 0

            Rectangle {
                x: 10
                y: 4
                width: parent.width - 20
                height: 1
                color: CP.alpha(CP.magenta, 0.2)
            }

            Text {
                id: summary
                x: 12
                y: 12
                width: parent.width - 24
                wrapMode: Text.Wrap
                text: confirmBox.p.pending ? "\u25e2 CHECKING\u2026"
                    : !confirmBox.p.ok ? "\u25e2 " + (confirmBox.p.error || "CANNOT REWIND").toUpperCase()
                    : confirmBox.nothing ? "\u25e2 NO FILE CHANGED SINCE THIS PROMPT"
                    : "\u25e2 " + confirmBox.p.files + (confirmBox.p.files === 1 ? " FILE" : " FILES")
                        + " \u00b7 +" + confirmBox.p.ins + " \u2212" + confirmBox.p.del
                font.family: "Oxanium"
                font.pixelSize: 9
                font.bold: true
                font.letterSpacing: 1.4
                color: confirmBox.p.pending ? CP.yellow
                    : !confirmBox.p.ok ? CP.red : CP.cyan
            }

            Row {
                id: buttons
                x: 12
                anchors.top: summary.bottom
                anchors.topMargin: 6
                height: 18
                spacing: 6

                AiHeaderButton {
                    // Nothing to undo: a fork still makes sense, a rewind does not
                    visible: confirmBox.p.ok === true
                        && (!confirmBox.nothing || confirmBox.p.action === "fork-rewind")
                    label: confirmBox.p.action === "fork-rewind" ? "FORK + REWIND" : "REWIND"
                    accent: CP.yellow
                    onTriggered: root.confirm()
                }

                AiHeaderButton {
                    label: confirmBox.p.pending || confirmBox.p.ok ? "CANCEL" : "CLOSE"
                    accent: CP.magenta
                    onTriggered: root.chat.cancelRewind()
                }
            }
        }
    }
}
