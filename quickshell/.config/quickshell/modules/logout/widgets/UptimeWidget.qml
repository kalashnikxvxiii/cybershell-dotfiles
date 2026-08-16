import QtQuick
import Quickshell.Io
import "../../../common"


CutShape {
    id: root
    width:  380
    height: 72
    cutTopRight:   12
    cutBottomLeft: 12
    fillColor:   Qt.rgba(0, 6/255, 14/255, 0.55)
    strokeColor: Qt.rgba(Colours.accentSecondary.r, Colours.accentSecondary.g, Colours.accentSecondary.b, 0.50)
    strokeWidth: 1
    inset:       0.5

    property string _uptime: "…"
    Process {
        id: uptimeProc
        command: ["uptime", "-p"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root._uptime = this.text.trim().replace(/^up /, "")
        }
    }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: uptimeProc.running = true }

    Column {
        anchors.centerIn: parent
        spacing: 4
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "// UPTIME"
            color: Colours.textSecondary
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
            font.weight: Font.Bold
            font.letterSpacing: 2
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root._uptime
            color: Colours.accentPrimary
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            font.weight: Font.Bold
            font.letterSpacing: 1.5
        }
    }
}
