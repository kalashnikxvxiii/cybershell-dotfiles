// CavaModule.qml — bar audio visualizer
// Uses the same CavaProvider as DashMediaMini (Audio.cava.values)

import CyberAudio.Services
import QtQuick
import "../../common/Colors.js" as CP
import "../../common"

Item {
    id: root
    implicitHeight: 24
    implicitWidth:  80

    property bool showBackground: true

    // ── Register the CavaProvider service ──────────────────────────────────
    ServiceRef { service: Audio.cava }

    // ── Audio data (float 0-1, already normalized with Monstercat smoothing)
    property var cavaValues: Audio.cava.values
    readonly property int barCount: Math.max(1, Math.round(root.width / 6))

    function levelAt(index) {
        var vals = cavaValues
        if (!vals || vals.length === 0) return 0
        var n = vals.length
        var segSize = n / barCount
        var start = Math.floor(index * segSize)
        var end   = Math.min(n, Math.floor((index + 1) * segSize))
        if (start >= n) return 0
        if (end <= start) end = start + 1
        var sum = 0
        for (var i = start; i < end; i++) sum += (vals[i] ?? 0)
        return Math.max(0, Math.min(1, sum / (end - start)))
    }

    // ── Optional background ──────────────────────────────────────────────────
    CutShape {
        visible: root.showBackground
        anchors.fill: parent
        color: CP.moduleBg
        radiusBottomLeft: 10
        Rectangle { width: 2; height: parent.height; color: CP.cyan }
    }

    // ── Bars ─────────────────────────────────────────────────────────────────
    Row {
        id: barsRow
        clip: true
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: parent.height
        spacing: 1

        Repeater {
            model: root.barCount

            delegate: Rectangle {
                required property int index
                readonly property real level: root.levelAt(index)

                width:          Math.max(2, barsRow.width / root.barCount - 1)
                anchors.bottom: parent.bottom
                height:         Math.max(0, level * barsRow.height)

                gradient: Gradient {
                    GradientStop { position: 1.0; color: CP.alpha(CP.yellow, 0.9) }
                    GradientStop { position: 0.0; color: CP.alpha(CP.yellow, 0.0) }
                }
            }
        }
    }
}
