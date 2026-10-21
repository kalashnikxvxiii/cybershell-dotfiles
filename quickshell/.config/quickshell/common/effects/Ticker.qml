// Ticker.qml — a subscriber to the shell's heartbeat (see ../FrameClock.qml)
//
// Continuous motion without a looping NumberAnimation. A running leaf
// animation makes Qt render the whole window at the monitor's refresh rate
// (240Hz on DP-1) however little actually moves; a Ticker wakes it ~30 times a
// second at most, and in step with every other Ticker, so they share frames.
//
//   Ticker { id: tick; running: root.visible }
//   x: -dist * (0.5 - 0.5 * Math.cos(Math.PI * ((tick.elapsed % 4000) / 4000)))
//
// or, for work that has to run on each step:
//
//   Ticker { running: root.live; every: 8; onTicked: poll() }     // ~4Hz

import QtQuick
import ".."

QtObject {
    id: root

    property bool running: false
    // Milliseconds spent running. Keeps its value across pauses
    property real elapsed: 0
    // Milliseconds covered by the latest step, for integrating simulations
    property real delta: 0
    // Act on every Nth beat of the clock: 1 is ~30Hz, 8 is ~4Hz
    property int every: 1
    // Fire once as soon as it starts, instead of waiting for the first beat
    property bool triggeredOnStart: false

    signal ticked()

    property bool _held: false
    property int  _beats: 0
    property double _last: 0

    function _sync() {
        if (root.running === root._held) return
        root._held = root.running
        if (root.running) {
            root._last = Date.now()
            root._beats = 0
            FrameClock.acquire()
            if (root.triggeredOnStart) root.ticked()
        } else {
            FrameClock.release()
        }
    }

    onRunningChanged: _sync()
    Component.onCompleted: _sync()
    Component.onDestruction: {
        if (root._held) {
            root._held = false
            FrameClock.release()
        }
    }

    property Connections _link: Connections {
        target: FrameClock
        enabled: root._held

        function onTick() {
            root._beats += 1
            if (root._beats % root.every !== 0) return
            const now = FrameClock.now
            root.delta = now - root._last
            root.elapsed += root.delta
            root._last = now
            root.ticked()
        }
    }
}
