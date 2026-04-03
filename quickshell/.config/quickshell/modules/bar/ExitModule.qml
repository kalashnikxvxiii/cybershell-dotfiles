// ExitModule.qml — pulsante exit/poweroff/reboot (danger button)
// Click sx: hyprctl exit | Click dx: poweroff | Click mid: reboot

import Quickshell.Io
import QtQuick
import Quickshell.Hyprland
import "../../common/Colors.js" as CP

CyberpunkModule {
    id: root
    accent: CP.red

    text: " "

    onLeftClick:   function() { Hyprland.dispatch("exit") }
    onRightClick:  function() { _poweroff.running = true }
    onMiddleClick: function() { _reboot.running   = true }

    // Extra glow on hover
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        visible: root.hovered
        Rectangle {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: 6
            color: "transparent"
            // box-shadow: -4px 0 22px alpha(cp-red, 0.6)
            // emulato con gradiente
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(1, 0, 0.235, 0.35) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    Process { id: _poweroff; command: ["systemctl", "poweroff"]; running: false }
    Process { id: _reboot;   command: ["systemctl", "reboot"];   running: false }
}
