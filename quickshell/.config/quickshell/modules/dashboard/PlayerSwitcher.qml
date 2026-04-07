// PlayerSwitcher.qml - toggle verticale Spotify / Browser
import QtQuick
import "../../common/Colors.js" as CP
import "../../common"

Item {
    id: root

    implicitWidth: 22
    implicitHeight: 50

    readonly property bool isSpotify: Players.isSpotifyActive

    // Background
    Rectangle {
        anchors.fill: parent
        color: CP.alpha(CP.black, 0.32)
        // border.color: CP.alpha(CP.yellow, 0.55)
        // border.width: 1
    }

    // Active slot indicator
    Rectangle {
        y: root.isSpotify ? 0 : root.height / 2
        width: parent.width
        height: parent.height / 2
        color: CP.alpha(CP.yellow, 0.20)
        Behavior on y { NumberAnimation{ duration: 160; easing.type: Easing.OutCubic } }
    }

    // Center divider
    Rectangle {
        y: parent.height / 2
        width: parent.width
        height: 1
        color: CP.alpha(CP.yellow, 0.28)
    }

    // Label Spotify (top)
    Text {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        height: parent.height / 2
        verticalAlignment: Text.AlignVCenter
        text: "\uf1bc"
        font.family: "Oxanium"
        font.pixelSize: 24
        font.weight: Font.Bold
        color: root.isSpotify ? CP.neon : CP.alpha(CP.white, 0.32)
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    // Label Browser (bottom)
    Text {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        height: parent.height / 2
        verticalAlignment: Text.AlignVCenter
        text: "\ueb01"
        font.family: "Oxanium"
        font.pixelSize: 24
        font.weight: Font.Bold
        color: !root.isSpotify ? CP.neon : CP.alpha(CP.white, 0.32)
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Players.togglePlayer()
    }
}