// LoadModule.qml — load average 1/5/15, intervallo 5s

import QtQuick
import "../../common/Colors.js" as CP
import "../../common/io"

CyberpunkModule {
    id: root
    accent: CP.yellow

    property string avg1:  "—"
    property string avg5:  "—"
    property string avg15: "—"
    text: " " + avg1 + " " + avg5 + " " + avg15

    TimedProcess {
        interval: 5000
        command: ["bash", "-c", "cut -d' ' -f1-3 /proc/loadavg"]
        onData: data => {
            var parts = data.trim().split(" ")
            if (parts.length >= 3) {
                root.avg1  = parts[0]
                root.avg5  = parts[1]
                root.avg15 = parts[2]
            }
        }
    }
}
