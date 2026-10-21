// AiSideAnswer.qml - the answer to a /btw, over the composer.
//
// Not a row of the transcript: the side question never enters the
// conversation, so it is drawn beside it and goes away when dismissed, as the
// CLI's panel does. It grows with the answer up to a cap, then scrolls
import QtQuick
import "../../common/effects"
import "../../common"
import "../../common/Colors.js" as CP
import "AiMarkdown.js" as Md

Item {
    id: root

    // The chat's `side`: { question, answer, error, pending }, or null
    property var side: null
    signal dismissed()

    readonly property color fg: "#d8e0e8"
    readonly property int maxBody: 220

    visible: root.side !== null
    implicitHeight: visible ? head.height + Math.min(flick.contentHeight, root.maxBody) + 26 : 0
    height: implicitHeight

    CutShape {
        anchors.fill: parent
        fillColor: CP.alpha(CP.void2, 0.92)
        strokeColor: CP.alpha(CP.cyan, 0.45)
        strokeWidth: 1
        inset: 0.5
        cutTopLeft: 8
        cutBottomRight: 8
    }

    Item {
        id: head
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.margins: 10
        height: 14

        Text {
            id: tag
            anchors.verticalCenter: parent.verticalCenter
            text: "\u25e2 BTW"
            font.family: "Oxanium"
            font.pixelSize: 9
            font.bold: true
            font.letterSpacing: 1.8
            color: CP.cyan
        }

        Text {
            anchors.left: tag.right
            anchors.leftMargin: 8
            anchors.right: close.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: root.side?.question ?? ""
            elide: Text.ElideRight
            font.family: "Oxanium"
            font.pixelSize: 10
            color: CP.alpha(root.fg, 0.6)
        }

        AiIconButton {
            id: close
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            frame: false
            glyph: "\uf00d"
            glyphSize: 10
            accent: CP.cyan
            onTriggered: root.dismissed()
        }
    }

    Flickable {
        id: flick
        anchors { top: head.bottom; left: parent.left; right: parent.right }
        anchors.topMargin: 8
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        height: Math.min(contentHeight, root.maxBody)
        contentWidth: width
        contentHeight: answer.height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Item {
            id: answer
            width: flick.width
            height: root.side?.pending || (root.side?.error ?? "") !== ""
                ? note.implicitHeight : md.height

            Text {
                id: note
                visible: root.side?.pending === true || (root.side?.error ?? "") !== ""
                width: parent.width
                wrapMode: Text.Wrap
                text: root.side?.pending ? "Thinking aside\u2026" : (root.side?.error ?? "")
                font.family: "Oxanium"
                font.pixelSize: 11
                color: root.side?.pending ? CP.alpha(CP.cyan, notePulse.k) : CP.red

                Pulse { id: notePulse; running: root.visible && root.side?.pending === true; from: 0.8; to: 0.35; halfMs: 700 }
            }

            AiMarkdownView {
                id: md
                visible: !note.visible
                width: parent.width
                blocks: visible ? Md.parse(root.side?.answer ?? "") : []
                fg: root.fg
            }
        }
    }
}
