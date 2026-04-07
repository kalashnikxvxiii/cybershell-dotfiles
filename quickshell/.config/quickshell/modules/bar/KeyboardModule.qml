// KeyboardModule.qml — keyboard layout + CapsLock via keyboard-waybar.sh

import QtQuick
import "../../common/Colors.js" as CP
import "../../common/io"

CyberpunkModule {
    id: root
    accent: CP.magenta

    property string layout: "--"
    text: " " + layout

    TimedProcess {
        interval: 1000
        command: ["bash", "/home/kalashnikxv/.config/waybar/scripts/keyboard-waybar.sh"]
        onData: data => { root.layout = data.trim() || "--" }
    }
}
