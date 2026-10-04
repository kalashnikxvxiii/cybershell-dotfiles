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
    font.family: "Oxanium"
    font.pixelSize: 12
    color: "#d8e0e8"

    // "fn:" links are footnote references, with nowhere to go
    onLinkActivated: l => { if (!l.startsWith("fn:")) Qt.openUrlExternally(l) }

    // A click gives this block the keyboard, so Ctrl+C can reach it. Anything
    // that is not a copy goes back to the composer, typed key included: the
    // reader who starts writing after selecting expects the words in the box
    Keys.onPressed: event => {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
        if (event.key === Qt.Key_Escape) {
            root.deselect()
            AiState.focusComposer("")
            event.accepted = true
        } else if (!ctrl && !(event.modifiers & Qt.AltModifier) && event.text !== ""
            && event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backtab) {
            root.deselect()
            AiState.focusComposer(event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                || event.key === Qt.Key_Backspace ? "" : event.text)
            event.accepted = true
        }
    }

    // Takes no button: presses reach the TextEdit and its links, wheel events
    // the list. Only the pointer shape is decided here
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        cursorShape: root.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.IBeamCursor
    }
}
