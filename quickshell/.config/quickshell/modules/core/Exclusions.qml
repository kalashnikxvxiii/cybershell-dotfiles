import Quickshell
import Quickshell.Wayland
import QtQuick

Scope {
    id: root
    
    required property var screen
    required property int barHeight

    PanelWindow {
        screen: root.screen
        WlrLayershell.namespace: "bar-esclusion"
        exclusiveZone: root.barHeight
        anchors.top: true
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        mask: Region {}
    }
}