// Pulse.qml — a value that ramps from `from` to `to` and back, on the FrameClock
//
// For the pending / armed / busy pulses: a number to bind an opacity to.
// Written as a Ticker rather than a looping NumberAnimation pair, because a
// running leaf animation makes Qt render the whole window at the monitor's
// refresh rate (see Ticker.qml).
//
//   Pulse { id: pulse; running: root.busy; from: 1.0; to: 0.55; halfMs: 600 }
//   opacity: pulse.k
//
// `k` rests at `from` whenever it is not running.

Ticker {
    id: root

    property real from: 1.0
    property real to: 0.5
    // Time to go from `from` to `to`; the way back takes as long
    property int halfMs: 600
    // Ease like InOutSine instead of linearly
    property bool sine: false

    readonly property real k: {
        const u0 = (elapsed % (halfMs * 2)) / halfMs
        let u = u0 < 1 ? u0 : 2 - u0
        if (sine) u = 0.5 - 0.5 * Math.cos(Math.PI * u)
        return from + (to - from) * u
    }

    onRunningChanged: if (!running) elapsed = 0
}
