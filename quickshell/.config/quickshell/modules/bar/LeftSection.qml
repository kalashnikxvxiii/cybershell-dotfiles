import QtQuick
import QtQuick.Effects
import "../../common/Colors.js" as CP
import "."
import "../../common"

Item {
    id: root
    property var barScreen

    implicitHeight: 24
    // Room on the right for the glow of the title's background
    implicitWidth: innerRow.implicitWidth + 12

    Row {
        id: innerRow
        height: parent.height
        spacing: 0

        Workspaces {
            barScreen: root.barScreen
            height:    innerRow.height
        }

        // Inside the section's layer, so it tilts with it and its edges get smoothed.
        // Shorter than the section: what touches the texture's border stays jagged
        Item {
            width: title.implicitWidth
            height: innerRow.height
            visible: false // title.title !== ""

            Item {
                anchors.centerIn: parent
                width: parent.width
                height: 20

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor:            Theme.cyan
                    shadowBlur:             0.75
                    shadowOpacity:          0.40
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset:   0
                }

                CutShape {
                    anchors.fill: parent
                    fillColor:    CP.moduleBg
                    strokeColor:  CP.alpha(Theme.cyan, 0.50)
                    strokeWidth:  1
                    inset:        0.5
                    cutBottomRight: 9
                }
            }

            WindowTitle {
                id: title
                height: parent.height
            }
        }
    }
}
