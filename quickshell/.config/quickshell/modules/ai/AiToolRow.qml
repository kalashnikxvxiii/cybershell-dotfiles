// AiToolRow.qml - one tool call, on one line: what ran, on what, how it went.
//
// The row of an unfolded AiToolGroup, and the tool step of an unfolded focus
// fold, where it sits between the reasoning around it in the order things
// happened. The argument is the one the extension shows next to the name
import QtQuick
import "../../common/Colors.js" as CP

Item {
    id: root

    required property var call      // { name, input, id, state }

    readonly property color tone: root.call.state === "error" ? CP.red
        : root.call.state === "running" ? CP.yellow : CP.neon

    // The field that says what the call was about, by tool
    readonly property string arg: {
        const i = root.call.input ?? {}
        const v = i.command ?? i.file_path ?? i.notebook_path ?? i.pattern
            ?? i.query ?? i.url ?? i.path ?? i.description ?? ""
        return String(v).split("\n")[0]
    }

    implicitHeight: 16
    height: implicitHeight

    Row {
        id: line
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 7

        Text {
            id: name
            anchors.verticalCenter: parent.verticalCenter
            text: "\u25e2 " + String(root.call.name).toUpperCase()
            font.family: "Oxanium"
            font.pixelSize: 9
            font.letterSpacing: 1.2
            font.bold: true
            color: root.tone
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.arg !== ""
            width: Math.min(implicitWidth, root.width - name.width - status.width - 2 * line.spacing)
            text: root.arg
            elide: Text.ElideMiddle
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
            color: CP.alpha("#d8e0e8", 0.6)
        }

        Text {
            id: status
            anchors.verticalCenter: parent.verticalCenter
            text: root.call.state === "running" ? "\u00b7\u00b7\u00b7"
                : root.call.state === "error" ? "FAIL" : "OK"
            font.family: "Oxanium"
            font.pixelSize: 9
            font.letterSpacing: 1.2
            color: CP.alpha(root.tone, 0.8)
        }
    }
}
