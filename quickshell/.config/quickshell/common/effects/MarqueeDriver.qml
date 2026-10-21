// MarqueeDriver.qml — the shell's marquee timeline, on the FrameClock
//
// Hold at the origin, scroll `distance` px to the left at constant speed, hold
// at the end, snap back. The caller draws two copies of the text a gap apart,
// so the snap is invisible:
//
//   MarqueeDriver {
//       id: marquee
//       running: viewport.overflowing && root.visible
//       distance: label.implicitWidth + gap
//   }
//   x: marquee.offset
//
// A NumberAnimation would do the same job but renders the whole window at the
// monitor's refresh rate while it scrolls (see Ticker.qml).

Ticker {
    id: root

    property real distance: 0
    property int holdStartMs: 1500
    property int scrollMs: 8000
    property int holdEndMs: 1000

    readonly property real offset: {
        const t = elapsed % (holdStartMs + scrollMs + holdEndMs)
        return t < holdStartMs
            ? 0
            : -Math.min(1, (t - holdStartMs) / scrollMs) * distance
    }

    // Start the cycle over, e.g. when the text changes
    function restart() { elapsed = 0 }
}
