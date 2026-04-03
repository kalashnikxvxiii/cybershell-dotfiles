// Tray.qml — System tray via Quickshell.Services.SystemTray

import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Io
import QtQuick
import "../../common/Colors.js" as CP
import "../../common"

Item {
    id: root
    
    property bool expanded: false
    property bool showBackground: true
    property var parentWindow
    property int buttonSize: 22
    property int trayGap: 2
    property int expandedContentWidth: pinnedRow.implicitWidth + 
                                    + (root.expanded ? (trayRow.implicitWidth + trayGap) : 0)
    
    implicitHeight: 24
    implicitWidth:  root.buttonSize
    width: root.buttonSize

    // Check if an item is pinned
    function isPinned(id) {
        return trayPins.pinnedIds.indexOf(id) !== -1
    }

    // Toggle pinned status for an item
    function togglePinned(id) {
        var ids = trayPins.pinnedIds || []
        var idx = ids.indexOf(id)
        if (idx === -1) 
            ids = ids.concat([id])
        else {
            ids = ids.slice()
            ids.splice(idx, 1)
        }
        trayPins.pinnedIds = ids
        trayPinsFile.writeAdapter()
    }

    FileView {
        id: trayPinsFile
        path: Qt.resolvedUrl("tray-pins.json")    // file JSON accanto a Tray.qml
        atomicWrites: true
        blockLoading: true

        adapter: JsonAdapter {
            id: trayPins
            // lista di id pinnati salvata nel JSON
            property var pinnedIds: []
        }
    }

    // Tray row with icons and expandable content
    Row {
        anchors.right: root.right
        spacing: 0

        // Tray pinned items
        Row {
            id: pinnedRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Item {
                width: 6    // spazio sx del primo pinned item
                height: parent.height
            }

            Repeater {
                model: SystemTray.items
                delegate: Item {
                    required property SystemTrayItem modelData
                    visible: root.isPinned(modelData.id)
                    implicitWidth: visible ? 16 : 0
                    implicitHeight: 16

                    Image {
                        anchors.fill: parent
                        source: modelData.icon
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        antialiasing: true
                        opacity: 1.0
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor

                        onClicked: mouse => {
                            // Click scroll = pin/unpin
                            if (mouse.button === Qt.MiddleButton) {
                                root.togglePinned(modelData.id)
                                return
                            }

                            // Comportamento normale
                            if (mouse.button === Qt.LeftButton && !modelData.onlyMenu) {
                                modelData.activate()
                            } else if (modelData.hasMenu) {
                                var win = root.parentWindow
                                if (!win) return
                                var toItem = win.contentItem !== undefined ? win.contentItem : root
                                var pos = mapToItem(toItem, 0, height)
                                modelData.display(win, Math.round(pos.x), Math.round(pos.y))
                            }
                        }
                    }
                }
            }
        }
        // Tray expandable content
        Item {
            id: trayExpandable
            width: root.expanded ? (trayRow.implicitWidth + 5 + trayGap) : 0
            height: root.height
            clip: true
            Behavior on width {
                Anim {}
            }

            // Tray row with icons
            Row {
                id: trayRow
                anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 10 }
                spacing: 6

                // Repeater for tray items
                Repeater {
                    model: SystemTray.items

                    delegate: Item {
                        id: trayItem
                        required property SystemTrayItem modelData

                        visible: !root.isPinned(modelData.id)
                        implicitWidth:  visible ? 16 : 0
                        implicitHeight: 16
                        anchors.verticalCenter: parent.verticalCenter

                        // Icona via QML Image con source dall'item
                        Image {
                            anchors.fill: parent
                            source:       trayItem.modelData.icon
                            sourceSize.width:  width
                            sourceSize.height: height
                            fillMode:     Image.PreserveAspectFit
                            smooth:       true
                            antialiasing: true
                            mipmap: true
                            // Dim passive icons
                            opacity: 1.0
                        }

                        // Mouse area for tray item
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor

                            onClicked: mouse => {
                                // Click scroll = pin/unpin
                                if (mouse.button === Qt.MiddleButton) {
                                    root.togglePinned(modelData.id)
                                    return
                                }

                                // Comportamento normale
                                if (mouse.button === Qt.LeftButton && !trayItem.modelData.onlyMenu) {
                                    trayItem.modelData.activate()
                                } else if (trayItem.modelData.hasMenu) {
                                    var win = root.parentWindow
                                    if (!win) return
                                    var toItem = win.contentItem !== undefined ? win.contentItem : root
                                    var pos = trayItem.mapToItem(toItem, 0, trayItem.height)
                                    trayItem.modelData.display(win, Math.round(pos.x), Math.round(pos.y))
                                }
                            }
                        }
                    }
                }

                Item {
                    width: 2    // spazio sx del primo pinned item
                    height: parent.height
                }
            }            
        }

        Item {
            width: root.expanded ? root.trayGap : 0
            height: root.height
            Behavior on width {
                Anim {}
            }
        }

        Item {
            width: root.buttonSize
            height: root.height

            Text {
                anchors.centerIn: parent
                text: root.expanded ? ">" : "<"
                font.family: "Oxanium"
                font.pixelSize: 12
                color: CP.cyan
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expanded = !root.expanded
            }
        }
    }
}
