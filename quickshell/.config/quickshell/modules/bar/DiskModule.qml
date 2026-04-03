// DiskModule.qml — disco / usage % via df, intervallo 30s

import Quickshell.Io
import QtQuick
import "../../common/Colors.js" as CP
import "../../common/io"

CyberpunkModule {
    id: root
    accent: CP.yellow

    property string pct: "—"
    text: " " + pct + "%"

    onLeftClick: function() { _fm.running = true }
    Process { id: _fm; command: ["bash", "-c", "$FILE_MANAGER"]; running: false }

    TimedProcess {
        interval: 30000
        command: ["df", "--output=pcent", "/"]
        onData: data => {
            // output: "Use%\n 42%\n"
            var lines = data.trim().split("\n")
            if (lines.length >= 2)
                root.pct = lines[lines.length - 1].trim().replace("%", "")
        }
    }
}
