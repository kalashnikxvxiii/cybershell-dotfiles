// AiTextMenu.qml - what a right click on text offers: copy, search, quote, and
// the editing actions when the text is the composer's.
//
// One menu for every text in the drawer. The block that was clicked is the
// target: the actions read and change its selection, so the menu holds no copy
// of the text and goes stale with nothing. A transcript block can vanish while
// the menu is up (the list rebuilds rows as a reply grows): the target then
// reads null and the menu closes itself
import QtQuick
import "../../common"
import "../../common/Colors.js" as CP

Item {
    id: root

    property Item target: null
    // Where a search goes: the selection is appended, URL-encoded
    property string searchUrl: "https://www.google.com/search?q="

    signal quoted(string text)

    readonly property color fg: "#d8e0e8"
    readonly property int rowH: 24
    readonly property bool editable: root.target !== null && !root.target.readOnly
        && root.target.enabled
    // A selection across blocks belongs to no single target
    readonly property bool multi: AiState.multiSelect && root.target !== null && root.target.readOnly
    readonly property string selected: root.multi ? AiState.selectedText() : (root.target?.selectedText ?? "")

    // Rows by what the target is: a transcript block cannot be cut nor pasted
    // into, the composer has nothing to quote
    readonly property var items: root.editable ? [
        { id: "cut", label: "CUT", glyph: "", keys: "CTRL+X", on: root.hasSel },
        { id: "copy", label: "COPY", glyph: "", keys: "CTRL+C", on: root.hasSel },
        { id: "paste", label: "PASTE", glyph: "", keys: "CTRL+V", on: root.target?.canPaste ?? false },
        { id: "sep" },
        { id: "search", label: "SEARCH THE WEB", glyph: "", keys: "", on: root.hasSel },
        { id: "all", label: "SELECT ALL", glyph: "", keys: "CTRL+A", on: (root.target?.length ?? 0) > 0 }
    ] : [
        { id: "copy", label: "COPY", glyph: "", keys: "CTRL+C", on: root.hasSel },
        { id: "search", label: "SEARCH THE WEB", glyph: "", keys: "", on: root.hasSel },
        { id: "quote", label: "QUOTE IN PROMPT", glyph: "", keys: "", on: root.hasSel },
        { id: "sep" },
        { id: "all", label: "SELECT ALL", glyph: "", keys: "CTRL+A", on: (root.target?.length ?? 0) > 0 }
    ]

    visible: root.target !== null
    width: 190
    height: col.implicitHeight + 8

    // At the pointer, flipped back inside the parent when it would spill over
    // its right or bottom edge
    function openAt(t, px, py) {
        root.target = t
        const p = root.parent
        root.x = Math.max(4, Math.min(px, p.width - root.width - 4))
        root.y = py + root.height + 4 > p.height ? Math.max(4, py - root.height) : py
    }

    function close() { root.target = null }

    function run(id) {
        const t = root.target
        const multi = root.multi
        const sel = root.selected
        root.close()
        if (!t) return
        if (id === "copy") { if (multi) AiState.copySelection(); else t.copy() }
        else if (id === "cut") t.cut()
        else if (id === "paste") t.paste()
        else if (id === "all") { t.forceActiveFocus(); t.selectAll() }
        else if (id === "search") Qt.openUrlExternally(root.searchUrl
            + encodeURIComponent(sel.trim().replace(/\s+/g, " ")))
        else if (id === "quote") root.quoted(sel)
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
                id: row
                required property var modelData

                readonly property bool sep: modelData.id === "sep"
                readonly property bool on: !sep && modelData.on === true

                width: col.width
                height: sep ? 9 : root.rowH

                Rectangle {
                    visible: row.sep
                    anchors.verticalCenter: parent.verticalCenter
                    x: 10
                    width: parent.width - 20
                    height: 1
                    color: CP.alpha(CP.magenta, 0.2)
                }

                Rectangle {
                    visible: !row.sep
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    color: CP.alpha(CP.cyan, ma.containsMouse && row.on ? 0.1 : 0)
                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                Text {
                    id: glyph
                    visible: !row.sep
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    text: row.modelData.glyph ?? ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: !row.on ? CP.alpha(root.fg, 0.2)
                        : ma.containsMouse ? CP.cyan : CP.alpha(CP.magenta, 0.8)
                }

                Text {
                    visible: !row.sep
                    anchors.left: glyph.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.label ?? ""
                    font.family: "Oxanium"
                    font.pixelSize: 10
                    font.letterSpacing: 1.6
                    font.bold: true
                    color: !row.on ? CP.alpha(root.fg, 0.25)
                        : ma.containsMouse ? CP.cyan : CP.alpha(root.fg, 0.85)
                }

                Text {
                    visible: !row.sep && (row.modelData.keys ?? "") !== ""
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.keys ?? ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 9
                    color: CP.alpha(root.fg, row.on ? 0.35 : 0.15)
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    enabled: !row.sep
                    hoverEnabled: true
                    cursorShape: row.on ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (row.on) root.run(row.modelData.id)
                }
            }
        }
    }
}
