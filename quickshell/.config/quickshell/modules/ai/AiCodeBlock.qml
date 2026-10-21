// AiCodeBlock.qml — fenced code, with a copy button. Shell snippets also run:
// in place, with the output under the code, or in a terminal for the ones
// that need one (sudo, prompts, pagers).
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

    readonly property bool shell: AiRunner.isShell(root.lang)
    // The run lives in AiRunner: this block is rebuilt with every new turn
    readonly property var run: {
        AiRunner.revision
        return root.shell ? AiRunner.find(root.code) : null
    }
    readonly property bool running: root.run?.running ?? false
    // Where the model's own commands run: the snippet assumes the same place
    readonly property string cwd: AiState.session?.cwd ?? ""
    property real _now: Date.now()

    implicitHeight: codeText.implicitHeight + 34 + (root.run !== null ? outPane.height + 10 : 0)
    height: implicitHeight

    Timer {
        interval: 200
        repeat: true
        running: root.running
        triggeredOnStart: true
        onTriggered: root._now = Date.now()
    }

    function _secs(ms) {
        ms = Math.max(0, ms)
        return ms < 10000 ? (ms / 1000).toFixed(1) + "s" : Math.round(ms / 1000) + "s"
    }

    component HeadButton: Text {
        id: hb
        property color accent: CP.cyan
        signal clicked()
        font.family: "Oxanium"
        font.pixelSize: 8
        font.letterSpacing: 1.8
        color: hbMa.containsMouse ? hb.accent : CP.alpha(hb.accent, 0.45)
        Behavior on color { ColorAnimation { duration: 120 } }
        MouseArea {
            id: hbMa
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: hb.clicked()
        }
    }

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

    Row {
        anchors.right: copyBtn.left
        anchors.rightMargin: 14
        anchors.top: parent.top
        anchors.topMargin: 7
        spacing: 14
        visible: root.shell

        HeadButton {
            text: "\uf120 TERM"
            onClicked: AiRunner.inTerminal(root.code, root.lang, root.cwd)
        }
        HeadButton {
            text: root.running ? "\uf04d STOP" : "\uf04b RUN"
            accent: root.running ? CP.red : CP.neon
            onClicked: root.running ? AiRunner.stop(root.code)
                : AiRunner.run(root.code, root.lang, root.cwd)
        }
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

    // -- Output ------------------------------------------
    Item {
        id: outPane
        visible: root.run !== null
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: codeText.bottom
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 10
        height: visible ? outText.y + outText.height : 0

        readonly property int exitCode: root.run?.exitCode ?? -1
        readonly property bool stopped: root.run?.stopped ?? false
        readonly property color tone: root.running || outPane.stopped ? CP.yellow
            : outPane.exitCode === 0 ? CP.neon : CP.red

        Rectangle {
            width: parent.width
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: CP.alpha(outPane.tone, 0.55) }
                GradientStop { position: 1; color: "transparent" }
            }
        }

        Text {
            id: outHead
            y: 6
            text: "\u25e2 " + (root.running
                    ? "RUNNING \u00b7 " + root._secs(root._now - (root.run?.startedAt ?? 0))
                    : (outPane.stopped ? "STOPPED" : "EXIT " + outPane.exitCode) + " \u00b7 "
                        + root._secs((root.run?.endedAt ?? 0) - (root.run?.startedAt ?? 0)))
            font.family: "Oxanium"
            font.pixelSize: 8
            font.bold: true
            font.letterSpacing: 1.8
            color: outPane.tone
        }

        HeadButton {
            anchors.right: parent.right
            anchors.top: outHead.top
            visible: !root.running
            text: "CLEAR"
            onClicked: AiRunner.clear(root.code)
        }

        AiRichText {
            id: outText
            anchors.left: parent.left
            anchors.right: parent.right
            y: outHead.y + outHead.height + 6
            textFormat: TextEdit.PlainText
            html: (root.run?.out ?? "").replace(/\n$/, "")
                || (root.running ? "\u2026" : "(no output)")
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
            color: CP.alpha("#cfe6e2", 0.85)
        }
    }
}
