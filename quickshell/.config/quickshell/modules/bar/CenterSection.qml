import QtQuick
import QtQuick.Effects
import "../../common/Colors.js" as CP
import "../../common/BarConfig.js" as BC
import "."
import "../../common"

Item {
    id: root

    property var barScreen

    implicitHeight: 24
    implicitWidth: innerRow.implicitWidth

    Item {
        id: bgItem
        anchors.fill: parent

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor:            CP.yellow
            shadowBlur:             0.75
            shadowOpacity:          0.40
            shadowHorizontalOffset: 0
            shadowVerticalOffset:   0
        }
        // Background
        CutShape {
            anchors.fill: parent
            fillColor: CP.moduleBg
            cutBottomRight: 8
            cutBottomLeft: 8
        }
    }

    Row {
        id: innerRow
        height: parent.height
        spacing: 6

        // Secondary monitor
        Clock {
            id: clockItem
            height: innerRow.height
            visible: !BC.isPrimary(root.barScreen)
        }

        // Primary monitor
        Item {
            id: mprisWithCava
            height: innerRow.height
            width: mpris.implicitWidth + 24
            visible: BC.isPrimary(root.barScreen)

            MprisModule {
                id: mpris
                anchors.fill: parent
                anchors.margins: 6
                height: parent.height
                showBackground: false
            }

            // Cava as background layer (bars only, no background fill)
            CavaModule {
                id: cavaVis
                anchors.fill: parent
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.topMargin: 1
                anchors.bottomMargin: 8
                anchors.leftMargin: 1
                height: parent.height
                showBackground: false

                opacity: (Players.active?.isPlaying ?? false) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 1200 } }

                transform: Scale {
                    yScale: -1
                    origin.y: cavaVis.height / 2
                }
            }
        }
    }

    // Border
    CutShape {
        anchors.fill: parent
        strokeColor: CP.alpha(CP.yellow, 0.35)
        strokeWidth: 1
        inset: 0.5
        cutBottomRight: 8
        cutBottomLeft: 8
    }
}
