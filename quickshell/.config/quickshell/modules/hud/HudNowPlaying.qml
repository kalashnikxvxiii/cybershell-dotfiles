// HudNowPlaying.qml -- a chip at every track change: a red line runs out, flickers,
// opens into the panel, then closes the same way.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "../../common"
import "../../common/effects"

Scope {
    id: root
    required property var screen

    property string title: ""
    property string artist: ""
    property string source: ""

    readonly property string trackId: (Players.active?.trackTitle ?? "") + "|" + (Players.active?.trackArtist ?? "")
    // Not for the tracks the players report as the shell comes up
    property bool armed: false
    Timer { interval: 4000; running: true; onTriggered: root.armed = true }
    onTrackIdChanged: if (armed && HudState.enabled && Players.active?.isPlaying && trackId !== "|") settle.restart()

    function show() {
        root.title = Players.active?.identity ?? "SPOTIFY"
        root.artist = Players.active ? (Players.active.trackArtist || "Unknown") + " - " + (Players.active.trackTitle || "") : "Cyberpunk Edgerunners - I Really Want"
        win.visible = true
        run.restart()
    }

    // Metadata arrives in pieces: wait for it to stop changing
    Timer { id: settle; interval: 140; onTriggered: root.show() }

    PanelWindow {
        id: win
        screen: root.screen
        visible: false
        color: "transparent"
        anchors { top: true; right: true }
        // Clear of the sonar, closed or open
        margins { top: 60; right: SonarState.open ? 410 : 250 }
        implicitWidth: 340
        implicitHeight: 90
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "qs-nowplaying"
        mask: Region {}

        Item {
            id: plate
            anchors.centerIn: parent
            width: 320
            height: 64
            transform: Tilt { w: plate.width; h: plate.height; yaw: -16; pitch: 1; roll: -1.5; focal: 2600 }
            layer.enabled: true
            layer.smooth: true
            layer.textureSize: Qt.size(width * 2, height * 2)
            layer.effect: DarkHalo {}

            // The red line
            Rectangle {
                id: line
                y: parent.height / 2 - 1.5
                width: 0
                height: 3
                color: HudState.danger
            }
            // The panel
            Item {
                id: panel
                anchors.fill: parent
                anchors.margins: 4
                opacity: 0
                clip: true

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0.05, 0.09, 0.12, 0.88)
                }
                Repeater {
                    model: [[0, 0], [1, 0], [0, 1], [1, 1]]
                    Rectangle {
                        required property var modelData
                        x: modelData[0] * (panel.width - 5)
                        y: modelData[1] * (panel.height - 5)
                        width: 5
                        height: 5
                        color: HudState.danger
                    }
                }
                Text {
                    x: 18
                    y: 10
                    width: 240
                    elide: Text.ElideRight
                    text: root.title
                    color: HudState.tech
                    font { family: HudState.font; pixelSize: 14; bold: true }
                }
                Text {
                    x: 18
                    y: 31
                    width: 270
                    elide: Text.ElideRight
                    text: root.artist
                    color: HudState.alpha(HudState.tech, 0.75)
                    font { family: HudState.font; pixelSize: 12 }
                }
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    y: 12
                    height: 13
                    spacing: 2
                    Repeater {
                        id: bars
                        model: 4
                        Rectangle {
                            required property int index
                            anchors.bottom: parent.bottom
                            width: 3
                            height: 3 + eq.levels[index] * 10
                            color: HudState.tech
                        }
                    }
                }
                Ticker {
                    id: eq
                    property var levels: [0.4, 0.7, 0.45, 0.8]
                    running: win.visible
                    every: 4
                    onTicked: levels = levels.map(() => Math.random())
                }
            }
        }
    }

    SequentialAnimation {
        id: run
        PropertyAction { target: panel; property: "opacity"; value: 0 }
        PropertyAction { target: line; property: "opacity"; value: 1 }
        NumberAnimation { target: line; property: "width"; from: 0; to: plate.width; duration: 170 }
        // Flicker, stepped
        PropertyAction { target: line; property: "opacity"; value: 0.12 }
        PauseAnimation { duration: 50 }
        PropertyAction { target: line; property: "opacity"; value: 1 }
        PauseAnimation { duration: 50 }
        PropertyAction { target: line; property: "opacity"; value: 0.12 }
        PauseAnimation { duration: 50 }
        PropertyAction { target: line; property: "opacity"; value: 1 }
        PauseAnimation { duration: 50 }
        PropertyAction { target: line; property: "opacity"; value: 0 }
        NumberAnimation { target: panel; property: "opacity"; from: 0; to: 1; duration: 180 }
        PauseAnimation { duration: 6400 }
        NumberAnimation { target: panel; property: "opacity"; to: 0; duration: 180 }
        PropertyAction { target: line; property: "opacity"; value: 1 }
        NumberAnimation { target: line; property: "width"; to: 0; duration: 150 }
        PropertyAction { target: win; property: "visible"; value: false }
    }
}
