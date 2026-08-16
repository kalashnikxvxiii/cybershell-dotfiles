import QtQuick
import Quickshell.Io
import "../../../common"


CutShape {
    id: root
    width:  380
    height: 88
    cutTopRight:   12
    cutBottomLeft: 12
    fillColor:   Qt.rgba(0, 6/255, 14/255, 0.55)
    strokeColor: Qt.rgba(Colours.accentSecondary.r, Colours.accentSecondary.g, Colours.accentSecondary.b, 0.50)
    strokeWidth: 1
    inset:       0.5

    property string _location: "…"
    property string _line:     "…"

    Process {
        id: fetchProc
        running: true
        // wttr.in single-call: location|icon+temp+condition (pipe-separator)
        // Timeout 5s, fallback su offline
        command: ["bash", "-c",
                 "curl -sf --max-time 5 'wttr.in/?format=%l|%c+%t+%C' 2>/dev/null || echo '?|\u26a0  offline'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = this.text.trim()
                var parts = raw.split("|")
                if (parts.length >= 2) {
                    root._location = parts[0].trim()
                    root._line     = parts[1].trim()
                } else {
                    root._location = "?"
                    root._line     = raw
                }
            }
        }
    }

    // Refresh ogni 30 minuti
    Timer {
        interval: 30 * 60 * 1000
        running: true
        repeat:  true
        onTriggered: fetchProc.running = true
    }

    Column {
        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "// WEATHER: " + root._location.toUpperCase()
            color: Colours.textSecondary
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
            font.weight: Font.Bold
            font.letterSpacing: 2
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root._line
            color: Colours.accentPrimary
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            font.weight: Font.Bold
            font.letterSpacing: 1.5
        }
    }
}
