import QtQuick
import Quickshell
import "../../common/Colors.js" as CP
import "./DashboardConst.js" as DC
import "../../common"

// Tab bar with 3 tabs: CYBERDECK, MEDIA, CYBERWARE
// Adapted from Caelestia Tabs.qml: animated indicator + scroll wheel

Item {
    id: root

    required property PersistentProperties dashState

    readonly property int tabCount: 3

    implicitHeight: bar.height + indicator.height + indicator.anchors.topMargin + separator.height

    // Tab row
    Row {
        id: bar

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        Repeater {
            model: DC.tabLabels

            delegate: Item {
                id: tab
                width: bar.width / root.tabCount
                height: 26

                required property string modelData
                required property int index

                readonly property bool current: root.dashState.currentTab === index

                // Background hover/active
                Rectangle {
                    anchors.fill: parent
                    color: tab.current ? CP.alpha(CP.cyan, 0.10) : "transparent"
                    Behavior on color { CAnim { duration: 150 } }
                }

                Text {
                    anchors.centerIn: parent
                    text: tab.modelData
                    font.family: "Oxanium"
                    font.pixelSize: 10
                    font.letterSpacing: 1.2
                    color: tab.current ? CP.cyan : CP.alpha(CP.cyan, 0.45)
                    Behavior on color { CAnim { duration: 150 } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.dashState.currentTab = tab.index
                    onWheel: wheel => {
                        if (wheel.angleDelta.y < 0)
                            root.dashState.currentTab = Math.min(root.dashState.currentTab + 1, root.tabCount - 1)
                        else if (wheel.angleDelta.y > 0)
                            root.dashState.currentTab = Math.max(root.dashState.currentTab - 1, 0)
                    }
                }
            }
        }
    }

    // Sliding indicator under the active tab
    Rectangle {
        id: indicator
        anchors.top: bar.bottom
        anchors.topMargin: 3
        height: 2
        width: bar.width / root.tabCount
        color: CP.cyan
        x: root.dashState.currentTab * width

        Behavior on x {
            Anim { duration: 200 }
        }
    }

    // Separator
    Rectangle {
        id: separator
        anchors.top: indicator.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Colours.neonBorder(0.15)
    }
}
