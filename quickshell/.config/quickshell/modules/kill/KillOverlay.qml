// KillOverlay.qml -- kill mode, one surface per screen: a red veil, a crosshair on the pointer,
// the window under it marked with what it is. Left click kills it; right click or Esc leaves.
// Holds the keyboard, so it also leaves by itself after a while.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../common"
import "../../common/effects"

Scope {
    id: root

    required property var screen

    readonly property bool focused: Hyprland.focusedMonitor?.name === root.screen.name
    property var target: null
    property real pointerX: -1
    property real pointerY: -1

    Timer {
        interval: 30000
        running: KillState.open
        onTriggered: KillState.stop()
    }

    onFocusedChanged: if (KillState.open && focused) keys.forceActiveFocus()

    Connections {
        target: KillState
        function onOpenChanged() {
            root.target = null
            if (KillState.open)
                keys.forceActiveFocus()
        }
    }

    PanelWindow {
        screen: root.screen
        visible: KillState.open || fx.visible
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-kill"
        WlrLayershell.keyboardFocus: KillState.open && root.focused ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        GlitchReveal {
            id: fx
            anchors.fill: parent
            shown: KillState.open

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0.28, 0, 0.03, 0.42)
            }
            ScanlineOverlay {
                opacity: 0.09
            }
            // Around the target, an even step off its corners; around the screen without one
            Item {
                readonly property int step: root.target ? 12 : 6
                // Without a target, around the area windows fill. Its side gap differs by screen
                readonly property int side: {
                    const tiled = KillState.clients.filter(c => c.monitor === root.screen.name && !c.floating)
                    return tiled.length > 0 ? Math.min(...tiled.map(c => c.x)) : 17
                }
                x: (root.target ? root.target.x : side) - step
                y: (root.target ? root.target.y : 41) - step
                width: (root.target ? root.target.w : parent.width - 2 * side) + 2 * step
                height: (root.target ? root.target.h : parent.height - 41 - 17) + 2 * step

                CornerAccents {
                    anchors.fill: parent
                    accentColor: HudState.danger
                    size: 22
                }
            }

            // Crosshair
            Rectangle {
                visible: root.pointerX >= 0
                x: root.pointerX
                width: 1
                height: parent.height
                color: HudState.alpha(HudState.danger, 0.45)
            }
            Rectangle {
                visible: root.pointerX >= 0
                y: root.pointerY
                width: parent.width
                height: 1
                color: HudState.alpha(HudState.danger, 0.45)
            }

            // The target
            CutShape {
                visible: root.target !== null
                x: (root.target?.x ?? 0) - 2
                y: (root.target?.y ?? 0) - 2
                width: (root.target?.w ?? 0) + 4
                height: (root.target?.h ?? 0) + 4
                // The window's own corners: rounding 34, power 1, plus its 2px border
                cutTopLeft: 20
                cutTopRight: 20
                cutBottomLeft: 20
                cutBottomRight: 20
                fillColor: HudState.alpha(HudState.danger, 0.1)
                strokeColor: HudState.danger
                strokeWidth: 2
                inset: 1

                CutShape {
                    anchors.centerIn: parent
                    width: Math.max(info.implicitWidth + 40, 300)
                    height: info.implicitHeight + 24
                    cutTopRight: 12
                    cutBottomLeft: 12
                    fillColor: Qt.rgba(0, 0, 0, 0.82)
                    strokeColor: HudState.danger
                    inset: 0.5

                    Column {
                        id: info
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            text: (root.target?.cls ?? "").toUpperCase()
                            color: HudState.danger
                            font { family: HudState.font; pixelSize: 20; bold: true; letterSpacing: 2 }
                        }
                        Text {
                            width: Math.min(implicitWidth, 420)
                            elide: Text.ElideRight
                            text: root.target?.title ?? ""
                            color: HudState.paper
                            font { family: HudState.font; pixelSize: 12 }
                        }
                        Text {
                            text: "PID " + (root.target?.pid ?? "") + "   //   SYNAPSE BURNOUT ARMED"
                            color: HudState.power
                            font { family: HudState.font; pixelSize: 11; letterSpacing: 1 }
                        }
                    }
                }
            }

            // Prompt
            Row {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 70
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    color: HudState.danger
                    font { family: HudState.icons; pixelSize: 24 }
                }
                CutShape {
                    width: label.implicitWidth + 44
                    height: 36
                    cutTopRight: 10
                    cutBottomLeft: 10
                    fillColor: HudState.alpha(HudState.danger, 0.2)
                    strokeColor: HudState.danger
                    strokeWidth: 2
                    inset: 1
                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: "CLICK ON AN APP TO TERMINATE!"
                        color: HudState.paper
                        font { family: HudState.font; pixelSize: 14; bold: true; letterSpacing: 1 }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "ESC  EXIT"
                    color: HudState.paper
                    font { family: HudState.font; pixelSize: 11; bold: true; letterSpacing: 1 }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.CrossCursor
                onPositionChanged: e => {
                    root.pointerX = e.x
                    root.pointerY = e.y
                    root.target = KillState.windowAt(root.screen.name, e.x, e.y)
                }
                onExited: {
                    root.pointerX = -1
                    root.target = null
                }
                onClicked: e => {
                    if (e.button === Qt.RightButton)
                        KillState.stop()
                    else if (root.target)
                        KillState.kill(root.target)
                }
            }

            Item {
                id: keys
                focus: true
                Keys.onEscapePressed: KillState.stop()
            }
        }
    }
}
