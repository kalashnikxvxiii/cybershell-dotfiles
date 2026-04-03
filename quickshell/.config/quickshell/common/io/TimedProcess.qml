// TimedProcess.qml — Timer + Process + SplitParser in un componente DRY
// Uso: TimedProcess { interval: 2000; command: [...]; onData: data => { ... } }

import Quickshell.Io
import QtQuick

Item {
    id: root

    // ── API ──
    required property var command       // ["bash", "-c", "..."]
    property int interval: 2000         // ms tra un poll e l'altro
    property bool active: true          // pausa/riprendi senza distruggere

    // ── Callback ── assegna come: onData: data => { root.xxx = parse(data) }
    property var onData: null

    // ── Accesso diretto al Process (per trigger manuale) ──
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
