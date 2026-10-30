// KeyChips.qml -- one key combination as a row of keycaps. Modifiers wear the
// colour of what they mean (see modColor), plain keys stay neutral.
pragma ComponentBehavior: Bound

import QtQuick
import "../../common/Colors.js" as CP

Row {
    id: root

    property var mods: []
    property var keys: []

    spacing: 3

    function modColor(mod) {
        if (mod === "SUPER") return CP.yellow
        if (mod === "SHIFT") return CP.cyan
        if (mod === "CTRL") return CP.magenta
        if (mod === "ALT") return CP.neon
        return "#d8e6e8"
    }

    component Cap: Rectangle {
        id: cap
        property string label: ""
        property color tone: "#d8e6e8"

        width: Math.max(18, capText.implicitWidth + 10)
        height: 18
        color: Qt.rgba(tone.r, tone.g, tone.b, 0.1)
        border.width: 1
        border.color: Qt.rgba(tone.r, tone.g, tone.b, 0.55)

        Text {
            id: capText
            anchors.centerIn: parent
            text: cap.label
            font.family: "Oxanium"
            font.pixelSize: 10
            font.bold: true
            font.letterSpacing: 0.5
            color: cap.tone
        }
    }

    Repeater {
        model: root.mods
        Cap {
            required property string modelData
            label: modelData
            tone: root.modColor(modelData)
        }
    }

    Repeater {
        model: root.keys
        Cap {
            required property string modelData
            label: modelData
        }
    }
}
