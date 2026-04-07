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

    // ── Background with diagonal cut + MultiEffect glow ────────────────────
    Item {
        id: bgItem
        anchors.fill: parent

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor:            CP.cyan
            shadowBlur:             0.75
            shadowOpacity:          0.40
            shadowHorizontalOffset: 0
            shadowVerticalOffset:   0
        }

        CutShape {
            anchors.fill: parent
            fillColor:    CP.moduleBg
            strokeColor:  CP.alpha(CP.cyan, 0.50)
            strokeWidth:  1
            inset:        0.5
            radiusTopLeft:    4
            radiusBottomLeft: 4
            cutBottomRight:   8
        }
    }

    Row {
        id: innerRow
        height: parent.height
        spacing: 0

        Workspaces {
            barScreen: root.barScreen
            height:    innerRow.height
        }

        WindowTitle {
            height: innerRow.height
        }
    }
}
