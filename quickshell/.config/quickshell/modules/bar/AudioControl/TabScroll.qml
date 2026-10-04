// TabScroll.qml — contenitore scrollabile per il contenuto di una tab.
// Scorre solo quando il contenuto eccede l'altezza disponibile, e la barra
// compare solo in quel caso (stesso idioma della griglia playlist).
import "../../../common/Colors.js" as CP
import "../../../common"
import QtQuick

Item {
    id: root

    default property alias content: col.data
    property int spacing: 10
    readonly property real contentHeight: col.implicitHeight

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
            id: col
            width: flick.width - 10
            spacing: root.spacing
        }
    }

    // Scrollbar — fratello del Flickable, quindi non scorre col contenuto
    Item {
        id: sb
        z: 5
        anchors.right:  parent.right
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        width: 12

        readonly property real _range: Math.max(0, flick.contentHeight - flick.height)
        readonly property bool needed: _range > 0
        readonly property real thumbH: Math.max(28, height * flick.height
                                                    / Math.max(1, flick.contentHeight))

        visible: opacity > 0
        opacity: needed ? (sbMa.containsMouse || sbMa.pressed ? 1.0 : 0.5) : 0
        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.right:  parent.right
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            width: 4
            color: CP.alpha(CP.void2, 0.55)
        }

        Rectangle {
            id: sbThumb
            anchors.right: parent.right
            width: 4
            height: sb.thumbH
            y: sb._range > 0 ? (flick.contentY / sb._range) * (sb.height - height) : 0
            color: sbMa.pressed ? CP.cyan : CP.alpha(CP.cyan, 0.7)
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        MouseArea {
            id: sbMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            property real _grab: 0

            function _scrollTo(y) {
                var travel = sb.height - sbThumb.height
                if (travel <= 0) return
                var t = Math.max(0, Math.min(travel, y))
                flick.contentY = (t / travel) * sb._range
            }

            onPressed: mouse => {
                if (mouse.y >= sbThumb.y && mouse.y <= sbThumb.y + sbThumb.height)
                    _grab = mouse.y - sbThumb.y
                else {
                    _grab = sbThumb.height / 2
                    _scrollTo(mouse.y - _grab)
                }
            }
            onPositionChanged: mouse => { if (pressed) _scrollTo(mouse.y - _grab) }
        }
    }
}
