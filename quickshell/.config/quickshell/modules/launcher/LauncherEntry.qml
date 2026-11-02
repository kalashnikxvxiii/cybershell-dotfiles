// LauncherEntry.qml — one menu row, ported from
// AndreaNec/Cyberpunk-quickshell (launcher/LauncherEntry.qml).
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets
import "../../common/Colors.js" as CP
import "../../common"

Item {
    id: item
    required property var modelData
    required property int index
    required property var launcher

    readonly property ListView view: ListView.view
    readonly property bool current: ListView.isCurrentItem
    readonly property int distance: Math.abs(index - view.currentIndex)

    // The rows sit flush left; only the selected one sticks out to the right
    readonly property real reserve: 48
    readonly property real shift: current ? 24 : 0

    readonly property string subtitle: launcher.armedId === modelData.id ? "Select again to confirm" : (launcher.query !== "" && modelData.path) ? modelData.path : (modelData.comment || "")

    width: view.width
    height: view.rowHeight
    opacity: current ? 1 : Math.max(0.25, 1 - distance * 0.18)
    Behavior on opacity { NumberAnimation { duration: 120 } }

    Item {
        id: body
        x: item.shift
        width: parent.width - item.reserve    // constant width: the row translates, it doesn't shrink
        height: parent.height
        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        // Number badge
        CutShape {
            id: badge
            width: 26
            height: 26
            anchors.verticalCenter: parent.verticalCenter
            fillColor: "transparent"
            strokeWidth: 1.5
            strokeColor: Theme.cyan
            cutBottomLeft: 12
            Text {
                anchors.centerIn: parent
                text: item.index + 1
                color: Theme.cyan
                font.family: "Oxanium"
                font.bold: true
                font.pixelSize: 12
            }
        }

        // Row box: outline + content as siblings
        Item {
            anchors.left: badge.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 2
            anchors.bottomMargin: 2

            // Quickhack frame: cut top right, bevelled step on the left edge
            Shape {
                id: frame
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: item.current ? 2 : 1
                    strokeColor: item.current ? Theme.cyan : CP.alpha(Theme.cyan, 0.5)
                    fillColor: item.current ? CP.alpha(Theme.cyan, 0.15) : "transparent"
                    joinStyle: ShapePath.MiterJoin
                    PathPolyline {
                        path: {
                            const i = 1, r = frame.width - i, b = frame.height - i
                            return [
                                Qt.point(i, i), Qt.point(r - 6, i), Qt.point(r, i + 6), Qt.point(r, b),
                                Qt.point(i + 4, b), Qt.point(i + 4, b - 20), Qt.point(i, b - 24), Qt.point(i, i)
                            ]
                        }
                    }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10

                // Icon: nerd-font glyph for system entries, theme icon for apps
                Item {
                    implicitWidth: 24
                    implicitHeight: 24

                    IconImage {
                        anchors.fill: parent
                        visible: !item.modelData.glyph
                        source: Quickshell.iconPath(item.modelData.iconName || "", true) || Quickshell.iconPath("application-x-executable", true)
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !!item.modelData.glyph
                        text: item.modelData.glyph || ""
                        color: Theme.cyan
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 18
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: item.modelData.name
                        color: item.current ? CP.white : "#aab4c8"
                        font.family: "Oxanium"
                        font.bold: true
                        font.pixelSize: 14
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        visible: text !== ""
                        text: item.subtitle
                        color: CP.alpha(Theme.cyan, 0.7)
                        font.family: "Oxanium"
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Chevron for submenus
                Text {
                    visible: !!item.modelData.children
                    text: ""
                    color: Theme.cyan
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        // onPositionChanged, not onEntered: the list scrolls under a still cursor
        onPositionChanged: item.view.currentIndex = item.index
        onClicked: item.launcher.activate(item.modelData)
    }
}
