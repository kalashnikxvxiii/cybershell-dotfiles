// TemperatureModule.qml — CPU temp via hwmon o sensors, intervallo 5s

import QtQuick
import "../../common/Colors.js" as CP
import "../../common"
import "../../common/io"
import "../../common/effects"

CyberpunkModule {
    id: root

    property int  tempC:    0
    property bool critical: tempC >= 80

    accent: critical ? CP.red : Colours.accentWarn
    text:   (critical ? " " : " ") + tempC + "°C"

    PulseAnim on opacity { running: root.critical; duration: 600 }

    TimedProcess {
        interval: 5000
        command: ["bash", "-c",
            // Prova hwmon prima, poi nvidia-smi, poi 0
            "t=$(cat /sys/class/hwmon/hwmon*/temp*_input 2>/dev/null | sort -n | tail -1); " +
            "[ -n \"$t\" ] && echo $((t/1000)) || " +
            "nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null || " +
            "echo 0"
        ]
        onData: data => {
            var n = parseInt(data.trim())
            if (!isNaN(n)) root.tempC = n
        }
    }
}
