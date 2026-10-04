// AiEffortRow.qml - the effort selector, shared by the mode and model menus.
//
// A filled run up to the chosen level rather than a free slider: these are named
// steps, not a continuum. Which steps exist depends on the model, so the row is
// handed its levels instead of assuming five
import QtQuick
import "../../common"
import "../../common/Colors.js" as CP

Item {
    id: root

    property var levels: []
    property string current: ""
    property bool enabled: true
    property color fg: "#d8e0e8"
    property string hovered: ""     // the level under the cursor, if any

    signal picked(string level)

    implicitHeight: 30
    height: implicitHeight
    opacity: root.enabled && root.levels.length > 0 ? 1 : 0.35
    Behavior on opacity { NumberAnimation { duration: 120 } }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Effort"
            font.family: "Oxanium"
            font.pixelSize: 12
            font.bold: true
            color: CP.alpha(root.fg, 0.80)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            // Nothing to show when the model has no effort levels at all
            text: root.levels.length === 0 ? "(not supported)"
                : "(" + (root.hovered !== "" ? root.hovered : root.current) + ")"
            font.family: "Oxanium"
            font.pixelSize: 11
            color: CP.alpha(root.fg, root.hovered !== "" ? 0.70 : 0.40)
            Behavior on color { ColorAnimation { duration: 110 } }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 13
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Repeater {
            model: root.levels

            delegate: Item {
                required property var modelData
                required property int index

                readonly property int pick: root.levels.indexOf(root.current)
                readonly property bool lit: index <= pick

                width: index === pick ? 18 : 9
                height: 9
                Behavior on width { NumberAnimation { duration: 140 } }

                Rectangle {
                    anchors.fill: parent
                    color: lit ? CP.alpha(CP.cyan, ma.containsMouse ? 0.95 : 0.75)
                        : CP.alpha(root.fg, ma.containsMouse ? 0.30 : 0.15)
                    Behavior on color { ColorAnimation { duration : 110 } }
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.enabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(modelData)
                    // The label above names what the cursor is over
                    onEntered: root.hovered = modelData
                    onExited: if (root.hovered === modelData) root.hovered = ""
                }
            }
        }
    }
}