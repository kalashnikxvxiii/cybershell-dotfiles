// FrameClock.qml — the shell's one heartbeat for stepped visual effects
//
// Everything that moves without a user touching it (particles, pulses,
// marquees, meters, canvas sweeps) steps on this clock instead of running its
// own NumberAnimation or Timer, for two reasons:
//
//  * A running NumberAnimation makes Qt render the whole window at the
//    monitor's refresh rate (240Hz on DP-1) however little actually moves.
//  * A Timer per effect fires at its own phase, so N effects cost N frames per
//    period. On this clock they all update in the same event-loop turn, which
//    the scene graph folds into a single frame.
//
// It only runs while at least one Ticker (effects/Ticker.qml) is running, so an
// idle shell costs nothing. Use Ticker, not this, from components.

pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // ~30Hz: enough for motion on a 24px bar or a 400px card, a quarter of
    // what the 240Hz monitor would otherwise be asked for
    readonly property int interval: 33

    property int users: 0
    // Wall-clock ms of the latest tick
    property real now: Date.now()

    signal tick()

    function acquire() { users += 1 }
    function release() { users = Math.max(0, users - 1) }

    Timer {
        interval: root.interval
        repeat: true
        running: root.users > 0
        onTriggered: {
            root.now = Date.now()
            root.tick()
        }
    }
}
