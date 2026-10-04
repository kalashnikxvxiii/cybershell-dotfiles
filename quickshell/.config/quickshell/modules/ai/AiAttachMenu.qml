// AiAttachMenu.qml - the paths staged for the next message.
//
// A drop or the + picker lands a path here instead of in the prompt text: the
// list travels with the message and the model opens each entry with its own
// tools, so a message can carry paths and no words at all. Folders come back
// from the shell with a trailing slash, which is what picks their glyph.
// Five rows, then it scrolls
import QtQuick
import Quickshell
import "../../common"
import "../../common/Colors.js" as CP

Item {
    id: root

    property var paths: []
    
    signal removed(string path)
    signal cleared()

    readonly property color fg: "#d8e0e8"
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property int rowH: 22
    readonly property int headerH: 20
    readonly property int maxRows: 5

    // Computed from the model, not from the view: ListView anchored to this
    // item cannot also be what sizes it
    implicitHeight: root.paths.length === 0 ? 0
        : root.headerH + Math.min(root.maxRows, root.paths.length) * root.rowH + 6
    height: implicitHeight
    visible: root.paths.length > 0

    CutShape {
        anchors.fill: parent
        fillColor: CP.alpha(CP.void2, 0.97)
        strokeColor: CP.alpha(CP.magenta, 0.45)
        strokeWidth: 1
        inset: 0.5
        cutTopRight: 12
    }

    Item {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.topMargin: 2
        height: root.headerH

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "ATTACHED \u00b7 " + root.paths.length
            font.family: "Oxanium"
            font.pixelSize: 8
            font.letterSpacing: 2
            font.bold: true
            color: CP.alpha(root.fg, 0.38)
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 10         // clear of the cut corner
            anchors.verticalCenter: parent.verticalCenter
            text: "CLEAR"
            font.family: "Oxanium"
            font.pixelSize: 8
            font.letterSpacing: 2
            font.bold: true
            color: clearMa.containsMouse ? CP.red : CP.alpha(root.fg, 0.38)
            Behavior on color { ColorAnimation { duration: 120 } }

            MouseArea {
                id: clearMa
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.cleared()
            }
        }
    }

    ListView {
        id: view
        anchors { top: header.bottom; left: parent.left
            right: parent.right; bottom: parent.bottom }
        anchors.bottomMargin: 4
        clip: true
        model: root.paths
        boundsBehavior: Flickable.StopAtBounds
        // The newest path lands at the bottom: bring it into view
        onCountChanged: positionViewAtEnd()

        delegate: Item {
            id: row
            required property string modelData

            readonly property bool isDir: modelData.endsWith("/")

            width: view.width
            height: root.rowH

            // Passive, unlike a MouseArea: it stays hovered while the pointer
            // is over the remove button, so the button does not flicker away
            HoverHandler { id: rowHover }

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                color: CP.alpha(CP.cyan, rowHover.hovered ? 0.09 : 0)
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Text {
                id: glyph
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: row.isDir ? "\uf07b" : "\uf0f6"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                color: row.isDir ? CP.yellow : CP.cyan
            }

            Text {
                anchors.left: glyph.right
                anchors.leftMargin: 8
                anchors.right: remove.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                // The middle goes first: the name at the end is what tells
                // two paths apart
                text: root.home !== "" && row.modelData.startsWith(root.home)
                    ? "~" + row.modelData.slice(root.home.length) : row.modelData
                elide: Text.ElideMiddle
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                color: CP.alpha(root.fg, 0.82)
            }

            AiIconButton {
                id: remove
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                visible: rowHover.hovered
                frame: false
                glyph: "\uf00d"
                glyphSize: 10
                accent: CP.red
                onTriggered: root.removed(row.modelData)
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
}
