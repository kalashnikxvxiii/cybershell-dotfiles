import QtQuick
import "../../../common"


CutShape {
    id: root
    width:  380
    height: 210
    cutTopRight:   12
    cutBottomLeft: 12
    fillColor:   Qt.rgba(0, 6/255, 14/255, 0.55)
    strokeColor: Qt.rgba(Colours.accentSecondary.r, Colours.accentSecondary.g, Colours.accentSecondary.b, 0.50)
    strokeWidth: 1
    inset:       0.5

    property real _now: Date.now()
    Timer { interval: 60000; running: true; repeat: true; onTriggered: root._now = Date.now() }

    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                var d = new Date(root._now)
                var months = ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"]
                return "// " + months[d.getMonth()] + " " + d.getFullYear()
            }
            color: Colours.accentPrimary
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            font.weight: Font.Bold
            font.letterSpacing: 2
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            Repeater {
                model: ["M","T","W","T","F","S","S"]
                delegate: Text {
                    required property string modelData
                    width: 26
                    text:  modelData
                    color: Colours.textSecondary
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Grid {
            anchors.horizontalCenter: parent.horizontalCenter
            columns: 7
            columnSpacing: 6
            rowSpacing: 3

            readonly property var monthCells: {
                var d = new Date(root._now)
                var year = d.getFullYear(), month = d.getMonth()
                var firstDay = new Date(year, month, 1).getDay()
                var startOffset = (firstDay === 0 ? 6 : firstDay - 1)
                var daysInMonth = new Date(year, month + 1, 0).getDate()
                var today = d.getDate()
                var cells = []
                for (var i = 0; i < startOffset; i++) cells.push({day: 0, isToday: false})
                for (var day = 1; day <= daysInMonth; day++) cells.push({day: day, isToday: day === today})
                return cells
            }

            Repeater {
                model: parent.monthCells
                delegate: Text {
                    required property var modelData
                    width: 26
                    text:  modelData.day === 0 ? "" : modelData.day.toString()
                    color: modelData.isToday ? Colours.accentPrimary : Colours.textPrimary
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.weight: modelData.isToday ? Font.Bold : Font.Normal
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
