// GpuModule.qml — GPU usage % via gpu-waybar.sh, intervallo 2s

import QtQuick
import "../../common/Colors.js" as CP
import "../../common/io"

CyberpunkModule {
    id: root
    accent: CP.neon

    property string val: "—"
    text: " " + val

    TimedProcess {
        interval: 2000
        command: ["bash", "/home/kalashnikxv/.config/waybar/scripts/gpu-waybar.sh"]
        onData: data => { root.val = data.trim() || "—" }
    }
}
