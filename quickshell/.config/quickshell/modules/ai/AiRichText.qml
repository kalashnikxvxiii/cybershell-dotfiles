// AiRichText.qml - a run of chat prose in rich text, as AiMarkdown.js
// builds it. Links open in the browser and show the hand on hover.
//
// A read-only TextEdit and not a Text: a Text cannot be selected. The price is
// that TextEdit has no lineHeight, so the spacing travels inside the markup as
// a CSS line-height on a wrapping block, which QTextDocument honours.
// Selection stays within one block: each paragraph is its own document
import QtQuick
import "../../common"
import "../../common/Colors.js" as CP

TextEdit {
    id: root

    // The markup to show. `text` is derived from it: set this one
    property string html: ""
    // Proportional, as Text.lineHeight was. 1 leaves the markup untouched
    property real lineHeight: 1.3

    text: root.textFormat === TextEdit.RichText && root.lineHeight !== 1
        ? '<div style="line-height:' + Math.round(root.lineHeight * 100) + '%">'
            + root.html + "</div>"
        : root.html
    textFormat: TextEdit.RichText
    wrapMode: TextEdit.Wrap
    readOnly: true
    selectByMouse: true
    // Ctrl+A would select the whole transcript in a terminal; here it selects
    // the block, which is the most a single document can hold
    selectByKeyboard: true
    selectionColor: CP.alpha(CP.magenta, 0.4)
    selectedTextColor: "#f2f6f8"
    // Kept on screen without the focus only while a selection spans blocks
    persistentSelection: AiState.multiSelect
    Component.onCompleted: AiState.registerText(root)
    Component.onDestruction: AiState.unregisterText(root)
    font.family: "Oxanium"
    font.pixelSize: 12
    color: "#d8e0e8"

    // "fn:" links are footnote references, with nowhere to go. Only web and
    // mail links leave the shell: the text comes from the model, and a file://
    // or custom-scheme link would hand xdg-open whatever it was told to open
    onLinkActivated: l => {
        const u = String(l).toLowerCase()
        if (u.startsWith("https://") || u.startsWith("http://") || u.startsWith("mailto:"))
            Qt.openUrlExternally(l)
    }

    // A click gives this block the keyboard, so Ctrl+C can reach it. Anything
    // that is not a copy goes back to the composer, typed key included: the
    // reader who starts writing after selecting expects the words in the box
    Keys.onPressed: event => {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
        if (ctrl && event.key === Qt.Key_C && AiState.multiSelect) {
            AiState.copySelection()
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            AiState.clearSelection()
            AiState.focusComposer("")
            event.accepted = true
        } else if (!ctrl && !(event.modifiers & Qt.AltModifier) && event.text !== ""
            && event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backtab) {
            AiState.clearSelection()
            AiState.focusComposer(event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                || event.key === Qt.Key_Backspace ? "" : event.text)
            event.accepted = true
        }
    }

    // The right button only: left presses reach the TextEdit and its links,
    // wheel events the list (no handler, so the wheel is not taken). A right
    // press on a selection keeps it; anywhere else the menu has nothing to
    // copy but can still select the block
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        cursorShape: root.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.IBeamCursor
        onPressed: mouse => AiState.textMenuRequested(root, mouse.x, mouse.y)
    }
}
