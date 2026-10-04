// AiCodeBlock.qml — fenced code, with a copy button.
//
// Highlighted by AiHighlight.js into richt text. pre-wrap keeps the
// indentation and still wraps the long lines
import QtQuick
import Quickshell
import "../../common"
import "../../common/Colors.js" as CP
import "AiHighlight.js" as Hl

Item {
    id: root

    property string lang: ""
    property string code: ""
    property bool _copied: false

    implicitHeight: codeText.implicitHeight + 34
    height: implicitHeight

    CutShape {
        anchors.fill: parent
        fillColor: CP.alpha("#000000", 0.45)
        strokeColor: CP.alpha(CP.cyan, 0.30)
        strokeWidth: 1
        inset: 0.5
        cutTopRight: 6
        cutBottomLeft: 6
    }

    Text {
        id: langBadge
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.top: parent.top
        anchors.topMargin: 7
        text: (root.lang === "" ? "TEXT" : root.lang.toUpperCase())
        font.family: "Oxanium"
        font.pixelSize: 8
        font.letterSpacing: 1.8
        color: CP.alpha(CP.cyan, 0.65)
    }

    Text {
        id: copyBtn
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.top: parent.top
        anchors.topMargin: 7
        text: root._copied ? "COPIED" : "COPY"
        font.family: "Oxanium"
        font.pixelSize: 8
        font.letterSpacing: 1.8
        color: root._copied ? CP.neon
            : (copyMa.containsMouse ? CP.cyan : CP.alpha(CP.cyan, 0.45))
        Behavior on color { ColorAnimation { duration: 120 } }

        MouseArea {
            id: copyMa
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                // argv, not a shell string: `--` covers code that starts with a
                // dash and nothing needs quoting or escaping. `-n` drops the
                // trailing newline wl-copy would otherwise add.
                Quickshell.execDetached(["wl-copy", "-n", "--", root.code])
                root._copied = true
                copyReset.restart()
            }
        }
    }

    Timer {
        id: copyReset
        interval: 1200
        onTriggered: root._copied = false
    }

    AiRichText {
        id: codeText
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: langBadge.bottom
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 6
        html: '<div style="white-space:pre-wrap">' + Hl.highlight(root.code, root.lang) + "</div>"
        lineHeight: 1
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 10
        // No ligatures: "->" stays two characters, as it will be when pasted
        font.features: { "calt": 0, "liga": 0 }
    }
}
