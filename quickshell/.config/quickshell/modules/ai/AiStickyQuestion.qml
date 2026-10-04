// AiStickyQuestion.qml - the question being answered, held at the top of the
// transcript once its card has scrolled out of sight.
//
// The answer under it can be long; without this the reader loses what was
// asked. The next question pushes it out as it arrives, the way section
// headers hand over. A click scrolls back to the full card; a long one can
// also be unfolded in place, up to part of the transcript, and scrolled there.
import QtQuick
import "../../common"
import "../../common/Colors.js" as CP

Item {
    id: root

    required property ListView view
    required property var rows

    // Taller cards are cut here and fade out
    readonly property int maxHeight: 76
    // Unfolded, it may cover this much of the transcript and scrolls past it
    readonly property real openHeight: Math.min(msg.height, root.view.height * 0.6)

    readonly property bool cut: msg.height > root.maxHeight
    property bool expanded: false

    property int index: -1
    // Top of the next question, in view coordinates; it pushes this one up
    property real nextTop: Infinity

    readonly property var row: index >= 0 && index < rows.length ? rows[index] : null

    // Another question is another card: it starts folded
    onIndexChanged: root.expanded = false

    height: card.height
    visible: row !== null
    clip: true

    // The rows are all built (cacheBuffer), so every card has a real position.
    // The pinned question is the last one whose top is above the view
    function update() {
        const top = root.view.contentY
        let cur = -1
        let next = Infinity
        for (let i = 0; i < root.view.count; i++) {
            if (root.rows[i]?.role !== "user") continue
            const it = root.view.itemAtIndex(i)
            if (!it) continue
            if (it.y < top - 1) cur = i
            else { next = it.y - top; break }
        }
        root.index = cur
        root.nextTop = next
    }

    Connections {
        target: root.view
        function onContentYChanged() { root.update() }
        function onContentHeightChanged() { Qt.callLater(root.update) }
        function onCountChanged() { Qt.callLater(root.update) }
    }

    Item {
        id: card
        width: root.width
        height: root.expanded ? root.openHeight : Math.min(msg.height, root.maxHeight)
        // Handed over: the next question pushes this one out from below
        y: Math.min(0, root.nextTop - height - root.view.spacing / 2)

        // Opaque: the transcript scrolls under it
        CutShape {
            anchors.fill: parent
            fillColor: CP.void2
            cutTopLeft: 5
            cutBottomRight: 5
        }

        Flickable {
            id: flick
            anchors.fill: parent
            contentWidth: width
            contentHeight: msg.height
            // Folded, it only shows the top of the card
            interactive: root.expanded && contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Connections {
                target: root
                function onExpandedChanged() { if (!root.expanded) flick.contentY = 0 }
            }

            AiMessage {
                id: msg
                width: card.width
                role: "user"
                parts: root.row?.parts ?? []
            }

            // Inside the content: the Flickable takes drags and the wheel,
            // a click still reaches this
            MouseArea {
                width: flick.width
                height: msg.height
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.view.pinned = false
                    root.view.positionViewAtIndex(root.index, ListView.Beginning)
                }
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 3
            width: 2
            visible: flick.interactive
            y: flick.visibleArea.yPosition * flick.height
            height: Math.max(18, flick.visibleArea.heightRatio * flick.height)
            color: CP.alpha(CP.cyan, flick.moving ? 0.55 : 0.25)
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        // Whatever is still below the edge fades out
        Rectangle {
            visible: root.cut && !(root.expanded && flick.atYEnd)
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            anchors.margins: 1
            height: 26
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: CP.void2 }
            }
        }

        // The card's own frame is cut off with it: drawn again at this size
        CutShape {
            anchors.fill: parent
            strokeColor: CP.alpha(CP.cyan, hover.hovered ? 0.5 : 0.28)
            strokeWidth: 1
            inset: 0.5
            cutTopLeft: 5
            cutBottomRight: 5
        }

        // On the card, not on one child: it stays true over the button
        HoverHandler { id: hover }

        // Only a card that is cut has more to show
        Item {
            id: more
            visible: root.cut && hover.hovered
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 4
            width: moreLabel.implicitWidth + 16
            height: 16

            CutShape {
                anchors.fill: parent
                fillColor: CP.alpha(CP.void2, 0.95)
                strokeColor: CP.alpha(CP.cyan, moreMa.containsMouse ? 0.8 : 0.45)
                strokeWidth: 1
                inset: 0.5
                cutTopLeft: 4
                Behavior on strokeColor { ColorAnimation { duration: 100 } }
            }

            Text {
                id: moreLabel
                anchors.centerIn: parent
                text: root.expanded ? "SHOW LESS" : "SHOW MORE"
                font.family: "Oxanium"
                font.pixelSize: 8
                font.letterSpacing: 1.5
                font.bold: true
                color: moreMa.containsMouse ? CP.cyan : CP.alpha(CP.cyan, 0.75)
                Behavior on color { ColorAnimation { duration: 100 } }
            }

            MouseArea {
                id: moreMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expanded = !root.expanded
            }
        }
    }
}
