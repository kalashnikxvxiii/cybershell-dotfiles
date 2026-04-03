// CpuModule.qml — CPU usage % via /proc/stat, intervallo 2s

import Quickshell.Io
import QtQuick
import "../../common/Colors.js" as CP
import "../../common/io"

CyberpunkModule {
    id: root
    accent: CP.cyan

    property int    usage: 0
    property string _prev: ""   // "total active"

    text: " " + usage + "%"

    onLeftClick: function() { _term.running = true }
    Process { id: _term; command: ["bash", "-c", "$TERM -e htop"]; running: false }

    TimedProcess {
        interval: 2000
        command: ["bash", "-c",
            "read _ u n s id iw irq si _ < /proc/stat; " +
            "echo $((u+n+s+id+iw+irq+si)) $((u+n+s+irq+si))"
        ]
        onData: data => {
            var parts = data.trim().split(" ")
            if (parts.length < 2) return
            var total  = parseInt(parts[0])
            var active = parseInt(parts[1])
            var prev = root._prev.split(" ")
            if (prev.length === 2) {
                var dt = total  - parseInt(prev[0])
                var da = active - parseInt(prev[1])
                root.usage = dt > 0 ? Math.round(da / dt * 100) : 0
            }
            root._prev = total + " " + active
        }
    }
}
