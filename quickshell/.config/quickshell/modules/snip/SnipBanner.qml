// SnipBanner.qml -- the capture banner, top left under the vitals: what to do while selecting,
// what happened right after. Takes no input, and being drawn over the frozen image it never
// ends up in a screenshot.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../common"
import "../../common/effects"

Scope {
    id: root

    required property var screen

    readonly property bool wanted: SnipState.bannerText !== "" && SnipState.bannerScreen === root.screen.name
    // A moment later: the surface mapped last goes on top, and it has to be above the selector
    property bool shown: false
    onWantedChanged: {
        if (wanted) {
            late.restart()
        } else {
            late.stop()
            shown = false
        }
    }
    Timer { id: late; interval: 120; onTriggered: root.shown = true }

    // Kept while the banner glitches out
    property string text: ""
    onShownChanged: if (shown) text = SnipState.bannerText
    Connections {
        target: SnipState
        function onBannerTextChanged() {
            if (SnipState.bannerText !== "")
                root.text = SnipState.bannerText
        }
    }

    PanelWindow {
        screen: root.screen
        visible: root.shown || fx.visible
        color: "transparent"
        anchors { top: true; left: true }
        margins { top: 124; left: 24 }
        implicitWidth: 500
        implicitHeight: 70
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-snip-banner"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}

        GlitchReveal {
            id: fx
            anchors.fill: parent
            shown: root.shown

            Item {
                id: plate
                anchors.fill: parent
                transform: Tilt { w: plate.width; h: plate.height; yaw: 24; pitch: 5; roll: 3; focal: 2100 }
                layer.enabled: true
                layer.smooth: true
                layer.textureSize: Qt.size(width * 2, height * 2)
                layer.effect: DarkHalo {}

                Text {
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    color: HudState.danger
                    font { family: HudState.icons; pixelSize: 26 }
                }
                CutShape {
                    x: 52
                    anchors.verticalCenter: parent.verticalCenter
                    width: 420
                    height: 34
                    cutTopRight: 6
                    cutBottomRight: 10
                    fillColor: HudState.alpha(HudState.danger, 0.22)
                    strokeColor: HudState.danger
                    inset: 0.5

                    Text {
                        anchors.centerIn: parent
                        text: root.text
                        color: HudState.danger
                        font { family: HudState.font; pixelSize: 14; bold: true; letterSpacing: 1 }
                    }
                }
            }
        }
    }
}
