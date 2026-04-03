// PowerPopup.qml — power menu popup (Exit WM / Power off / Reboot)
// Miglioramenti: CutShape (no border-radius), CornerAccents, glitch sui tile on hover

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import "../../common/Colors.js" as CP
import "../../common"

Item {
    id: root
    width: 160
    height: 118

    signal closeRequested()

    Process { id: poweroffProc; command: ["systemctl", "poweroff"]; running: false }
    Process { id: rebootProc;   command: ["systemctl", "reboot"];   running: false }

    // ── Enter animation ───────────────────────────────────────────────────
    opacity: 0
    property real slideY: -16
    Component.onCompleted: {
        powerEnterOpacity.start()
        powerEnterSlide.start()
    }
    NumberAnimation {
        id: powerEnterOpacity
        target: root; property: "opacity"
        from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic
    }
    NumberAnimation {
        id: powerEnterSlide
        target: root; property: "slideY"
        from: -16; to: 0; duration: 180; easing.type: Easing.OutCubic
    }

    // ── Card con CutShape ─────────────────────────────────────────────────
    Item {
        id: card
        y: root.slideY
        width: parent.width; height: parent.height

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor:            CP.red
            shadowBlur:             0.75
            shadowOpacity:          0.35
            shadowHorizontalOffset: 0
            shadowVerticalOffset:   0
        }

        CutShape {
            anchors.fill: parent
            fillColor:   CP.moduleBg
            strokeColor: Qt.rgba(1, 0, 0.235, 0.50)
            strokeWidth: 1
            inset: 0.5
            cutTopRight:   10
            cutBottomLeft: 10
        }

        // Bordo sinistro rosso
        Rectangle {
            width: 3; height: parent.height
            color: CP.red
        }
        // Linea bottom
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width; height: 1
            color: Qt.rgba(1, 0, 0.235, 0.40)
        }
    }

    // ── CornerAccents ─────────────────────────────────────────────────────
    CornerAccents {
        x: 0; y: root.slideY
        width: parent.width; height: parent.height
        accentColor:     CP.red
        size:            7
        showTopLeft:     true
        showTopRight:    false
        showBottomLeft:  false
        showBottomRight: true
        opacity: 0.65
    }

    // ── Tile list ─────────────────────────────────────────────────────────
    Column {
        id: tileColumn
        y: root.slideY + 8
        x: 10
        width: parent.width - 20
        spacing: 4

        Repeater {
            model: [
                { label: "EXIT WM",   action: "exit" },
                { label: "POWER OFF", action: "poweroff" },
                { label: "REBOOT",    action: "reboot" }
            ]
            delegate: Item {
                required property var modelData
                width: tileColumn.width
                height: 32

                // Stato glitch per il tile
                property bool _glitch: false
                property color _textColor: CP.red

                CutShape {
                    anchors.fill: parent
                    fillColor:   tileHover.hovered
                                 ? Qt.rgba(1, 0, 0.235, 0.12)
                                 : Qt.rgba(0.12, 0.05, 0.08, 1)
                    strokeColor: Qt.rgba(1, 0, 0.235, 0.35)
                    strokeWidth: 1
                    inset: 0.5
                    cutTopRight:    5
                    cutBottomLeft:  5
                }

                Text {
                    id: tileLabel
                    anchors.centerIn: parent
                    text: modelData.label
                    font.family: "Oxanium"
                    font.pixelSize: 12
                    font.letterSpacing: 1
                    color: parent._textColor
                    transform: Translate { id: tileShift; x: 0 }
                }

                HoverHandler {
                    id: tileHover
                    onHoveredChanged: if (hovered) tileGlitch.restart()
                }

                SequentialAnimation {
                    id: tileGlitch
                    running: false; loops: 1

                    PropertyAction { target: parent; property: "_textColor"; value: CP.red }
                    PropertyAction { target: tileShift; property: "x"; value: 0 }
                    PauseAnimation { duration: 20 }

                    PropertyAction { target: parent; property: "_textColor"; value: CP.magenta }
                    PropertyAction { target: tileShift; property: "x"; value: 3 }
                    PauseAnimation { duration: 40 }

                    PropertyAction { target: parent; property: "_textColor"; value: CP.yellow }
                    PropertyAction { target: tileShift; property: "x"; value: -2 }
                    PauseAnimation { duration: 35 }

                    PropertyAction { target: parent; property: "_textColor"; value: CP.red }
                    PropertyAction { target: tileShift; property: "x"; value: 0 }
                    PauseAnimation { duration: 30 }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (modelData.action === "exit")
                            Hyprland.dispatch("exit")
                        else if (modelData.action === "poweroff")
                            poweroffProc.running = true
                        else if (modelData.action === "reboot")
                            rebootProc.running = true
                        root.closeRequested()
                    }
                }
            }
        }
    }

    // ── Close button ──────────────────────────────────────────────────────
    Text {
        id: closeBtn
        anchors { right: parent.right; rightMargin: 10; top: parent.top; topMargin: 6 }
        y: root.slideY
        text: "✕"
        font.pixelSize: 12
        color: CP.red
        opacity: closeHover.hovered ? 1 : 0.8
        HoverHandler { id: closeHover }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            onClicked: root.closeRequested()
        }
    }
}
