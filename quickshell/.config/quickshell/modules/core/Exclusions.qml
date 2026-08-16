import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../common"

Scope {
    id: root
    
    required property var screen
    required property int barHeight

    PanelWindow {
        screen: root.screen
        WlrLayershell.namespace: "bar-esclusion"
        exclusiveZone: BarState.isVisibleOn(root.screen.name) ? root.barHeight : 0
        anchors.top: true
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        mask: Region {}
    }
}