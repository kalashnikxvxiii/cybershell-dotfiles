// MessagesPanel.qml -- the game's phone view. MESSAGES is the history: left click opens a message
// (its default action, or the whole text), right click or the X dismisses it. CONTACTS lists the
// apps that wrote: their messages, clear them, launch the app. Esc closes.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../../common"
import "../../common/effects"

Scope {
    id: root

    required property var screen

    readonly property bool shown: NotifState.panelOpen && NotifState.panelScreen === root.screen.name
    property int tab: 0
    property bool unreadOnly: false
    property string appFilter: ""
    // The message whose whole text is showing
    property int expanded: -1
    property var hovered: null

    readonly property var messages: NotifState.history.filter(n =>
        (!root.unreadOnly || !NotifState.read[n.id]) && (root.appFilter === "" || n.appName === root.appFilter))
    readonly property var contacts: [...new Set(NotifState.history.map(n => n.appName))]
        .sort((a, b) => a.localeCompare(b))

    onShownChanged: {
        if (!shown)
            return
        tab = 0
        unreadOnly = false
        appFilter = ""
        expanded = -1
        hovered = null
        keys.forceActiveFocus()
    }

    PanelWindow {
        screen: root.screen
        visible: root.shown || fx.visible
        color: "transparent"
        anchors { top: true; left: true }
        margins { top: 110; left: 24 }
        implicitWidth: 530
        implicitHeight: 700
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-messages"
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        GlitchReveal {
            id: fx
            anchors.fill: parent
            shown: root.shown

            Item {
                id: plate
                anchors.fill: parent
                transform: Tilt { w: plate.width; h: plate.height; yaw: 16; pitch: 2; roll: 0.5; focal: 2100 }
                layer.enabled: true
                layer.smooth: true
                layer.textureSize: Qt.size(width * 2, height * 2)

                // A blood-dark veil that fades out on every side, no panel edge
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 14
                    color: Qt.rgba(0.07, 0, 0.012, 0.86)
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        autoPaddingEnabled: true
                        blurEnabled: true
                        blur: 1
                        blurMax: 48
                    }
                }

                Item {
                    id: keys
                    focus: true
                    Keys.onEscapePressed: NotifState.togglePanel()
                }

                // Phone with its signal bars
                Column {
                    x: 16
                    y: 26
                    spacing: 2
                    Repeater {
                        model: 3
                        Rectangle {
                            width: 12
                            height: 2
                            color: HudState.alpha(HudState.danger, 0.6)
                        }
                    }
                    Text {
                        text: ""
                        color: HudState.tech
                        font { family: HudState.icons; pixelSize: 30 }
                    }
                }

                // Shard stack: the one in front shows whoever is under the pointer
                ContactShard {
                    x: 66
                    y: 2
                    ghost: true
                    opacity: 0.2
                }
                ContactShard {
                    x: 57
                    y: 11
                    ghost: true
                    opacity: 0.45
                }
                ContactShard {
                    x: 48
                    y: 20
                    picture: NotifState.picture(root.hovered)
                }

                // Tabs, with a faint rule running on past them
                Rectangle {
                    x: 100
                    y: 78
                    width: 400
                    height: 1
                    color: HudState.alpha(HudState.danger, 0.3)
                }
                Row {
                    x: 100
                    y: 44
                    spacing: 6
                    Tab {
                        index: 0
                        glyph: ""
                        label: "MESSAGES"
                    }
                    Tab {
                        index: 1
                        glyph: ""
                        label: "CONTACTS"
                    }
                }

                Flickable {
                    id: flick
                    x: 100
                    y: 92
                    width: 400
                    height: parent.height - 92 - 66
                    clip: true
                    contentHeight: root.tab === 0 ? messageList.implicitHeight : contactList.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: messageList
                        width: flick.width
                        visible: root.tab === 0
                        Repeater {
                            model: root.messages
                            MessageRow {}
                        }
                    }
                    Column {
                        id: contactList
                        width: flick.width
                        visible: root.tab === 1
                        Repeater {
                            model: root.contacts
                            ContactRow {}
                        }
                    }
                }

                Text {
                    anchors.centerIn: flick
                    visible: flick.contentHeight === 0
                    text: root.tab === 0 ? "NO MESSAGES" : "NO CONTACTS"
                    color: HudState.alpha(HudState.paper, 0.45)
                    font { family: HudState.font; pixelSize: 15; letterSpacing: 1 }
                }

                // Scrollbar: a faint track, the thumb in red
                Rectangle {
                    x: 508
                    y: flick.y
                    width: 1
                    height: flick.height
                    color: HudState.alpha(HudState.paper, 0.14)
                }
                Rectangle {
                    x: 507
                    visible: flick.contentHeight > flick.height
                    y: flick.y + flick.visibleArea.yPosition * flick.height
                    width: 3
                    height: flick.visibleArea.heightRatio * flick.height
                    color: HudState.danger
                }

                Rectangle {
                    x: 100
                    y: parent.height - 58
                    width: 410
                    height: 1
                    color: HudState.danger
                }

                Row {
                    x: 100
                    y: parent.height - 46
                    spacing: 16
                    Hint {
                        visible: root.appFilter !== ""
                        label: "ALL APPS"
                        onClicked: root.appFilter = ""
                    }
                    Hint {
                        label: root.unreadOnly ? "SHOW ALL" : "SHOW UNREAD"
                        onClicked: root.unreadOnly = !root.unreadOnly
                    }
                    Hint {
                        label: "CLEAR ALL"
                        onClicked: NotifState.clear()
                    }
                    Hint {
                        label: "DND " + (NotifState.quiet ? "ON" : "OFF")
                        onClicked: NotifState.toggleDnd()
                    }
                }
                Hint {
                    x: 510 - width
                    y: parent.height - 46
                    label: "CLOSE"
                    onClicked: NotifState.togglePanel()
                }
            }
        }
    }

    component Tab: Item {
        id: tabItem
        required property int index
        required property string glyph
        required property string label
        readonly property bool active: root.tab === index
        readonly property color tone: active ? HudState.tech : HudState.danger
        width: tabRow.implicitWidth + 16
        height: 34

        Row {
            id: tabRow
            x: 4
            spacing: 7
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: tabItem.glyph
                color: tabItem.tone
                font { family: HudState.icons; pixelSize: 15 }
            }
            Text {
                text: tabItem.label
                color: tabItem.tone
                font { family: HudState.font; pixelSize: 17; letterSpacing: 1 }
            }
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 2
            color: tabItem.tone
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.tab = tabItem.index
                flick.contentY = 0
            }
        }
    }

    component MessageRow: MouseArea {
        id: message
        required property var modelData
        readonly property bool selected: containsMouse
        readonly property bool unread: !NotifState.read[modelData.id]
        readonly property bool open: root.expanded === modelData.id
        width: messageList.width
        height: Math.max(64, subject.y + subject.implicitHeight + 11)
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: if (containsMouse) root.hovered = modelData
        onClicked: e => {
            if (e.button === Qt.RightButton) {
                modelData.dismiss()
                return
            }
            root.expanded = open ? -1 : modelData.id
            NotifState.open(modelData)
        }

        Rectangle {
            x: 12
            anchors.bottom: parent.bottom
            width: parent.width - 24
            height: 1
            color: HudState.alpha(HudState.paper, 0.07)
        }
        CutShape {
            anchors.fill: parent
            visible: message.selected
            cutTopLeft: 9
            cutBottomRight: 9
            fillColor: HudState.alpha(HudState.paper, 0.1)
            strokeColor: HudState.alpha(HudState.paper, 0.6)
            strokeWidth: 1.5
            inset: 0.75
        }
        Text {
            id: sender
            x: 12
            y: 10
            width: parent.width - 80
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: message.modelData.summary.toUpperCase()
            color: message.selected ? HudState.paper
                : message.unread ? HudState.tech : HudState.alpha(HudState.paper, 0.6)
            font { family: HudState.font; pixelSize: 16; letterSpacing: 1 }
        }
        Text {
            id: subject
            x: 12
            y: 33
            width: parent.width - 60
            textFormat: Text.PlainText
            text: message.modelData.body || message.modelData.appName
            wrapMode: message.open ? Text.WrapAtWordBoundaryOrAnywhere : Text.NoWrap
            maximumLineCount: message.open ? 12 : 1
            elide: Text.ElideRight
            color: message.selected || message.unread ? HudState.paper : HudState.alpha(HudState.paper, 0.42)
            font { family: HudState.font; pixelSize: 13 }
        }
        // Dismiss when selected, else the unread mark or the time
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12
            y: 12
            visible: !message.selected
            text: message.unread ? "" : Qt.formatTime(NotifState.times[message.modelData.id] ?? new Date(), "HH:mm")
            color: message.unread ? HudState.ok : HudState.alpha(HudState.paper, 0.42)
            font { family: message.unread ? HudState.icons : HudState.font; pixelSize: 13 }
        }
        Glyph {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            visible: message.selected
            glyph: ""
            tone: HudState.paper
            onClicked: message.modelData.dismiss()
        }
    }

    component ContactRow: MouseArea {
        id: contact
        required property string modelData
        readonly property bool selected: containsMouse
        readonly property var entry: DesktopEntries.heuristicLookup(modelData)
        width: contactList.width
        height: 48
        hoverEnabled: true

        Rectangle {
            x: 40
            anchors.bottom: parent.bottom
            width: parent.width - 52
            height: 1
            color: HudState.alpha(HudState.paper, 0.07)
        }
        CutShape {
            anchors.fill: parent
            visible: contact.selected
            cutBottomRight: 9
            fillColor: HudState.alpha(HudState.tech, 0.24)
            strokeColor: HudState.tech
            inset: 0.5
        }
        Text {
            x: 13
            anchors.verticalCenter: parent.verticalCenter
            visible: contact.selected
            text: ""
            color: HudState.tech
            font { family: HudState.icons; pixelSize: 15 }
        }
        Text {
            x: 40
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 170
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: contact.modelData.toUpperCase()
            color: contact.selected ? HudState.tech : HudState.alpha(HudState.tech, 0.72)
            font { family: HudState.font; pixelSize: 16; letterSpacing: 1 }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            visible: contact.selected
            Glyph {
                glyph: ""
                onClicked: {
                    root.appFilter = contact.modelData
                    root.tab = 0
                    flick.contentY = 0
                }
            }
            Glyph {
                glyph: ""
                onClicked: {
                    for (const n of NotifState.history)
                        if (n.appName === contact.modelData)
                            n.dismiss()
                }
            }
            Glyph {
                visible: contact.entry !== null
                glyph: ""
                onClicked: {
                    contact.entry.execute()
                    NotifState.togglePanel()
                }
            }
        }
    }

    component Glyph: Text {
        id: glyphItem
        property string glyph
        property color tone: HudState.tech
        signal clicked()
        text: glyph
        color: tone
        font { family: HudState.icons; pixelSize: 18 }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -3
            cursorShape: Qt.PointingHandCursor
            onClicked: glyphItem.clicked()
        }
    }

    component Hint: Item {
        id: hint
        property string label
        signal clicked()
        width: ring.width + 6 + hintText.implicitWidth
        height: 18

        Rectangle {
            id: ring
            anchors.verticalCenter: parent.verticalCenter
            width: 15
            height: 15
            radius: 7.5
            color: HudState.alpha(HudState.tech, 0.25)
            border { color: HudState.tech; width: 2 }
        }
        Text {
            id: hintText
            anchors.left: ring.right
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: hint.label
            color: hintHit.containsMouse ? HudState.paper : HudState.danger
            font { family: HudState.font; pixelSize: 11; bold: true; letterSpacing: 1 }
        }
        MouseArea {
            id: hintHit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: hint.clicked()
        }
    }
}
