// WindowTitle.qml — titolo finestra attiva via Hyprland.activeToplevel

import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Shapes
import "../../common/Colors.js" as CP
import "../../common"

Item {
    id: root
    implicitHeight: 24
    implicitWidth:  label.implicitWidth + 28

    property string rawTitle: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : ""
    property string title: {
        var t = rawTitle.length > 25 ? rawTitle.slice(0, 25) : rawTitle
        return t.length > 0 ? "╰┈➤ " + t : ""
    }

    Text {
        id: label
        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 14 }
        text:               root.title
        font.family:        "Oxanium"
        font.pixelSize:     12
        font.letterSpacing: 2
        color:              CP.white
        style:              Text.Raised
        styleColor:         Qt.rgba(1, 1, 1, 0.3)
        transform: Translate { id: labelShift; x: 0 }
    }

    GlitchAnim { id: glitchAnim; labelTarget: label; shiftTarget: labelShift; baseColor: CP.white }
    HoverHandler { onHoveredChanged: if (hovered) glitchAnim.restart() }
}
