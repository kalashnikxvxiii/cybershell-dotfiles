// AiTodoCard.qml - the model's checklist (TodoWrite), over the composer.
//
// The tool sends the whole list every time, so the card shows the last one.
// It goes away once every item is done; the header folds it
import QtQuick
import "../../common"
import "../../common/Colors.js" as CP

Item {
    id: root

    property var todos: []
    property bool expanded: true

    readonly property color fg: "#d8e0e8"
    readonly property int done: root.todos.filter(t => t.status === "completed").length
    readonly property bool shown: root.todos.length > 0 && root.done < root.todos.length

    visible: root.shown
    implicitHeight: root.shown
        ? 20 + head.height + (root.expanded ? 6 + list.height : 0) : 0
    height: implicitHeight

    CutShape {
        anchors.fill: parent
        fillColor: CP.alpha(CP.void2, 0.92)
        strokeColor: CP.alpha(CP.cyan, 0.35)
        strokeWidth: 1
        inset: 0.5
        cutTopRight: 8
    }

    Item {
        id: head
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.margins: 10
        height: 14

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "\u25e2 TASKS"
            font.family: "Oxanium"
            font.pixelSize: 10
            font.letterSpacing: 2
            font.bold: true
            color: CP.cyan
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.done + "/" + root.todos.length + (root.expanded ? "  \u25b4" : "  \u25be")
            font.family: "Oxanium"
            font.pixelSize: 9
            font.letterSpacing: 1
            color: CP.alpha(root.fg, 0.5)
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    Flickable {
        id: list
        anchors { top: head.bottom; left: parent.left; right: parent.right }
        anchors.topMargin: 6
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        visible: root.expanded
        height: Math.min(col.implicitHeight, 150)
        contentHeight: col.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: col
            width: list.width
            spacing: 4

            Repeater {
                model: root.todos

                Item {
                    required property var modelData
                    readonly property bool active: modelData.status === "in_progress"
                    readonly property bool finished: modelData.status === "completed"

                    width: col.width
                    height: label.implicitHeight

                    // Same diamond as the transcript: full when it is the
                    // step being worked on, hollow while it waits
                    Rectangle {
                        x: 1
                        y: 5
                        width: 5
                        height: 5
                        rotation: 45
                        color: finished ? CP.alpha(CP.neon, 0.5)
                            : active ? CP.cyan : "transparent"
                        border.width: 1
                        border.color: finished ? CP.alpha(CP.neon, 0.5)
                            : CP.alpha(CP.cyan, active ? 1 : 0.5)
                    }

                    Text {
                        id: label
                        x: 14
                        width: parent.width - 14
                        text: active ? (modelData.activeForm || modelData.content)
                            : modelData.content
                        wrapMode: Text.Wrap
                        font.family: "Oxanium"
                        font.pixelSize: 10
                        font.strikeout: finished
                        color: CP.alpha(root.fg, finished ? 0.35 : active ? 1 : 0.65)
                    }
                }
            }
        }
    }
}
