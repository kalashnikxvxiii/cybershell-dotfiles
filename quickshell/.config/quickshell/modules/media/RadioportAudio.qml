// RadioportAudio.qml -- the audio control's OUT / IN / APPS beside the Radioport: the popup's
// own tabs, in the Radioport's palette. A tab exists only while on screen, so that nothing
// captures audio with the panel closed.
import QtQuick
import "../../common/Colors.js" as CP
import "../../common"
import "../bar/AudioControl/tabs" as Tabs

Item {
    id: root

    property bool active: false
    property int tab: 0

    readonly property var tabs: ["OUT", "IN", "APPS"]

    implicitWidth: 410

    RadioportHeader {
        width: parent.width
        code: "AUD_ROUTE_IO"
        title: "AUDIO CONTROL"
    }

    Row {
        id: tabBar
        y: 62
        width: parent.width
        spacing: 4

        Repeater {
            model: root.tabs

            Item {
                id: chip
                required property string modelData
                required property int index
                readonly property bool current: root.tab === index

                width: (tabBar.width - 8) / 3
                height: 32

                CutShape {
                    anchors.fill: parent
                    cutBottomRight: 8
                    fillColor: chip.current ? CP.alpha(Theme.cyan, 0.16)
                        : hit.containsMouse ? CP.alpha(Theme.cyan, 0.08) : Qt.rgba(0.07, 0.02, 0.05, 0.75)
                    strokeColor: chip.current ? Theme.cyan : CP.alpha(Theme.red, 0.8)
                    strokeWidth: chip.current ? 1.5 : 1
                    inset: 0.75
                }
                Rectangle {
                    visible: chip.current
                    x: 3
                    y: 3
                    width: 4
                    height: 4
                    color: Theme.cyan
                }
                Text {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 3
                    text: chip.index + 1
                    color: chip.current ? Theme.cyan : CP.alpha(Theme.red, 0.8)
                    font { family: "Oxanium"; pixelSize: 8 }
                }
                Text {
                    anchors.centerIn: parent
                    text: chip.modelData
                    color: Theme.cyan
                    opacity: chip.current ? 1 : 0.75
                    font { family: "Oxanium"; pixelSize: 16; letterSpacing: 1 }
                }
                MouseArea {
                    id: hit
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.tab = chip.index
                }
            }
        }
    }

    Item {
        y: 104
        width: parent.width
        height: root.height - y

        Loader {
            anchors.fill: parent
            active: root.active && root.tab === 0
            sourceComponent: Tabs.OutputsTab {
                accent: Theme.cyan
                frame: Theme.red
                meter: Theme.cyan
                heading: Theme.red
                sourceBox: Theme.red
                eqBox: Theme.cyan
            }
        }
        Loader {
            anchors.fill: parent
            active: root.active && root.tab === 1
            sourceComponent: Tabs.InputsTab {
                accent: Theme.cyan
                frame: Theme.red
                meter: Theme.cyan
                heading: Theme.red
            }
        }
        Loader {
            anchors.fill: parent
            active: root.active && root.tab === 2
            sourceComponent: Tabs.AppsTab {
                accent: Theme.cyan
                frame: Theme.red
                heading: Theme.red
            }
        }
    }
}
