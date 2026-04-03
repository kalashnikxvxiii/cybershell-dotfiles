// NetworkModule.qml — stato rete via nmcli, intervallo 5s

import QtQuick
import "../../common/Colors.js" as CP
import "../../common/io"
import "../../common/effects"

CyberpunkModule {
    id: root

    property string netStatus: "off"
    property bool   connected: netStatus !== "off"
    property string ssid:      ""
    property string signal:    ""

    accent: connected ? CP.cyan : CP.red
    text: {
        if (netStatus === "off")      return " OFF"
        if (netStatus === "ethernet") return " "
        return " " + ssid + " " + signal + "%"
    }

    PulseAnim on opacity { running: !root.connected; duration: 700 }

    TimedProcess {
        interval: 5000
        command: ["bash", "-c",
            "if ip route show default | grep -q ' dev e'; then\n" +
            "  echo 'ethernet'\n" +
            "elif ip route show default | grep -q default; then\n" +
            "  s=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2)\n" +
            "  g=$(nmcli -t -f active,signal dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2)\n" +
            "  echo \"wifi|${s}|${g}\"\n" +
            "else\n" +
            "  echo 'off'\n" +
            "fi"
        ]
        onData: data => {
            var parts = data.trim().split("|")
            if (parts[0] === "ethernet") {
                root.netStatus = "ethernet"
            } else if (parts[0] === "wifi") {
                root.netStatus = "wifi"
                root.ssid      = parts[1] || ""
                root.signal    = parts[2] || ""
            } else {
                root.netStatus = "off"
            }
        }
    }
}
