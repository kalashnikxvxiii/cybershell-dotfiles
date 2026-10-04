// AiModelMenu.qml - the model picker.
//
// The catalog is whatever the session reported in its `initialize` response:
// twelve entries here, each with the name and the one line Claude itself uses to
// describe it. Nothing is hardcoded, so a new model appears without an edit.
// Effort sits pinned at the bottom because it qualifies the model above it.
import QtQuick
import "../../common"
import "../../common/Colors.js" as CP

Item {
    id: root

    property var catalog: []
    property string currentModel: ""
    property var effortLevels: []
    property string currentEffort: ""
    property bool enabled: true

    signal modelPicked(string value)
    signal effortPicked(string level)
    signal dismissed()

    readonly property color fg: "#d8e0e8"
    readonly property int rowH: 42
    readonly property int headerH: 22

    implicitWidth: 320
    implicitHeight: root.headerH + Math.min(252, root.catalog.length * root.rowH)
        + 1 + effortRow.height + 10
    width: implicitWidth
    height: implicitHeight

    CutShape {
        anchors.fill: parent
        fillColor: CP.alpha(CP.void2, 0.97)
        strokeColor: CP.alpha(CP.magenta, 0.45)
        strokeWidth: 1
        inset: 0.5
        cutTopRight: 24
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) { root.dismissed(); event.accepted = true }
    }

    Item {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.topMargin: 6
        height: root.headerH

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "SELECT A MODEL"
            font.family: "Oxanium"
            font.pixelSize: 8
            font.letterSpacing: 2
            font.bold: true
            color: CP.alpha(root.fg, 0.38)
        }
    }

    ListView {
        id: view
        anchors { top: header.bottom; left: parent.left
                  right: parent.right; bottom: rule.top }
        anchors.bottomMargin: 4
        clip: true
        model: root.catalog
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: -1

        delegate: Item {
            required property var modelData
            required property int index

            readonly property bool active: modelData.value === root.currentModel
            // The entry the CLI marks as the session default reads as a
            // recommendation, so it carries the accent the others do not
            readonly property color accent:
                modelData.value === "default" ? CP.neon : CP.magenta

            width: view.width
            height: root.rowH

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                color: CP.alpha(accent, ma.containsMouse ? 0.11 : (active ? 0.07 : 0))
                Behavior on color { ColorAnimation { duration: 110 } }
            }

            Rectangle {
                visible: active
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                anchors.leftMargin: 4
                width: 2
                color: accent
            }

            Text {
                id: title
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.right: check.left
                anchors.rightMargin: 8
                anchors.top: parent.top
                anchors.topMargin: 6
                text: modelData.displayName ?? modelData.value
                elide: Text.ElideRight
                font.family: "Oxanium"
                font.pixelSize: 12
                font.bold: true
                color: active ? root.fg : CP.alpha(root.fg, 0.82)
            }

            Text {
                anchors.left: title.left
                anchors.right: check.left
                anchors.rightMargin: 8
                anchors.top: title.bottom
                anchors.topMargin: 1
                text: modelData.description ?? ""
                elide: Text.ElideRight
                font.family: "Oxanium"
                font.pixelSize: 9
                color: CP.alpha(root.fg, 0.40)
            }

            Text {
                id: check
                anchors.right: parent.right
                anchors.rightMargin: 13
                anchors.verticalCenter: parent.verticalCenter
                visible: active
                text: "\u2713"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: accent
            }

            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.enabled && !(modelData.disabled === true)
                cursorShape: Qt.PointingHandCursor
                onClicked: root.modelPicked(modelData.value)
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 3
            width: 2
            visible: view.contentHeight > view.height
            y: view.visibleArea.yPosition * view.height
            height: Math.max(18, view.visibleArea.heightRatio * view.height)
            color: CP.alpha(CP.magenta, view.moving ? 0.55 : 0.25)
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    Rectangle {
        id: rule
        anchors { left: parent.left; right: parent.right; bottom: effortRow.top }
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        height: 1
        color: CP.alpha(CP.magenta, 0.20)
    }

    AiEffortRow {
        id: effortRow
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        anchors.bottomMargin: 4
        levels: root.effortLevels
        current: root.currentEffort
        enabled: root.enabled
        fg: root.fg
        onPicked: l => root.effortPicked(l)
    }
}
