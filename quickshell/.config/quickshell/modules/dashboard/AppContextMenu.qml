// AppContextMenu.qml — Context menu for app launcher (Pin / Change Icon / Remove)

import QtQuick
import "../../common"
import "../../common/Colors.js" as CP

Item {
    id: ctxRoot

    // Parent must set these for position clamping
    required property real parentWidth
    required property real parentHeight

    // Signals to parent
    signal pinToggle(int index, bool currentlyPinned)
    signal removeApp(int index)
    signal editIcon(int index)

    // Transparent overlay — closes the context menu when clicking outside
    MouseArea {
        anchors.fill: parent
        visible: menu.visible
        z: 9
        onClicked: menu.visible = false
    }

    // Context menu
    Rectangle {
        id: menu
        visible: false
        z: 10
        width: 110
        height: menuCol.implicitHeight + 8
        color: Colours.moduleBg
        border.width: 1
        border.color: CP.alpha(CP.cyan, 0.45)
        radius: 4

        property int  targetIndex:  -1
        property bool targetPinned: false

        function open(idx, pinned, mx, my) {
            targetIndex  = idx
            targetPinned = pinned
            x = Math.min(mx, ctxRoot.parentWidth  - width  - 4)
            y = Math.min(my, ctxRoot.parentHeight - height - 4)
            visible = true
        }

        Column {
            id: menuCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 4 }
            spacing: 2

            // Pin / Unpin
            Rectangle {
                width: parent.width; height: 26; radius: 3
                color: pinHover.containsMouse ? CP.alpha(CP.cyan, 0.15) : "transparent"
                Behavior on color { CAnim {} }

                Text {
                    anchors.centerIn: parent
                    text: menu.targetPinned ? "Unpin" : "Pin"
                    font.family: "Oxanium"; font.pixelSize: 11
                    color: CP.cyan
                }
                MouseArea {
                    id: pinHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        ctxRoot.pinToggle(menu.targetIndex, menu.targetPinned)
                        menu.visible = false
                    }
                }
            }

            // Change Icon
            Rectangle {
                width: parent.width; height: 26; radius: 3
                color: changeIconHover.containsMouse ? CP.alpha(CP.cyan, 0.15) : "transparent"
                Behavior on color { CAnim {} }

                Text {
                    anchors.centerIn: parent
                    text: "Change Icon"
                    font.family: "Oxanium"; font.pixelSize: 11
                    color: CP.cyan
                }
                MouseArea {
                    id: changeIconHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        ctxRoot.editIcon(menu.targetIndex)
                        menu.visible = false
                    }
                }
            }

            // Remove
            Rectangle {
                width: parent.width; height: 26; radius: 3
                color: removeHover.containsMouse ? CP.alpha(CP.red, 0.12) : "transparent"
                Behavior on color { CAnim {} }

                Text {
                    anchors.centerIn: parent
                    text: "Remove"
                    font.family: "Oxanium"; font.pixelSize: 11
                    color: CP.red
                }
                MouseArea {
                    id: removeHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        ctxRoot.removeApp(menu.targetIndex)
                        menu.visible = false
                    }
                }
            }
        }
    }

    // Public API — delegates to the inner Rectangle
    function open(idx, pinned, mx, my) {
        menu.open(idx, pinned, mx, my)
    }

    // Lets the parent close the menu
    property alias visible_menu: menu.visible
    function close() { menu.visible = false }
}
