// TimedProcess.qml — Timer + Process + SplitParser in one DRY component
// Usage: TimedProcess { interval: 2000; command: [...]; onData: data => { ... } }

import Quickshell.Io
import QtQuick

Item {
    id: root

    // ── API ──
    required property var command       // ["bash", "-c", "..."]
    property int interval: 2000         // ms between polls
    property bool active: true          // pause/resume without destroying

    // ── Callback ── assign as: onData: data => { root.xxx = parse(data) }
    property var onData: null

    // ── Direct Process access (for manual triggering) ──
    readonly property alias process: _proc
    function trigger() { _proc.running = true }

    // ── Internals ──
    Timer {
        interval: root.interval
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: _proc.running = true
    }

    Process {
        id: _proc
        command: root.command
        running: false
        stdout: SplitParser {
            onRead: data => {
                if (typeof root.onData === "function") root.onData(data)
            }
        }
    }
}
