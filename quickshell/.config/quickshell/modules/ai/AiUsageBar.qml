// AiUsageBar.qml - one plan limit: its name, how much is gone, when it resets.
//
// The parent is the server's own utilization of the window. Past 80% the
// bar turns red, the threshold the Claude extension marks as well
import QtQuick
import "../../common/Colors.js" as CP

Item {
    id: root

    property string label: ""
    property real utilization: 0
    property string resetsAt: ""
    property color accent: CP.magenta

    readonly property color fg: "#d8e0e8"
    readonly property bool high: root.utilization >= 80

    // The coarsest unit is not zero: minutes, then hours, then days
    function resetText(iso) {
        if (iso === "") return ""
        const ms = new Date(iso).getTime() - Date.now()
        if (isNaN(ms)) return ""
        if (ms <= 0) return "RESETS SOON"
        const m = Math.floor(ms / 60000)
        if (m < 60) return "RESETS IN " + m + "M"
        const h = Math.floor(ms / 3600000)
        if (h < 24) return "RESETS IN " + h + "H"
        return "RESETS IN " + Math.floor(ms / 86400000) + "D"
    }

    implicitHeight: name.implicitHeight + 5 + track.height
        + (reset.text !== "" ? 4 + reset.implicitHeight : 0)

    Text {
        id: name
        anchors.left: parent.left
        anchors.top: parent.top
        text: root.label
        font.family: "Oxanium"
        font.pixelSize: 11
        color: CP.alpha(root.fg, 0.85)
    }

    Text {
        anchors.right: parent.right
        anchors.baseline: name.baseline
        text: Math.floor(root.utilization) + "%"
        font.family: "Oxanium"
        font.pixelSize: 11
        font.bold: true
        color: root.high ? CP.red : CP.alpha(root.fg, 0.85)
    }

    Rectangle {
        id: track
        anchors { top: name.bottom; left: parent.left; right: parent.right }
        anchors.topMargin: 5
        height: 4
        color: CP.alpha(root.fg, 0.08)

        Rectangle {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: parent.width * Math.max(0, Math.min(100, root.utilization)) / 100
            color: root.high ? CP.red : root.accent
        }
    }

    Text {
        id: reset
        anchors.left: parent.left
        anchors.top: track.bottom
        anchors.topMargin: 4
        text: root.resetText(root.resetsAt)
        font.family: "Oxanium"
        font.pixelSize: 8
        font.letterSpacing: 1
        color: CP.alpha(root.fg, 0.40)
    }
}
