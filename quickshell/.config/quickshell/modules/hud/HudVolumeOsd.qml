// HudVolumeOsd.qml -- the volume readout, bottom center of the focused screen, whatever changes
// the volume. Above fullscreen windows, takes no input, and stays out of the way while the
// volume popup is open, which already shows the same thing.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import "../../common"
import "../../common/effects"

Scope {
    id: root

    required property var screen

    PwObjectTracker { objects: [Pipewire.preferredDefaultAudioSink] }
    readonly property var audio: Pipewire.preferredDefaultAudioSink?.audio ?? null
    readonly property real volume: audio?.volume ?? 0
    readonly property bool muted: audio?.muted ?? false
    readonly property bool focused: Hyprland.focusedMonitor?.name === root.screen.name

    property bool shown: false
    // Past 100% the readout warns, and close to the 150% ceiling it alarms
    readonly property color level: root.volume >= 1.35 ? HudState.danger
        : root.volume > 1.05 ? Colours.accentWarn : HudState.tech

    function show() {
        if (!armed || !focused || AudioControlState.popupOpen)
            return
        shown = true
        hide.restart()
    }

    // Not for the values the sink reports as the shell comes up
    property bool armed: false
    Timer { interval: 3000; running: true; onTriggered: root.armed = true }
    Timer { id: hide; interval: 1500; onTriggered: root.shown = false }

    Connections {
        target: root.audio
        function onVolumesChanged() { root.show() }
        function onMutedChanged() { root.show() }
    }

    PanelWindow {
        screen: root.screen
        visible: root.shown || fx.visible
        color: "transparent"
        anchors.bottom: true
        margins.bottom: 70
        implicitWidth: 360
        implicitHeight: 90
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-osd"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}

        GlitchReveal {
            id: fx
            anchors.centerIn: parent
            width: plate.width
            height: plate.height
            shown: root.shown

            Item {
                id: plate
                width: 330
                height: 74
                transform: Tilt { w: plate.width; h: plate.height; pitch: 4; focal: 1300 }
                layer.enabled: true
                layer.smooth: true
                layer.textureSize: Qt.size(width * 2, height * 2)
                layer.effect: DarkHalo {}

                // Corner strokes
                Rectangle { x: 8; y: 8; width: 16; height: 2; color: HudState.tech }
                Rectangle { x: 8; y: 8; width: 1; height: 54; color: HudState.alpha(HudState.tech, 0.4) }
                Rectangle { x: plate.width - 24; y: 62; width: 16; height: 2; color: HudState.tech }

                Text {
                    x: 20
                    y: 16
                    text: root.muted ? "" : root.volume > 0.5 ? "" : ""
                    color: root.level
                    font { family: HudState.icons; pixelSize: 22 }
                }
                Text {
                    x: 56
                    y: 14
                    text: "VOLUME"
                    color: HudState.tech
                    font { family: HudState.font; pixelSize: 13; bold: true; letterSpacing: 1 }
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    y: 12
                    text: root.muted ? "MUTE" : Math.round(root.volume * 100) + "%"
                    color: root.level
                    font { family: HudState.font; pixelSize: 15; bold: true }
                }
                Rectangle {
                    x: 56
                    y: 40
                    width: plate.width - 70
                    height: 9
                    color: HudState.track(root.level)

                    Rectangle {
                        width: parent.width * (root.muted ? 0 : Math.min(1, root.volume))
                        height: parent.height
                        color: root.level
                    }
                }
            }
        }
    }
}
