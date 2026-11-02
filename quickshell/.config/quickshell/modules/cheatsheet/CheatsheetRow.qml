// CheatsheetRow.qml -- one bind: name and keycaps on top, what it does below.
// Filtered-out rows dim in place, so the layout never jumps while searching.
pragma ComponentBehavior: Bound

import QtQuick
import "../../common/Colors.js" as CP

import "../../common"
Item {
    id: root

    required property var row
    property bool matched: true
    property bool searching: false
    property color accent: Theme.cyan
    // The bind already on the combination being captured
    property bool conflicted: false
    property bool clickable: false
    signal activated()

    opacity: matched || conflicted ? 1 : 0.16

    Rectangle {
        anchors.fill: parent
        color: root.conflicted ? CP.alpha(Theme.red, 0.28)
            : hover.containsMouse ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.12)
            : root.searching && root.matched ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.07)
            : "transparent"

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Rectangle {
        width: 2
        height: parent.height
        color: root.conflicted ? Theme.red : root.accent
        opacity: root.conflicted || hover.containsMouse ? 1 : root.searching && root.matched ? 0.6 : 0
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: root.clickable ? Qt.LeftButton : Qt.NoButton
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.activated()
    }

    Text {
        id: name
        x: 8
        anchors.verticalCenter: chips.verticalCenter
        width: chips.x - x - 8
        elide: Text.ElideRight
        text: root.row.name.toUpperCase()
        font.family: Theme.font
        font.pixelSize: 12
        font.bold: true
        font.letterSpacing: 1
        color: "#e8f2f4"
    }

    KeyChips {
        id: chips
        anchors.right: parent.right
        anchors.rightMargin: 4
        y: Math.max(1, (root.height - 34) / 2)
        mods: root.row.mods
        keys: root.row.keys
    }

    Text {
        x: 8
        anchors.top: chips.bottom
        anchors.topMargin: 2
        width: parent.width - 12
        elide: Text.ElideRight
        text: root.row.note
        font.family: Theme.font
        font.pixelSize: 11
        color: "#93a6aa"
    }
}
