import QtQuick
import QtQuick.Effects
import "../../common/Colors.js" as CP
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
        // Sfondo
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

        // Monitor Secondario
        Clock {
            id: clockItem
            height: innerRow.height
            visible: !BarConfig.isPrimary(root.barScreen)
        }

        // Monitor Primario
        Item {
            id: mprisWithCava
            height: innerRow.height
            width: mpris.implicitWidth + 24
            visible: BarConfig.isPrimary(root.barScreen)

            MprisModule {
                id: mpris
                anchors.fill: parent
                anchors.margins: 6
                height: parent.height
                showBackground: false
            }

            // Cava come layer di sfondo (solo barre, senza background)
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

    // Bordo
    CutShape {
        anchors.fill: parent
        strokeColor: CP.alpha(CP.yellow, 0.35)
        strokeWidth: 1
        inset: 0.5
        cutBottomRight: 8
        cutBottomLeft: 8
    }
}
