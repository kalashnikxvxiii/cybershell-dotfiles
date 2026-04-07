// GpuExpandedOverlay.qml — Expanded overlay with GPU details
// Extracted from PerfMetrics.qml: VRAM, Power, Clocks, Fan, Encoder/Decoder, P-State, PCIe

import QtQuick
import QtQuick.Layouts
import "../../../common"

Item {
    id: root
    clip: true

    // ── Required properties ──
    required property real    expandProgress
    required property bool    animTriggered
    required property color   gpuColor
    required property color   gpuTempColor
    required property string  gpuName
    required property real    gpuPerc
    required property real    gpuTemp
    required property real    gpuVramUsedGb
    required property real    gpuVramTotalGb
    required property int     gpuClockCur
    required property int     gpuClockMax
    required property int     gpuMemClockCur
    required property int     gpuMemClockMax
    required property real    gpuPowerDraw
    required property real    gpuPowerLimit
    required property int     gpuFanSpeed
    required property string  gpuPState
    required property string  gpuPcieGen
    required property string  gpuPcieWidth
    required property int     gpuEncoderUtil
    required property int     gpuDecoderUtil
    required property int     gpuMemBwUtil

    signal closeRequested()

    CutShape {
        anchors.fill: parent
        fillColor: Colours.moduleBg
        cutBottomLeft: 24
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 12
        opacity: root.expandProgress

        // ── Header ────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle { width: 3; height: 14; color: root.gpuColor }
            Text {
                text: "GPU DETAILS"
                font.family: "Oxanium"
                font.pixelSize: 11
                font.letterSpacing: 2
                color: root.gpuColor
            }
            Text {
                text: root.gpuName
                font.family: "Chakra Petch"
                font.pixelSize: 9
                color: Colours.textMuted
            }
            Item { Layout.fillWidth: true }
            Text {
                text: root.gpuPerc.toFixed(1) + "%"
                font.family: "Chakra Petch"
                font.pixelSize: 10
                color: root.gpuColor
            }
            Text {
                text: root.gpuTemp.toFixed(0) + "°C"
                font.family: "Chakra Petch"
                font.pixelSize: 10
                color: root.gpuTempColor
            }
            Text {
                text: "[ESC]"
                font.family: "Oxanium"
                font.pixelSize: 8
                color: Colours.textMuted
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }

        // ── TOP: VRAM + Power gauges
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            // VRAM gauge card
            Item {
                id: gpuExp0
                Layout.fillWidth: true
                Layout.fillHeight: true
                property bool _animDone: false
                opacity: _animDone ? 1 : 0
                scale: _animDone ? 1.0 : 0.2
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InQuad } }
                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                Timer { interval: 0; running: root.animTriggered; repeat: false; onTriggered: gpuExp0._animDone = true }
                Connections { target: root; function onAnimTriggeredChanged() {
                    if (!root.animTriggered) {
                        gpuExp0._animDone = false
                    }
                }}

                CutShape {
                    anchors.fill: parent
                    fillColor: Qt.rgba(0, 0, 0, 0.3)
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 2

                    Text {
                        text: "VRAM"; font.family: "Oxanium"
                        font.pixelSize: 9; font.letterSpacing: 2
                        color: Colours.textMuted; Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: root.gpuVramUsedGb.toFixed(1) + " GB"
                        font.family: "Oxanium"; font.pixelSize: 26
                        font.weight: Font.Bold; color: Colours.accentPrimary
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: "/ " + root.gpuVramTotalGb.toFixed(1) + " GB"
                        font.family: "Chakra Petch"; font.pixelSize: 9
                        color: Colours.textSecondary; Layout.alignment: Qt.AlignHCenter
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 30

                        Canvas {
                            id: vramArc
                            anchors.fill: parent
                            property real pct: root.gpuVramTotalGb > 0 ? root.gpuVramUsedGb / root.gpuVramTotalGb : 0
                            onPctChanged: requestPaint()
                            Component.onCompleted: requestPaint()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()

                            onPaint: {
                                let ctx = getContext("2d")
                                let w = width, h = height
                                ctx.clearRect(0, 0, w, h)
                                if (w <= 0 || h <= 0) return

                                let cx = w / 2, r = w * 0.45
                                let cy = h + r * 0.1, lineW = 3
                                let leftAngle = Math.PI - 0.35
                                let rightAngle = 0.35
                                let totalSweep = leftAngle - rightAngle
                                let sweepCW = 2 * Math.PI - totalSweep
                                let c = Colours.accentPrimary

                                ctx.beginPath()
                                ctx.arc(cx, cy, r, leftAngle, rightAngle, false)
                                ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.1)
                                ctx.lineWidth = lineW
                                ctx.lineCap = "round"
                                ctx.stroke()

                                if (pct > 0) {
                                    let activeEnd = leftAngle + sweepCW * pct
                                    ctx.beginPath()
                                    ctx.arc(cx, cy, r, leftAngle, activeEnd, false)
                                    ctx.strokeStyle = c
                                    ctx.lineWidth = lineW
                                    ctx.lineCap = "round"
                                    ctx.stroke()

                                    let tipX = cx + Math.cos(activeEnd) * r
                                    let tipY = cy + Math.sin(activeEnd) * r
                                    let glow = ctx.createRadialGradient(tipX, tipY, 0, tipX, tipY, 8)
                                    glow.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.5))
                                    glow.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0))
                                    ctx.beginPath()
                                    ctx.arc(tipX, tipY, 8, 0, 2 * Math.PI)
                                    ctx.fillStyle = glow
                                    ctx.fill()
                                }
                            }
                        }
                    }

                    Text {
                        text: (root.gpuVramTotalGb > 0 ? (root.gpuVramUsedGb /  root.gpuVramTotalGb * 100).toFixed(0) : "0") + "%"
                        font.family: "Oxanium"; font.pixelSize: 20; font.weight: Font.Bold
                        color: Colours.accentPrimary; Layout.alignment: Qt.AlignHCenter
                    }
                }

                CutShape { anchors.fill: parent; strokeColor: Colours.neonBorder(0.3); strokeWidth: 1; inset: 0.5 }
            }

            // Power gauge card
            Item {
                id: gpuExp1
                Layout.fillWidth: true
                Layout.fillHeight: true

                property bool _animDone: false
                opacity: _animDone ? 1 : 0
                scale: _animDone ? 1.0 : 0.2
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InQuad } }
                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                Timer { interval: 80; running: root.animTriggered; repeat: false; onTriggered: gpuExp1._animDone = true }
                Connections { target: root; function onAnimTriggeredChanged() {
                    if (!root.animTriggered) gpuExp1._animDone = false 
                }}

                CutShape {
                    anchors.fill: parent; fillColor: Qt.rgba(0, 0, 0, 0.3)
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 2

                    Text {
                        text: "POWER"; font.family: "Oxanium"; font.pixelSize: 9
                        font.letterSpacing: 2; color: Colours.textMuted
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: root.gpuPowerDraw.toFixed(1) + " W"
                        font.family: "Oxanium"; font.pixelSize: 26; font.weight: Font.Bold
                        color: Colours.accentWarn; Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: "/ " + root.gpuPowerLimit.toFixed(0) + " W"
                        font.family: "Chakra Petch"; font.pixelSize: 9
                        color: Colours.textSecondary; Layout.alignment: Qt.AlignHCenter
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 30

                        Canvas {
                            id: powerArc
                            anchors.fill: parent
                            property real pct: root.gpuPowerLimit > 0 ? root.gpuPowerDraw / root.gpuPowerLimit : 0
                            onPctChanged: requestPaint()
                            Component.onCompleted: requestPaint()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()

                            onPaint: {
                                let ctx = getContext("2d")
                                let w = width, h = height
                                ctx.clearRect(0, 0, w, h)
                                if (w <= 0 || h <= 0) return

                                let cx = w / 2, r = w * 0.45
                                let cy = h + r * 0.1, lineW = 3
                                let leftAngle = Math.PI - 0.35
                                let rightAngle = 0.35
                                let totalSweep = leftAngle - rightAngle
                                let sweepCW = 2 * Math.PI - totalSweep
                                let c = Colours.accentWarn

                                ctx.beginPath()
                                ctx.arc(cx, cy, r, leftAngle, rightAngle, false)
                                ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.1)
                                ctx.lineWidth = lineW
                                ctx.lineCap = "round"
                                ctx.stroke()

                                if (pct > 0) {
                                    let activeEnd = leftAngle + sweepCW * Math.min(1, pct)
                                    ctx.beginPath()
                                    ctx.arc(cx, cy, r, leftAngle, activeEnd, false)
                                    ctx.strokeStyle = c
                                    ctx.lineWidth = lineW
                                    ctx.lineCap = "round"
                                    ctx.stroke()

                                    let tipX = cx + Math.cos(activeEnd) * r
                                    let tipY = cy + Math.sin(activeEnd) * r
                                    let glow = ctx.createRadialGradient(tipX, tipY, 0, tipX, tipY, 8)
                                    glow.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.5))
                                    glow.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0))
                                    ctx.beginPath()
                                    ctx.arc(tipX, tipY, 8, 0, 2 * Math.PI)
                                    ctx.fillStyle = glow
                                    ctx.fill()
                                }
                            }
                        }
                    }

                    Text {
                        text: (root.gpuPowerLimit > 0 ? (root.gpuPowerDraw / root.gpuPowerLimit * 100).toFixed(0) : "0") + "%"
                        font.family: "Oxanium"; font.pixelSize: 20; font.weight: Font.Bold
                        color: Colours.accentWarn; Layout.alignment: Qt.AlignHCenter
                    }
                }

                CutShape { anchors.fill: parent; strokeColor: Colours.neonBorder(0.3); strokeWidth: 1; inset: 0.5 }
            }
        }

        // ── MID section: Clocks + Fan ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            // GPU Clock
            Item {
                id: gpuExp2
                Layout.fillWidth: true
                Layout.preferredHeight: 120

                property bool _animDone: false
                opacity: _animDone ? 1 : 0
                scale: _animDone ? 1.0 : 0.2
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InQuad } }
                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                Timer { interval: 160; running: root.animTriggered; repeat: false; onTriggered: gpuExp2._animDone = true }
                Connections { target: root; function onAnimTriggeredChanged() { if (!root.animTriggered) gpuExp2._animDone = false } }

                CutShape { anchors.fill: parent; fillColor: Qt.rgba(0, 0, 0, 0.3) }
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 6; spacing: 2
                    Text { text: "GPU CLOCK"; font.family: "Oxanium"; font.pixelSize: 8; font.letterSpacing: 1.5; color: Colours.textMuted; Layout.alignment: Qt.AlignHCenter }
                    Text { text: root.gpuClockCur + " MHz"; font.family: "Oxanium"; font.pixelSize: 18; font.weight: Font.Bold; color: Colours.accentSecondary; Layout.alignment: Qt.AlignHCenter }
                    Text { text: "MAX " + root.gpuClockMax; font.family: "Chakra Petch"; font.pixelSize: 9; color: Colours.textMuted; Layout.alignment: Qt.AlignHCenter }
                }
                CutShape { anchors.fill: parent; strokeColor: Colours.neonBorder(0.3); strokeWidth: 1; inset: 0.5 }
            }

            // Mem Clock
            Item {
                id: gpuExp3
                Layout.fillWidth: true
                Layout.preferredHeight: 120

                property bool _animDone: false
                opacity: _animDone ? 1 : 0
                scale: _animDone ? 1.0 : 0.2
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InQuad } }
                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                Timer { interval: 240; running: root.animTriggered; repeat: false; onTriggered: gpuExp3._animDone = true }
                Connections { target: root; function onAnimTriggeredChanged() { if (!root.animTriggered) gpuExp3._animDone = false } }

                CutShape { anchors.fill: parent; fillColor: Qt.rgba(0, 0, 0, 0.3) }
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 6; spacing: 2
                    Text { text: "MEM CLOCK"; font.family: "Oxanium"; font.pixelSize: 8; font.letterSpacing: 1.5; color: Colours.textMuted; Layout.alignment: Qt.AlignHCenter }
                    Text { text: root.gpuMemClockCur + " MHz"; font.family: "Oxanium"; font.pixelSize: 18; font.weight: Font.Bold; color: Colours.accentSecondary; Layout.alignment: Qt.AlignHCenter }
                    Text { text: "MAX " + root.gpuMemClockMax; font.family: "Chakra Petch"; font.pixelSize: 9; color: Colours.textMuted; Layout.alignment: Qt.AlignHCenter }
                }
                CutShape { anchors.fill: parent; strokeColor: Colours.neonBorder(0.3); strokeWidth: 1; inset: 0.5 }
            }

            // Fan
            Item {
                id: gpuExp4
                Layout.fillWidth: true
                Layout.preferredHeight: 120

                property bool _animDone: false
                opacity: _animDone ? 1 : 0
                scale: _animDone ? 1.0 : 0.2
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InQuad } }
                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                Timer { interval: 320; running: root.animTriggered; repeat: false; onTriggered: gpuExp4._animDone = true }
                Connections { target: root; function onAnimTriggeredChanged() { if (!root.animTriggered) gpuExp4._animDone = false } }

                readonly property color fanColor: root.gpuFanSpeed > 90 ? Colours.accentDanger
                                                : root.gpuFanSpeed > 70 ? Colours.accentWarn
                                                : Colours.accentOk

                CutShape { anchors.fill: parent; fillColor: Qt.rgba(0, 0, 0, 0.3) }
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 6; spacing: 2
                    Text { text: "FAN"; font.family: "Oxanium"; font.pixelSize: 8; font.letterSpacing: 1.5; color: Colours.textMuted; Layout.alignment: Qt.AlignHCenter }
                    Text { text: root.gpuFanSpeed + "%"; font.family: "Oxanium"; font.pixelSize: 18; font.weight: Font.Bold; color: gpuExp4.fanColor; Layout.alignment: Qt.AlignHCenter }
                }
                CutShape { anchors.fill: parent; strokeColor: Colours.neonBorder(0.3); strokeWidth: 1; inset: 0.5 }
            }
        }

        // ── BOTTOM section: Usage bars ──
        Item {
            id: gpuExp5
            Layout.fillWidth: true
            Layout.preferredHeight: childrenRect.height

            property bool _animDone: false
            opacity: _animDone ? 1 : 0
            scale: _animDone ? 1.0 : 0.2
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InQuad } }
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
            Timer { interval: 400; running: root.animTriggered; repeat: false; onTriggered: gpuExp5._animDone = true }
            Connections { target: root; function onAnimTriggeredChanged() { if (!root.animTriggered) gpuExp5._animDone = false } }

            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 10

                // Encoder bar
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text { text: "ENCODER"; font.family: "Oxanium"; font.pixelSize: 10; font.letterSpacing: 1; color: Colours.textMuted; Layout.preferredWidth: 70 }
                    Item {
                        Layout.fillWidth: true; Layout.preferredHeight: 12
                        Rectangle { anchors.fill: parent; color: Qt.rgba(Colours.accentMem.r, Colours.accentMem.g, Colours.accentMem.b, 0.08) }
                        Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: parent.width * (root.gpuEncoderUtil / 100); color: Colours.accentMem; Behavior on width { Anim { duration: 400 } } }
                    }
                    Text { text: root.gpuEncoderUtil + "%"; font.family: "Oxanium"; font.pixelSize: 12; font.weight: Font.Bold; color: Colours.accentMem; Layout.preferredWidth: 35; horizontalAlignment: Text.AlignRight }
                }

                // Decoder bar
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text { text: "DECODER"; font.family: "Oxanium"; font.pixelSize: 10; font.letterSpacing: 1; color: Colours.textMuted; Layout.preferredWidth: 70 }
                    Item {
                        Layout.fillWidth: true; Layout.preferredHeight: 12
                        Rectangle { anchors.fill: parent; color: Qt.rgba(Colours.accentMem.r, Colours.accentMem.g, Colours.accentMem.b, 0.08) }
                        Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: parent.width * (root.gpuDecoderUtil / 100); color: Colours.accentMem; Behavior on width { Anim { duration: 400 } } }
                    }
                    Text { text: root.gpuDecoderUtil + "%"; font.family: "Oxanium"; font.pixelSize: 12; font.weight: Font.Bold; color: Colours.accentMem; Layout.preferredWidth: 35; horizontalAlignment: Text.AlignRight }
                }

                // Mem BW bar
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text { text: "MEM BW"; font.family: "Oxanium"; font.pixelSize: 10; font.letterSpacing: 1; color: Colours.textMuted; Layout.preferredWidth: 70 }
                    Item {
                        Layout.fillWidth: true; Layout.preferredHeight: 12
                        Rectangle { anchors.fill: parent; color: Qt.rgba(Colours.accentSecondary.r, Colours.accentSecondary.g, Colours.accentSecondary.b, 0.08) }
                        Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: parent.width * (root.gpuMemBwUtil / 100); color: Colours.accentSecondary; Behavior on width { Anim { duration: 400 } } }
                    }
                    Text { text: root.gpuMemBwUtil + "%"; font.family: "Oxanium"; font.pixelSize: 12; font.weight: Font.Bold; color: Colours.accentSecondary; Layout.preferredWidth: 35; horizontalAlignment: Text.AlignRight }
                }
            }
        }

        // ── Status row: P-State + PCIe ──
        Item {
            id: gpuExp6
            Layout.fillWidth: true
            Layout.preferredHeight: 30

            property bool _animDone: false
            opacity: _animDone ? 1 : 0
            scale: _animDone ? 1.0 : 0.2
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InQuad } }
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
            Timer { interval: 480; running: root.animTriggered; repeat: false; onTriggered: gpuExp6._animDone = true }
            Connections { target: root; function onAnimTriggeredChanged() { if (!root.animTriggered) gpuExp6._animDone = false } }

            readonly property color pstateColor: {
                let n = parseInt(root.gpuPState.replace("P", "")) || 0
                return n <= 2 ? Colours.accentOk : n <= 5 ? Colours.accentWarn : Colours.accentDanger
            }

            RowLayout {
                anchors.fill: parent
                spacing: 6

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    CutShape { anchors.fill: parent; fillColor: Qt.rgba(0, 0, 0, 0.3); cutBottomLeft: 12 }
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 6
                        Text { text: "P-STATE"; font.family: "Oxanium"; font.pixelSize: 12; font.letterSpacing: 1; color: Colours.textMuted }
                        Item { Layout.fillWidth: true }
                        Text { text: root.gpuPState; font.family: "Oxanium"; font.pixelSize: 11; font.weight: Font.Bold; color: gpuExp6.pstateColor }
                    }
                    CutShape { anchors.fill: parent; strokeColor: Colours.neonBorder(0.3); strokeWidth: 1; inset: 0.5; cutBottomLeft: 12 }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    CutShape { anchors.fill: parent; fillColor: Qt.rgba(0, 0, 0, 0.3) }
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 6
                        Text { text: "PCIE"; font.family: "Oxanium"; font.pixelSize: 12; font.letterSpacing: 1; color: Colours.textMuted }
                        Item { Layout.fillWidth: true }
                        Text { text: "GEN" + root.gpuPcieGen + " x" + root.gpuPcieWidth; font.family: "Oxanium"; font.pixelSize: 11; font.weight: Font.Bold; color: Colours.accentSecondary }
                    }
                    CutShape { anchors.fill: parent; strokeColor: Colours.neonBorder(0.3); strokeWidth: 1; inset: 0.5 }
                }
            }
        }
    }

    CutShape {
        anchors.fill: parent
        strokeWidth: 1
        strokeColor: Colours.neonBorder(0.3)
        inset: 0.5
        cutBottomLeft: 24
    }
}
