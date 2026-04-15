// Submap.qml — HUD mode indicator (hyprland/submap)
// Shows "—" when in default submap, active submap name otherwise
// Style: cyan when inactive → yellow when active

import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../../common/Colors.js" as CP
import "../../common"

Item {
    id: root
    implicitHeight: 24
    implicitWidth:  label.implicitWidth + 22

    property bool showBackground: true
    property string submap: Hyprland.submap ?? ""
    property bool   isActive: submap.length > 0
    property color  accent: isActive ? CP.yellow : Qt.rgba(0, 1, 0.824, 0.7)

    CutShape {
        visible: root.showBackground
        anchors.fill: parent
        fillColor: CP.moduleBg
        radiusBottomRight: 10
        radiusBottomLeft: 5

        Rectangle {
            width: 2; height: parent.height
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b,
                           root.isActive ? 1.0 : 0.4)
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width; height: 1
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b,
                           root.isActive ? 0.4 : 0.25)
        }
    }

    Text {
        id: label
        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 10 }
        text:           root.isActive ? "[" + root.submap + "]" : "—"
        font.family:    "Oxanium"
        font.pixelSize: 11
        color:          root.accent
        font.letterSpacing:  2
        style:          Text.Raised
        styleColor:     Qt.rgba(Qt.color(root.accent).r, Qt.color(root.accent).g, Qt.color(root.accent).b, 0.4)
        transform: Translate { id: labelShift; x: 0 }
    }

    GlitchAnim {
        id: glitchAnim; labelTarget: label; shiftTarget: labelShift
        baseColor: root.accent; shortMode: true; x1: 3; x2: -3; finalPause: 174
    }
    HoverHandler { onHoveredChanged: if (hovered) glitchAnim.restart() }
}
