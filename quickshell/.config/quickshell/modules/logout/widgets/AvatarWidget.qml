import QtQuick
import Quickshell
import "../../../common"


CutShape {
    id: root
    width:  380
    height: 120
    cutTopRight: 24
    fillColor:   Qt.rgba(0, 6/255, 14/255, 0.55)
    strokeColor: Qt.rgba(Colours.accentSecondary.r, Colours.accentSecondary.g, Colours.accentSecondary.b, 0.50)
    strokeWidth: 1
    inset:       0.5

    Row {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        Image {
            width: 88; height: 88
            anchors.verticalCenter: parent.verticalCenter
            source:   "file:///home/kalashnikxv/.face"
            smooth:   true
            fillMode: Image.PreserveAspectCrop
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Text {
                text:  "USER: " + (Quickshell.env("USER") || "user").toUpperCase()
                color: Colours.accentPrimary
                font.family: "Oxanium"
                font.pixelSize: 14
                font.weight:    Font.Bold
                font.letterSpacing: 2
            }
            Text {
                text:  "> host: " + (Quickshell.env("HOSTNAME") || "lucy")
                color: Colours.textSecondary
                font.family: "Oxanium"
                font.pixelSize: 11
            }
        }
    }
}
