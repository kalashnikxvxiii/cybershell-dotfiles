import "../../common/Colors.js" as CP
import "../../common"
import QtQuick

Item {
    id: root

    property string label: ""
    property string suffix: ""
    property real value: 0
    property real minValue: 0
    property real maxValue: 100
    property int decimals: 0
    property bool isInt: true
    signal valueEdited(real v)

    implicitWidth: 200
    implicitHeight: 38

    function _norm() {
        var d = maxValue - minValue
        return d <= 0 ? 0 : Math.max(0, Math.min(1, (value - minValue) / d))
    }
    function _setFromX(x) {
        var n = Math.max(0, Math.min(1, x / track.width))
        var v = minValue + n * (maxValue - minValue)
        v = isInt ? Math.round(v) : parseFloat(v.toFixed(decimals))
        if (v !== value) root.valueEdited(v)
    }

    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 14

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.label.toUpperCase()
            font.family: "Oxanium"
            font.pixelSize: 9
            font.letterSpacing: 1.5
            color: Colours.textMuted
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: (root.isInt ? Math.round(root.value).toString()
                              : root.value.toFixed(root.decimals)) + root.suffix
            font.family: "Oxanium"
            font.pixelSize: 9
            color: Colours.accentPrimary
        }
    }

    Item {
        id: trackWrap
        anchors.top: header.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        height: 16

        CutShape {
            id: track
            anchors.fill: parent
            fillColor: CP.alpha(CP.void2, 0.6)
            strokeColor: CP.alpha(CP.yellow, 0.30)
            strokeWidth: 1
            inset: 0.5
            cutTopLeft: 2
            cutBottomRight: 2
        }

        Rectangle {
            anchors.left: track.left
            anchors.top: track.top
            anchors.bottom: track.bottom
            anchors.margins: 2
            width: Math.max(0, (track.width - 4) * root._norm())
            color: CP.alpha(CP.yellow, 0.35)
        }

        Item {
            id: thumb
            width: 8
            height: 20
            x: (track.width - width) * root._norm()
            y: (track.height - height) / 2

            CutShape {
                anchors.fill: parent
                fillColor: ma.pressed ? CP.alpha(CP.yellow, 0.95) : CP.yellow
                strokeColor: "white"
                strokeWidth: 1
                inset: 0.5
                cutTopLeft: 2
                cutBottomRight: 2

                layer.enabled: ma.pressed
                layer.effect: null
            }
        }

        MouseArea {
            id: ma
            anchors.fill: track
            cursorShape: Qt.PointingHandCursor
            onPressed: function(mouse) { root._setFromX(mouse.x) }
            onPositionChanged: function(mouse) {
                if (pressed) root._setFromX(mouse.x)
            }
        }
    }
}
