// CavaModule.qml — bar audio visualizer
// Uses the same CavaProvider as DashMediaMini (Audio.cava.values)

import CyberAudio.Services
import QtQuick
import "../../common/Colors.js" as CP
import "../../common"
import "../../common/effects"

Item {
    id: root
    implicitHeight: 24
    implicitWidth:  80

    property bool showBackground: true

    // The visualizer only has something to show while it is on screen and audio
    // is playing: the copy on a secondary screen is never shown at all, and
    // without playback there is nothing to capture or analyse. The capture
    // thread is joined on the GUI thread when the last reference goes, and an
    // idle one (no audio for 100 ms+) only notices at its next 500 ms tick: the
    // whole shell froze that long. Dropping the reference as soon as playback
    // stops, while chunks are still arriving, makes the join immediate
    readonly property bool live: root.visible && (Players.active?.isPlaying ?? false)

    // ── Register the CavaProvider service ──────────────────────────────────
    ServiceRef { service: root.live ? Audio.cava : null }

    // ── Audio data (float 0-1, already normalized with Monstercat smoothing)
    // A snapshot, not a binding: the provider emits ~90 times a second (one
    // 512-sample chunk at 44.1kHz) and every emission would rebind every bar and
    // push a frame of the whole fullscreen window. 30Hz reads the same on a bar
    // 24px tall
    property var cavaValues: []
    // Playing silence (or a paused tab that still reports "playing") leaves the
    // spectrum flat: an unchanged one is not pushed on, so the bars do not
    // rebind 30 times a second for nothing
    property real _sig: -1
    Ticker {
        running: root.live
        triggeredOnStart: true
        onTicked: {
            const v = Audio.cava.values
            let sig = 0
            for (let i = 0; i < v.length; i++) sig += v[i] * (i + 1)
            if (sig === root._sig) return
            root._sig = sig
            root.cavaValues = v
        }
    }
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
        fillColor: CP.moduleBg
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
