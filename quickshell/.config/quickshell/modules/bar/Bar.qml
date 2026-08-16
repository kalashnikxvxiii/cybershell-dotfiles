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
    property bool volumePopupVisible: false

    // ── Slide up/down transition coordinated with Exclusions ──────────────────────
    readonly property bool _isVisible: BarState.isVisibleOn(bar.screen.name)

    transform: Translate {
        id: barSlide
        y: bar._isVisible ? 0 : -bar.barHeight
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

    // ── Background gradient (color from Colours / Wallust) ───────────────
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Colours.barBg }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // ── Scanline overlay (HUD effect) ──────────────────────────────────────
    // Dark horizontal lines every 2px — authentic CRT feel
    Item {
        anchors.fill: parent
        clip: true
        opacity: 0.16
        Repeater {
            model: Math.ceil(bar.barHeight / 2) + 1
            delegate: Rectangle {
                required property int index
                y: index * 2
                width: parent.width
                height: 1
                color: Colours.scanlineColor
            }
        }
    }

    // ── Bottom glow border (neon line with bloom) ─────────────────────────
    Rectangle {
        anchors.bottom: parent.top
        anchors.left:   parent.left
        anchors.right:  parent.right
        height: 1
        color: Colours.accentSecondary
        opacity: 0.55
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor:            Colours.accentSecondary
            shadowBlur:             0.85
            shadowOpacity:          1
            shadowHorizontalOffset: 0
            shadowVerticalOffset:   2
        }
    }

    // ── Layout ────────────────────────────────────────────────────────────
    Item {
        anchors.fill: parent

        // LEFT
        Row {
            id: leftRow
            height: parent.height
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            spacing: 0

            Repeater {
                id: leftRepeater
                model: bar.isDP1
                       ? BC.entriesPrimaryLeft
                       : BC.entriesSecondaryLeft

                delegate: DelegateChooser {
                    role: "name"

                    DelegateChoice {
                        roleValue: "leftSection"
                        LeftSection {
                            barScreen: bar.screen
                            height:    leftRow.height
                        }
                    }
                }
            }
        }

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

        // RIGHT
        RightSection {
            id: rightSection
            barScreen: bar.screen
            height: barHeight
            parentWindow: bar.parentWindow
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            onVolumeToggleRequested: bar.volumePopupVisible = !bar.volumePopupVisible
        }
    }

    // ── Volume popup ───────────────────────────────────────────
    PopupWindow {
        id: volumePopupWin
        visible: bar.volumePopupVisible
        color: "transparent"   // let CutShape diagonals show desktop background through
        anchor.window: bar.parentWindow
        anchor.item: rightSection.volumeAnchor
        anchor.rect: Qt.rect(0, 4, 72, barHeight)
        // Edges: Bottom=1 Left=2 Right=4 Top=8 (no 4|1/4|2=Left|Right, no 8|1=Top|Bottom)
        anchor.edges: 1 | 2
        anchor.gravity: 8 | 2
        implicitWidth: audioControlContent.width
        implicitHeight: audioControlContent.height
        onVisibleChanged: if (visible) audioControlContent.forceActiveFocus()

        AudioControlPopup {
            id: audioControlContent
            onCloseRequested: bar.volumePopupVisible = false
        }
    }

}
