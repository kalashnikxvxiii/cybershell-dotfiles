// BluetoothModule.qml — bluetooth status via bluetoothctl, 30s interval

import Quickshell.Io
import QtQuick
import "../../common/Colors.js" as CP
import "../../common/io"

CyberpunkModule {
    id: root

    property string btStatus:  "—"
    property bool   connected: false

    accent: connected ? CP.cyan : Qt.rgba(0.2, 0.2, 0.2, 1.0)
    text:   connected ? " " + btStatus : " OFF"

    onLeftClick: function() { _bmgr.running = true }
    Process { id: _bmgr; command: ["blueman-manager"]; running: false }

    TimedProcess {
        interval: 30000
        command: ["bash", "-c", `
            dev=$(bluetoothctl info 2>/dev/null | grep -E 'Name|Connected')
            name=$(echo "$dev" | grep 'Name:' | sed 's/.*Name: //')
            conn=$(echo "$dev" | grep 'Connected: yes')
            if [ -n "$conn" ] && [ -n "$name" ]; then
                echo "connected|$name"
            else
                echo "off"
            fi
        `]
        onData: data => {
            var parts = data.trim().split("|")
            root.connected = parts[0] === "connected"
            root.btStatus  = root.connected ? parts[1] : "OFF"
        }
    }
}
