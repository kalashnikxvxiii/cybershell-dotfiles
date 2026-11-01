// Bar.qml — Cyberpunk 2077 HUD bar (content layout)
//
// Pure Item: all the system-level stuff (PanelWindow, exclusiveZone,
// layer-shell, hover) lives in TopBarWrapper.qml which instantiates this component.

import Quickshell
import QtQuick
import QtQuick.Effects
import QtQml.Models
import "../../common/Colors.js" as CP
import "../../common/BarConfig.js" as BC
import "."
import "../../common"
import "AudioControl"

Item {
    id: bar

    required property var screen
    required property var parentWindow

    property bool isDP1: BC.isPrimary(screen)
    property int  barHeight: 24
    // Where the tilted sides end: the gap Hyprland leaves above the windows
    property int  sidesBottom: 36
    readonly property alias leftSide: leftSection
    readonly property alias rightSide: rightSection
    property bool volumePopupVisible: false

    // The HUD's V button opens the same popup, on the screen it was pressed on
    Connections {
        target: AudioControlState
        function onRequestToggle(screenName)  {
            if (screenName === bar.screen.name) bar.volumePopupVisible = !bar.volumePopupVisible
        }
    }

    // ── Slide up/down transition coordinated with Exclusions ──────────────────────
    readonly property bool _isVisible: BarState.isVisibleOn(bar.screen.name)

    transform: Translate {
        id: barSlide
        y: bar._isVisible ? 0 : -bar.sidesBottom
        Behavior on y {
            NumberAnimation {
                duration: 500
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.16, 1, 0.3, 1, 1, 1]
            }
        }
    }

    // Kill input while off-screen (avoid ghost hovers on hidden bar)
    enabled: bar._isVisible

    // ── Layout ────────────────────────────────────────────────────────────
    Item {
        anchors.fill: parent

        // CENTER
        Row {
            id: centerRow
            height: parent.height
            anchors.centerIn: parent
            spacing: 0

            Repeater {
                id: centerRepeater
                model: bar.isDP1
                    ? BC.entriesPrimaryCenter
                    : BC.entriesSecondaryCenter
                
                delegate: DelegateChooser {
                    role: "name"

                    DelegateChoice {
                        roleValue: "centerSection"
                        CenterSection {
                            barScreen: bar.screen
                            height: barHeight
                        }
                    }
                }
            }
        }

        // LEFT: leans like the HUD's vitals, down towards the center
        // Pinned on its left, and with a fixed pivot: the tiles stay put while the title changes
        LeftSection {
            id: leftSection
            anchors.left: parent.left
            anchors.leftMargin: 320
            y: 6
            height: 32
            barScreen: bar.screen
            transform: Tilt { w: 400; h: 32; yaw: 24; pitch: 5; roll: -1; focal: 2100 }
            // Flat at twice the size, then tilted as one texture (see HudPlate)
            layer.enabled: true
            layer.smooth: true
            layer.textureSize: Qt.size(width * 2, height * 2)
            layer.effect: DarkHalo {}
        }

        // RIGHT: leans like the HUD's status corner, mirrored
        RightSection {
            id: rightSection
            // Up against the HUD clock
            anchors.right: parent.right
            anchors.rightMargin: 150
            y: 5
            barScreen: bar.screen
            height: 32
            parentWindow: bar.parentWindow
            onVolumeToggleRequested: bar.volumePopupVisible = !bar.volumePopupVisible
            transform: Tilt { w: rightSection.width; h: rightSection.height; yaw: -16; pitch: 1; roll: -2; focal: 2600 }
            layer.enabled: true
            layer.smooth: true
            layer.textureSize: Qt.size(width * 2, height * 2)
            layer.effect: DarkHalo {}
        }
    }

    // -- Volume popup --------------------------
    PopupWindow {
        id: volumePopupWin
        visible: bar.volumePopupVisible || audioControlContent.height > 0
        color: "transparent"   // let CutShape diagonals show desktop background through
        anchor.window: bar.parentWindow
        // Next to the Sonar: as its card grows, slides along the slope of its top edge
        anchor.rect: Qt.rect(bar.width - 237 - (HudState.sonarShift[bar.screen.name] || 0), bar.sidesBottom + 0.047 * (HudState.sonarShift[bar.screen.name] || 0), 1, 1)
        anchor.edges: Edges.Bottom | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Left
        // Fixed size: resizing the surface on every frame made the animation stutter
        implicitWidth: 560
        implicitHeight: 740
        mask: Region { item: audioControlContent }
        onVisibleChanged: if (visible) audioControlContent.forceActiveFocus()

        // Flat at twice the size, tilted as one texture. Fixed and larger than the panel: the
        // panel's border never touches the texture's edge, and growing never reallocates it
        Item {
            width: 560
            height: 740
            // The Sonar's plane (HudStatusFrame): same angles and same center, so that the
            // panel's top edge is the extension of the Sonar's
            transform: Tilt { w: 1236; h: 368; yaw: -16; pitch: 1; roll: -1.5; focal: 2600 }
            layer.enabled: volumePopupWin.visible
            layer.smooth: true
            layer.textureSize: Qt.size(width * 2, height * 2)

            AudioControlPopup {
                id: audioControlContent
                x: 488 - width
                y: 24
                // Slightly larger when expanded, driven by the width's own animation
                transform: Scale {
                    origin.x: audioControlContent.width
                    xScale: 1 + 0.08 * (audioControlContent.width - 220) / 200
                    yScale: xScale
                }
                open: bar.volumePopupVisible
                onCloseRequested: bar.volumePopupVisible = false
            }
        }
    }
    
    PopupWindow {
        id: wsPreviewWin
        visible: BarState.previewWorkspace !== null
                && BarState.previewWorkspace.monitor
                && bar.screen
                && BarState.previewWorkspace.monitor.name === bar.screen.name
        color: "transparent"
        anchor.window: bar.parentWindow
        anchor.rect: Qt.rect(leftSection.x, bar.sidesBottom, 1, 1)
        anchor.edges: Edges.Bottom | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        implicitWidth: Math.max(1, wsPreviewContent.implicitWidth)
        implicitHeight: Math.max(1, wsPreviewContent.implicitHeight)

        WorkspacePreview {
            id: wsPreviewContent
            workspace: BarState.previewWorkspace
            previewWidth: 420
            active: wsPreviewWin.visible
        }
    }
}
