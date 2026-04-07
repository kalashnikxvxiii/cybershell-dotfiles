import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../common/Colors.js" as CP
import "../../common"

// Compact weather preview for the Dashboard tab
// Shows: large icon + temperature + condition description
// Adapted from Caelestia dash/Weather.qml

Item {
    id: root

    property string weatherIcon: "☁"
    property string tempStr: "--°"
    property string condition: ""
    property bool loading: true

    Component.onCompleted: weatherProc.running = true

    // Refresh every 30 minutes
    Timer { interval: 1800000; running: true; repeat: true; onTriggered: weatherProc.running = true }

    Process {
        id: weatherProc
        command: ["bash", "-c", "curl -s --max-time 8 'https://wttr.in/?format=j1' 2>/dev/null || echo 'ERROR'"]
        running: false

        property string buffer: ""

        stdout: SplitParser { onRead: data => { weatherProc.buffer += data } }

        onRunningChanged: {
            if (!running && buffer !== "") {
                root.loading = false
                if (!buffer.startsWith("ERROR") && buffer.length > 10) {
                    try {
                        const data = JSON.parse(buffer)
                        const cur = data.current_condition[0]
                        root.tempStr = cur.temp_C + "°C"
                        root.condition = cur.weatherDesc[0].value
                        const code = parseInt(cur.weatherCode)
                        if (code === 113)       root.weatherIcon = "☀"
                        else if (code <= 116)   root.weatherIcon = "⛅"
                        else if (code <= 122)   root.weatherIcon = "☁"
                        else if (code <= 200)   root.weatherIcon = "🌫"
                        else if (code <= 314)   root.weatherIcon = "🌧"
                        else if (code <= 395)   root.weatherIcon = "❄"
                        else                    root.weatherIcon = "⛈"
                    } catch (e) {}
                }
                buffer = ""
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 2

        // Large icon
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.weatherIcon
            font.pixelSize: 64
            color: CP.cyan
        }

        // Temperature
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.loading ? "--°C" : root.tempStr
            font.family: "Oxanium"
            font.pixelSize: 36
            font.weight: Font.Bold
            color: Colours.accentPrimary
        }

        // Condition description
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.condition
            font.family: "Oxanium"
            font.pixelSize: 18
            color: Colours.textSecondary
            elide: Text.ElideRight
            width: 110
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 2
        }
    }
}
