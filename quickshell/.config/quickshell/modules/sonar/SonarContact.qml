// SonarContact.qml — one row in the Sonar panel's contact list.
//
// The list and the radar show the same entries: hovering either one highlights
// the other, so the row is deliberately thin and the eye can move between them.
import QtQuick
import "../../common/Colors.js" as CP
import "../../common"

Item {
    id: row

    required property string label
    property string meta: ""
    property color  accent: Colours.accentSecondary
    // 0..1 for Wi-Fi; -1 hides the meter (bluetooth has no signal figure).
    property real   strength: -1
    property bool   connected: false
    property bool   selected: false
    property bool   hovered: false
    property bool   busy: false

    signal clicked()
    signal entered()
    signal exited()

    implicitHeight: 24

    Rectangle {
        anchors.fill: parent
        color: row.selected ? CP.alpha(row.accent, 0.16)
             : row.hovered  ? CP.alpha(row.accent, 0.08)
                            : "transparent"
        Behavior on color { CAnim { duration: 120 } }
    }

    // Marker on the left: filled when connected, hollow otherwise.
    Rectangle {
        id: dot
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 5; height: 5
        color: row.connected ? Colours.accentOk : "transparent"
        border.color: row.connected ? Colours.accentOk : CP.alpha(row.accent, 0.6)
        border.width: 1

        // A pending connection blinks rather than spinning: the shell has no
        // spinners, and the blink reads at this size.
        SequentialAnimation on opacity {
            running: row.busy
            loops: Animation.Infinite
            NumberAnimation { to: 0.25; duration: 320 }
            NumberAnimation { to: 1; duration: 320 }
        }
        onOpacityChanged: if (!row.busy && opacity !== 1) opacity = 1
    }

    Text {
        id: name
        anchors.left: dot.right
        anchors.leftMargin: 8
        anchors.right: meterBox.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: row.label
        elide: Text.ElideRight
        font.family: "Oxanium"
        font.pixelSize: 11
        font.letterSpacing: 0.5
        color: row.connected ? Colours.accentOk
             : (row.selected || row.hovered) ? Colours.textPrimary
                                             : Colours.textSecondary
    }

    Item {
        id: meterBox
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: metaText.implicitWidth + (row.strength >= 0 ? 30 : 0)
        height: 12

        Text {
            id: metaText
            anchors.right: row.strength >= 0 ? bars.left : parent.right
            anchors.rightMargin: row.strength >= 0 ? 8 : 0
            anchors.verticalCenter: parent.verticalCenter
            text: row.meta
            font.family: "Chakra Petch"
            font.pixelSize: 9
            color: Colours.textMuted
        }

        // Four bars: the classic signal ladder, squared off like everything else.
        Row {
            id: bars
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: row.strength >= 0
            spacing: 2
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    width: 3
                    height: 3 + index * 3
                    anchors.bottom: parent ? parent.bottom : undefined
                    color: row.strength * 4 > index ? row.accent : CP.alpha(row.accent, 0.18)
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: row.entered()
        onExited: row.exited()
        onClicked: row.clicked()
    }
}
