// SnipRecordFrame.qml -- the frame around a recording: crosshair corners, ruler, REC clock,
// camera tag. It must not end up in the video, and Hyprland's no_screen_share would only paint
// it black there, so whatever would fall inside the recorded region just stays hidden. Recording
// the whole screen leaves nothing to show; frameInVideo makes the opposite choice.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../common"

Scope {
    id: root

    required property var screen

    property bool frameInVideo: false

    readonly property bool shown: SnipState.recording && SnipState.recordScreen === root.screen.name
    readonly property var region: SnipState.recordRegion

    property int secs: 0
    function pad(n) { return (n < 10 ? "0" : "") + n }

    Timer {
        interval: 1000
        repeat: true
        running: root.shown
        onTriggered: root.secs = Math.floor((Date.now() - SnipState.recordStart) / 1000)
    }
    onShownChanged: secs = 0

    FileView {
        id: hostFile
        path: "/etc/hostname"
    }

    // In screen coordinates, with a margin: the camera tag leans a little past its box
    function clear(item) {
        if (root.frameInVideo || !root.region)
            return true
        const p = item.mapToItem(null, 0, 0)
        const m = 8
        return p.x + item.width + m <= root.region.x || p.x - m >= root.region.x + root.region.w
            || p.y + item.height + m <= root.region.y || p.y - m >= root.region.y + root.region.h
    }

    PanelWindow {
        screen: root.screen
        visible: root.shown
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-rec-frame"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}

        // Crosshair corners
        Repeater {
            model: [[0, 0], [1, 0], [0, 1], [1, 1]]
            Item {
                id: corner
                required property var modelData
                x: modelData[0] ? parent.width - width : 0
                y: modelData[1] ? parent.height - height : 0
                width: 22
                height: 22
                visible: root.clear(corner)
                Rectangle { y: 10; width: 22; height: 1; color: HudState.danger }
                Rectangle { x: 10; width: 1; height: 22; color: HudState.danger }
            }
        }

        // Ruler
        Item {
            id: ruler
            anchors.top: parent.top
            anchors.topMargin: 44
            anchors.horizontalCenter: parent.horizontalCenter
            width: 760
            height: 16
            visible: root.clear(ruler)

            Rectangle { y: 7; width: parent.width; height: 1; color: HudState.alpha(HudState.danger, 0.8) }
            Repeater {
                model: 7
                Rectangle {
                    required property int index
                    x: index * ruler.width / 6
                    y: 3
                    width: 1
                    height: 9
                    color: HudState.danger
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 200
                height: 15
                color: Qt.tint("#00060e", HudState.alpha(HudState.danger, 0.3))
                Text {
                    anchors.centerIn: parent
                    text: "CYBERDECK RECORDER"
                    color: HudState.danger
                    font { family: HudState.font; pixelSize: 10; bold: true; letterSpacing: 1 }
                }
            }
        }

        // REC clock and what is being recorded
        Column {
            id: clock
            x: 24
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 170
            spacing: 3
            visible: root.clear(clock)

            Rectangle {
                width: 76
                height: 18
                color: HudState.danger
                Text {
                    anchors.centerIn: parent
                    text: "REC " + root.pad(Math.floor(root.secs / 60)) + ":" + root.pad(root.secs % 60)
                    color: "#00060e"
                    font { family: HudState.font; pixelSize: 11; bold: true }
                }
            }
            Text {
                text: root.region ? Math.round(root.region.w) + " x " + Math.round(root.region.h) : ""
                color: HudState.danger
                font { family: HudState.font; pixelSize: 10 }
            }
        }

        // Camera tag, on the plane of the HUD's right corner
        Item {
            id: camera
            anchors.right: parent.right
            anchors.rightMargin: 30
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 110
            width: 330
            height: 34
            visible: root.clear(camera)
            transform: Tilt { w: camera.width; h: camera.height; yaw: -16; pitch: 1; roll: -1.5; focal: 2600 }
            layer.enabled: true
            layer.smooth: true
            layer.textureSize: Qt.size(width * 2, height * 2)

            Row {
                x: 2
                y: 4
                spacing: 8
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    color: HudState.danger
                    font { family: HudState.icons; pixelSize: 20 }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CAMERA 01:"
                    color: HudState.danger
                    font { family: HudState.font; pixelSize: 12; bold: true }
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 200
                    height: 15
                    color: HudState.danger
                    Text {
                        anchors.centerIn: parent
                        text: Quickshell.env("USER") + "@" + hostFile.text().trim() + " // LIVE"
                        color: "#00060e"
                        font { family: HudState.font; pixelSize: 10; bold: true }
                    }
                }
            }
        }
    }
}
