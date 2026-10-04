import QtQuick
import "../../../common"


CutShape {
    id: root
    width:  380
    height: 100
    fillColor:   Qt.rgba(0, 6/255, 14/255, 0.55)
    strokeColor: Qt.rgba(Colours.accentSecondary.r, Colours.accentSecondary.g, Colours.accentSecondary.b, 0.50)
    strokeWidth: 1
    inset:       0.5

    property real _now: Date.now()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root._now = Date.now() }

    Column {
        anchors.centerIn: parent
        spacing: 4
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                var d = new Date(root._now)
                return d.getHours().toString().padStart(2,'0') + ":" +
                        d.getMinutes().toString().padStart(2,'0') + ":" +
                        d.getSeconds().toString().padStart(2,'0')
            }
            color: Colours.accentPrimary
            font.family: "Oxanium"
            font.pixelSize: 34
            font.weight: Font.Bold
            font.letterSpacing: 4
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text:  "SYSTEM CLOCK"
            color: Colours.textSecondary
            font.family: "Oxanium"
            font.pixelSize: 10
            font.weight: Font.Bold
            font.letterSpacing: 2
        }
    }
}
