// AiHeaderButton.qml — the 120ms snappy button from the design system, sized
// for the chat header.
import QtQuick
import "../../common"
import "../../common/Colors.js" as CP

Item {
    id: root

    required property string label
    property color accent: CP.cyan
    property bool enabled: true
    signal triggered()

    width: Math.ceil(lbl.implicitWidth + 16)
    height: 22
    opacity: root.enabled ? 1 : 0.35

    CutShape {
        anchors.fill: parent
        fillColor: ma.containsMouse ? CP.alpha(root.accent, 0.10) : "transparent"
        strokeColor: CP.alpha(root.accent, 0.35)
        strokeWidth: ma.containsMouse ? 1.5 : 1
        inset: 0.5
        cutTopLeft: 2
        cutBottomRight: 2
        Behavior on fillColor { ColorAnimation { duration: 120 } }
        Behavior on strokeColor { ColorAnimation { duration: 120 } }
    }

    Text {
        id: lbl
        anchors.centerIn: parent
        text: root.label
        font.family: "Oxanium"
        font.pixelSize: 10
        font.letterSpacing: 1.2
        color: ma.containsMouse ? root.accent : CP.alpha(root.accent, 0.45)
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggered()
    }
}
