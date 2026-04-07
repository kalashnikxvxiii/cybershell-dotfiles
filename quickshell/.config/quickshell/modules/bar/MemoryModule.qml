// MemoryModule.qml — RAM usage % via /proc/meminfo, 5s interval

import Quickshell.Io
import QtQuick
import "../../common/Colors.js" as CP
import "../../common/io"

CyberpunkModule {
    id: root
    accent: CP.magenta

    property int pct: 0
    text: " " + pct + "%"

    onLeftClick: function() { _term.running = true }
    Process { id: _term; command: ["bash", "-c", "$TERM -e htop"]; running: false }

    TimedProcess {
        interval: 5000
        command: ["bash", "-c",
            "awk '/MemTotal/{t=$2}/MemFree/{f=$2}/Buffers/{b=$2}/^Cached/{c=$2}/SReclaimable/{s=$2}" +
            "END{printf \"%d\\n\",int((t-f-b-c-s)*100/t)}' /proc/meminfo"
        ]
        onData: data => {
            var n = parseInt(data.trim())
            if (!isNaN(n)) root.pct = n
        }
    }
}
