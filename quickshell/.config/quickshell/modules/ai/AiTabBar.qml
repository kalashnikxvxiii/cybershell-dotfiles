// AiTabBar.qml - the open chats, one tab each, and "+" for another.
//
// Flat tabs, as in the editor's own tab strip: no frames, the front one is
// lit and underlined. The "+" rides at the end of the row, right after the
// last tab, not pinned to the edge. Past the drawer's width the row scrolls
// sideways under the wheel and keeps the front tab in view. Each tab carries
// a status light, so a reply streaming or a permission waiting in a tab
// behind is still visible
import QtQuick
import "../../common"
import "../../common/Colors.js" as CP

Item {
    id: root

    readonly property color fg: "#d8e0e8"
    readonly property color claude: "#d97757"

    implicitHeight: 26

    // The line the tabs stand on; the front tab's underline is drawn over it
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: CP.alpha(CP.magenta, 0.22)
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: row.width
        contentHeight: height
        // The wheel below does the scrolling: a drag on a tab is a click
        interactive: false
        clip: true

        function reveal(item) {
            if (!item) return
            if (item.x < contentX) contentX = item.x
            else if (item.x + item.width > contentX + width)
                contentX = item.x + item.width - width
        }

        Row {
            id: row
            height: parent.height
            spacing: 2

            Repeater {
                model: AiState.chats

                delegate: Item {
                    id: tab

                    required property var modelData

                    readonly property bool front: modelData === AiState.chat
                    readonly property bool busy: modelData.session.busy
                    readonly property bool asking: modelData.session.pendingPermission !== null

                    width: Math.min(160, Math.max(70, label.implicitWidth + 44))
                    height: row.height

                    onFrontChanged: if (front) Qt.callLater(flick.reveal, tab)

                    // Passive: still sees the pointer over the close button
                    HoverHandler { id: hover }

                    Rectangle {
                        anchors.fill: parent
                        anchors.bottomMargin: 1
                        color: CP.alpha(CP.magenta, tab.front ? 0.06 : hover.hovered ? 0.05 : 0)
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }

                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: 2
                        visible: tab.front
                        color: CP.magenta
                    }

                    // Red: a permission waits. Yellow, pulsing: a reply is
                    // coming in. Terracotta: idle
                    Rectangle {
                        id: light
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 5
                        height: 5
                        color: tab.asking ? CP.red : tab.busy ? CP.yellow
                            : CP.alpha(root.claude, tab.front ? 1 : 0.40)
                        opacity: lightPulse.k

                        QtObject { id: lightPulse; property real k: 1 }

                        SequentialAnimation {
                            running: tab.busy || tab.asking
                            loops: Animation.Infinite
                            onStopped: lightPulse.k = 1
                            PropertyAction { target: lightPulse; property: "k"; value: 0.25 }
                            PauseAnimation { duration: 450 }
                            PropertyAction { target: lightPulse; property: "k"; value: 1 }
                            PauseAnimation { duration: 450 }
                        }
                    }

                    Text {
                        id: label
                        anchors.left: light.right
                        anchors.leftMargin: 7
                        anchors.right: close.left
                        anchors.rightMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: tab.modelData.title !== "" ? tab.modelData.title : "NEW CHAT"
                        elide: Text.ElideRight
                        font.family: "Oxanium"
                        font.pixelSize: 11
                        font.letterSpacing: tab.modelData.title !== "" ? 0.3 : 2
                        color: tab.front ? root.fg
                            : CP.alpha(root.fg, hover.hovered ? 0.70 : 0.42)
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }

                    // Middle click closes too, as on any browser tab
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (mouse.button === Qt.MiddleButton) AiState.closeChat(tab.modelData)
                            else AiState.select(tab.modelData)
                        }
                    }

                    // Above the tab's own MouseArea, or the click would select
                    AiIconButton {
                        id: close
                        anchors.right: parent.right
                        anchors.rightMargin: 5
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14
                        height: 14
                        frame: false
                        glyph: "\uf00d"
                        glyphSize: 9
                        accent: CP.magenta
                        visible: tab.front || hover.hovered
                        onTriggered: AiState.closeChat(tab.modelData)
                    }
                }
            }

            AiIconButton {
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 22
                glyph: "\uf067"
                glyphSize: 10
                accent: CP.cyan
                frame: false
                onTriggered: AiState.newChat()
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const d = event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y
            const max = Math.max(0, flick.contentWidth - flick.width)
            flick.contentX = Math.max(0, Math.min(max, flick.contentX - d / 2))
        }
    }
}
