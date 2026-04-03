// PerfMetrics.qml — Colonna sinistra: 5 card metriche (CPU, GPU, Disk, Memory, Network)
// Richiede che il parent esponga le properties di PerfDataProvider tramite alias.

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import CyberGraphics
import PlasmaFX
import "../../../common/Colors.js" as CP
import "../../../common"

Item {
    id: metricsRoot

    // ── Properties richieste dal parent ──
    required property real      cpuPerc
    required property real      cpuTemp
    required property var       cpuHistory
    required property string    gpuName
    required property real      gpuPerc
    required property real      gpuTemp
    required property real      gpuVramUsedGb
    required property real      gpuVramTotalGb
    required property int       gpuClockCur
    required property int       gpuClockMax
    required property int       gpuMemClockCur
    required property int       gpuMemClockMax
    required property real      gpuPowerDraw
    required property real      gpuPowerLimit
    required property int       gpuFanSpeed
    required property string    gpuPState
    required property string    gpuPcieGen
    required property string    gpuPcieWidth
    required property int       gpuEncoderUtil
    required property int       gpuDecoderUtil
    required property int       gpuMemBwUtil
    required property real      memPerc
    required property real      memUsedGb
    required property real      memTotalGb
    required property real      swapUsedGb
    required property real      swapTotalGb
    required property real      diskPerc
    required property real      diskUsedGb
    required property real      diskTotalGb
    required property string    netStatus
    required property string    netSsid
    required property string    netSignal
    required property real      netRxBps
    required property real      netTxBps
    required property color     cpuColor
    required property color     gpuColor
    required property color     memColor
    required property color     tempColor
    required property color     gpuTempColor
    required property real      pulseValue
    required property bool      glitching
    readonly property bool      procMode: selectedProc !== null && selectedProc !== undefined && typeof selectedProc.cpu !== 'undefined'
    
    property var    selectedProc:   null
    property var    corePercs:      []
    property var    coreHistories: []

    function formatBytes(b) {
        if (b < 1024) return b.toFixed(0) + " B/s"
        if (b < 1048576) return (b / 1024).toFixed(1) + " KB/s"
        return (b / 1048576).toFixed(2) + " MB/s"
    }

    // ── Sparkline alias (il parent assegna via id) ──
    property alias sparkline: sparkline

    property bool cpuExpanded:          false
    property real cpuExpandProgress:    0.0
    property bool coreAnimTriggered:    false

    NumberAnimation {
        id: cpuExpandAnim
        target: metricsRoot
        property: "cpuExpandProgress"
        duration: 300
        easing.type: Easing.OutQuad
        onFinished: {
            if (metricsRoot.cpuExpandProgress === 0) {
                metricsRoot.cpuExpanded = false
                metricsRoot.coreAnimTriggered = false
            } else {
                metricsRoot.coreAnimTriggered = true
            }
        }
    }

    property bool gpuExpanded:          false
    property real gpuExpandProgress:    0.0
    property bool gpuAnimTriggered:     false

    NumberAnimation {
        id: gpuExpandAnim
        target: metricsRoot
        property: "gpuExpandProgress"
        duration: 300
        easing.type: Easing.OutQuad
        onFinished: {
            if (metricsRoot.gpuExpandProgress === 0) {
                metricsRoot.gpuExpanded = false
                metricsRoot.gpuAnimTriggered = false
            } else {
                metricsRoot.gpuAnimTriggered = true
            }
        }
    }

    ColumnLayout {
        id: metricsLayout
        anchors.fill: parent

        // Indicatore processo selezionato
        Text {
            Layout.fillWidth: true
            visible: metricsRoot.procMode
            text: "▶ " + (metricsRoot.selectedProc ? metricsRoot.selectedProc.name.toUpperCase() : "")
            font.family: "Oxanium"
            font.pixelSize: 9
            font.letterSpacing: 2
            color: Colours.accentDanger
            elide: Text.ElideRight
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            columnSpacing: 6
            rowSpacing: 6
            visible: metricsRoot.cpuExpandProgress < 0.95 && metricsRoot.gpuExpandProgress < 0.95

            // ── ROW 0: CPU ─────────────────
            Item {
                id: cpuCard
                Layout.row: 0; Layout.column: 0
                Layout.fillWidth: true
                Layout.fillHeight: true

                CutShape {
                    anchors.fill: parent
                    fillColor: Colours.moduleBg
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!metricsRoot.cpuExpanded) {
                            if (metricsRoot.gpuExpanded) {
                                metricsRoot.gpuAnimTriggered = false
                                gpuExpandAnim.from = 1; gpuExpandAnim.to = 0
                                gpuExpandAnim.restart()
                            }
                            metricsRoot.cpuExpanded = true
                            cpuExpandAnim.from = 0; cpuExpandAnim.to = 1
                            cpuExpandAnim.restart()
                        }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    RowLayout {
                        spacing: 6
                        Rectangle { width: 3; height: 10; color: metricsRoot.cpuColor }
                        Text {
                            text: "CPU"
                            font.family: "Oxanium"
                            font.pixelSize: 10
                            font.letterSpacing: 2
                            color: metricsRoot.cpuColor
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: metricsRoot.cpuTemp.toFixed(0) + "°C"
                            font.family: "Chakra Petch"
                            font.pixelSize: 10
                            color: metricsRoot.tempColor
                        }
                    }

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: cpuPercText.implicitWidth + 8
                        implicitHeight: cpuPercText.implicitHeight

                        Text {
                            anchors.centerIn: parent
                            x: metricsRoot.glitching ? -2 : 0
                            text: cpuPercText.text
                            font: cpuPercText.font
                            color: CP.aberrationRed(metricsRoot.glitching ? 0.4 : 0)
                        }
                        Text {
                            anchors.centerIn: parent
                            x: metricsRoot.glitching ? 2 : 0
                            text: cpuPercText.text
                            font: cpuPercText.font
                            color: CP.aberrationCyan(metricsRoot.glitching ? 0.4 : 0)
                        }

                        Text {
                            id: cpuPercText
                            anchors.centerIn: parent
                            text: (metricsRoot.procMode ? parseFloat(metricsRoot.selectedProc?.cpu ?? 0).toFixed(1) : metricsRoot.cpuPerc.toFixed(1)) + "%"
                            font.family: "Rajdhani"
                            font.pixelSize: 38
                            font.weight: Font.Bold
                            color: metricsRoot.cpuColor
                            opacity: metricsRoot.cpuPerc > 90 ? metricsRoot.pulseValue : 1.0

                            layer.enabled: true
                            layer.effect: MultiEffect {
                                shadowEnabled: true
                                shadowColor: cpuPercText.color
                                shadowBlur: 0.6
                                shadowOpacity: metricsRoot.cpuPerc > 75 ? 0.5 : 0.25
                            }
                        }
                    }

                    Canvas {
                        id: sparkline
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 30

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var h = metricsRoot.cpuHistory
                            if (h.length < 2) return
                            var w = width, ht = height

                            ctx.beginPath()
                            ctx.moveTo(0, ht)
                            for (var i = 0; i < h.length; i++) {
                                var x = (i / (h.length - 1)) * w
                                var y = ht - (h[i] / 100) * ht
                                ctx.lineTo(x, y)
                            }
                            ctx.lineTo(w, ht)
                            ctx.closePath()
                            var grad = ctx.createLinearGradient(0, 0, 0, ht)
                            grad.addColorStop(0, Qt.rgba(metricsRoot.cpuColor.r, metricsRoot.cpuColor.g, metricsRoot.cpuColor.b, 0.25))
                            grad.addColorStop(1, "transparent")
                            ctx.fillStyle = grad
                            ctx.fill()

                            ctx.beginPath()
                            for (var j = 0; j < h.length; j++) {
                                var lx = (j / (h.length - 1)) * w
                                var ly = ht - (h[j] / 100) * ht
                                if (j === 0) ctx.moveTo(lx, ly)
                                else ctx.lineTo(lx, ly)
                            }
                            ctx.strokeStyle = Qt.rgba(metricsRoot.cpuColor.r, metricsRoot.cpuColor.g, metricsRoot.cpuColor.b, 0.8)
                            ctx.lineWidth = 1.5
                            ctx.stroke()
                        }
                    }
                }

                CutShape {
                    anchors.fill: parent
                    strokeColor: Colours.neonBorder(0.3)
                    strokeWidth: 1
                    inset: 0.5
                }
            }

            // ── ROW 0: GPU ─────────────────
            Item {
                id: gpuCard
                Layout.row: 0; Layout.column: 1
                Layout.fillWidth: true
                Layout.fillHeight: true

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: gpuMask
                }

                CutShape {
                    anchors.fill: parent
                    fillColor: Colours.moduleBg
                    cutTopRight: 24
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!metricsRoot.gpuExpanded) {
                            if (metricsRoot.cpuExpanded) {
                                metricsRoot.coreAnimTriggered = false
                                cpuExpandAnim.from = 1; cpuExpandAnim.to = 0
                                cpuExpandAnim.restart()
                            }
                            metricsRoot.gpuExpanded = true
                            gpuExpandAnim.from = 0; gpuExpandAnim.to = 1
                            gpuExpandAnim.restart()
                        }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    RowLayout {
                        spacing: 6
                        Rectangle { width: 3; height: 10; color: metricsRoot.gpuColor }
                        Text {
                            text: "GPU"
                            font.family: "Oxanium"
                            font.pixelSize: 10
                            font.letterSpacing: 2
                            color: metricsRoot.gpuColor
                        }
                        Text {
                            text: metricsRoot.gpuName
                            font.family: "Chakra Petch"
                            font.pixelSize: 9
                            color: Colours.textMuted
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: metricsRoot.gpuTemp.toFixed(0) + "°C"
                            font.family: "Chakra Petch"
                            font.pixelSize: 10
                            color: metricsRoot.gpuTempColor
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Canvas {
                            id: gpuArcCanvas
                            anchors.fill: parent
                            
                            property real gpuVal: metricsRoot.procMode
                                                ? parseFloat(metricsRoot.selectedProc?.gpu ?? 0)
                                                : metricsRoot.gpuPerc
                            
                            onGpuValChanged: requestPaint()
                            Component.onCompleted: requestPaint()

                            onPaint: {
                                let ctx = getContext("2d")
                                let w = width, h = height
                                ctx.clearRect(0, 0, w, h)
                                if (w <= 0 || h <= 0) return

                                let cx = w / 2, cy = h / 2
                                let r = Math.min(w / 2, h / 2) - 6
                                let lineW = 5
                                let startAngle = 0.75 * Math.PI     // 135°
                                let endAngle = 2.25 * Math.PI       // 405° (270° sweep)
                                let sweepAngle = endAngle - startAngle
                                let pct = Math.min(100, Math.max(0, gpuVal)) / 100
                                let c = metricsRoot.gpuColor

                                // Background arc
                                ctx.beginPath()
                                ctx.arc(cx, cy, r, startAngle, endAngle)
                                ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.1)
                                ctx.lineWidth = lineW
                                ctx.lineCap = "round"
                                ctx.stroke()

                                // Active arc
                                if (pct > 0) {
                                    ctx.beginPath()
                                    ctx.arc(cx, cy, r, startAngle, startAngle + sweepAngle * pct)
                                    ctx.strokeStyle = c
                                    ctx.lineWidth = lineW
                                    ctx.lineCap = "round"
                                    ctx.stroke()

                                    // Glow on tip
                                    let tipAngle = startAngle + sweepAngle * pct
                                    let tipX = cx + Math.cos(tipAngle) * r
                                    let tipY = cy + Math.sin(tipAngle) * r
                                    let glow = ctx.createRadialGradient(tipX, tipY, 0, tipX, tipY, 10)
                                    glow.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.6))
                                    glow.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0))
                                    ctx.beginPath()
                                    ctx.arc(tipX, tipY, 10, 0, 2 * Math.PI)
                                    ctx.fillStyle = glow
                                    ctx.fill()
                                }

                                // Tick marks (out)
                                for (let t = 0; t <= 4; t++) {
                                    let a = startAngle + (t / 4) * sweepAngle
                                    let inner = r - lineW / 2 + 2
                                    let outer = r - lineW / 2 + 6
                                    ctx.beginPath()
                                    ctx.moveTo(cx + Math.cos(a) * inner, cy + Math.sin(a) * inner)
                                    ctx.lineTo(cx + Math.cos(a) * outer, cy + Math.sin(a) * outer)
                                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.15)
                                    ctx.lineWidth = 1
                                    ctx.stroke()
                                }

                                // Perc at center of the arc
                                let percText = gpuVal.toFixed(1) + "%"
                                ctx.textAlign = "center"
                                ctx.textBaseLine = "middle"
                                ctx.font = "bold 28px Oxanium"
                                // Aberration
                                if (metricsRoot.glitching) {
                                    ctx.fillStyle = Qt.rgba(1, 0.1, 0.2, 0.4)
                                    ctx.fillText(percText, cx - 2, cy)
                                    ctx.fillStyle = Qt.rgba(0, 0.9, 1, 0.4)
                                    ctx.fillText(percText, cx + 2, cy)
                                }
                                ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 1)
                                ctx.fillText(percText, cx, cy)
                    
                                // "GPU" under perc
                                ctx.font = "9px Oxanium"
                                ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.4)
                                ctx.fillText("GPU", cx, cy + 18)
                            }
                        }
                    }
                    // Item {
                    //     Layout.alignment: Qt.AlignHCenter
                    //     implicitWidth: gpuPercText.implicitWidth + 8
                    //     implicitHeight: gpuPercText.implicitHeight

                    //     Text {
                    //         anchors.centerIn: parent
                    //         x: metricsRoot.glitching ? -2 : 0
                    //         text: gpuPercText.text
                    //         font: gpuPercText.font
                    //         color: CP.aberrationRed(metricsRoot.glitching ? 0.4 : 0)
                    //     }

                    //     Text {
                    //         anchors.centerIn: parent
                    //         x: metricsRoot.glitching ? 2 : 0
                    //         text: gpuPercText.text
                    //         font: gpuPercText.font
                    //         color: CP.aberrationCyan(metricsRoot.glitching ? 0.4 : 0)
                    //     }

                    //     Text {
                    //         id: gpuPercText
                    //         anchors.centerIn: parent
                    //         text: (metricsRoot.procMode ? parseFloat(metricsRoot.selectedProc?.gpu ?? 0).toFixed(1)
                    //             : metricsRoot.gpuPerc.toFixed(1)) + "%"
                    //         font.family: "Oxanium"
                    //         font.pixelSize: 38
                    //         font.weight: Font.Bold
                    //         color: metricsRoot.cpuColor
                    //         opacity: metricsRoot.gpuPerc > 0.9 ? metricsRoot.pulseValue : 1.0

                    //         layer.enabled: true
                    //         layer.effect: MultiEffect {
                    //             shadowEnabled: true
                    //             shadowColor: gpuPercText.color
                    //             shadowBlur: 0.6
                    //             shadowOpacity: metricsRoot.gpuPerc > 0.75 ? 0.5 : 0.25
                    //         }
                    //     }
                    // }

                    // Item {
                    //     Layout.fillWidth: true
                    //     Layout.fillHeight: true

                    //     Canvas {
                    //         id: gpuArcCanvas
                    //         anchors.fill: parent

                    //         property real gpuVal: metricsRoot.procMode
                    //                             ? parseFloat(metricsRoot.selectedProc?.gpu ?? 0)
                    //                             : metricsRoot.gpuPerc
                            
                    //         onGpuValChanged: requestPaint()
                    //         Component.onCompleted: requestPaint()

                    //         onPaint: {
                    //             let ctx = getContext("2d")
                    //             let w = width, h = height
                    //             ctx.clearRect(0, 0, w, h)
                    //             if (w <= 0 || h <= 0) return

                    //             // Arc from BL to BR
                    //             // Center under the card, ray = width / 2
                    //             let cx = w / 2
                    //             let r = w * 0.45
                    //             let cy = h + r * 0.1        // arc at the bottom of the card
                    //             let lineW = 4

                    //             // Clockwise arc, from right to left (going from up)
                    //             // endAngle (right) -> startAngle (left) clockwise = going by -PI/2
                    //             let leftAngle = Math.PI - 0.35              // ~2.79 rad (left)
                    //             let rightAngle = 0.35                       // ~0.35 rad (right)
                    //             let totalSweep = leftAngle - rightAngle     // arc going by upside
                    //             let pct = Math.min(100, Math.max(0, gpuVal)) / 100
                    //             let c = metricsRoot.gpuColor

                    //             // Background arc (anticlockwise: from left to right)
                    //             ctx.beginPath()
                    //             ctx.arc(cx, cy, r, leftAngle, rightAngle, false)
                    //             ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.1)
                    //             ctx.lineWidth = lineW
                    //             ctx.lineCap = "round"
                    //             ctx.stroke()

                    //             // Active arc ( from left to right)
                    //             let sweepCW = 2 * Math.PI - totalSweep
                    //             if (pct > 0) {
                    //                 let activeEnd = leftAngle + sweepCW * pct
                    //                 ctx.beginPath()
                    //                 ctx.arc(cx, cy, r, leftAngle, activeEnd, false)
                    //                 ctx.strokeStyle = c
                    //                 ctx.lineWidth = lineW
                    //                 ctx.lineCap = "round"
                    //                 ctx.stroke()

                    //                 // Glow on tip
                    //                 let tipX = cx + Math.cos(activeEnd) * r
                    //                 let tipY = cy + Math.sin(activeEnd) * r
                    //                 let glow = ctx.createRadialGradient(tipX, tipY, 0, tipX, tipY, 10)
                    //                 glow.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.6))
                    //                 glow.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0))
                    //                 ctx.beginPath()
                    //                 ctx.arc(tipX, tipY, 10, 0, 2 * Math.PI)
                    //                 ctx.fillStyle = glow
                    //                 ctx.fill()
                    //             }

                    //             // Tick marks
                    //             for (let t = 0; t <= 4; t++) {
                    //                 let a = leftAngle + (t / 4) * sweepCW
                    //                 let inner = r + lineW / 2 - 2
                    //                 let outer = r + lineW / 2 - 5
                    //                 ctx.beginPath()
                    //                 ctx.moveTo(cx + Math.cos(a) * inner, cy + Math.sin(a) * inner)
                    //                 ctx.lineTo(cx + Math.cos(a) * outer, cy + Math.sin(a) * outer)
                    //                 ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.15)
                    //                 ctx.lineWidth = 1
                    //                 ctx.stroke()
                    //             }
                    //         }
                    //     }
                    // }
                }

                CutShape {
                    id: gpuMask
                    visible: false
                    layer.enabled: true
                    fillColor: "white"
                    anchors.fill: parent
                    cutTopRight: 24
                }

                CutShape {
                    anchors.fill: parent
                    strokeColor: Colours.neonBorder(0.3)
                    strokeWidth: 1
                    inset: 0.5
                    cutTopRight: 24
                }
            }

            // ── ROW 1: DISK ────────────────
            Item {
                Layout.row: 1; Layout.column: 0
                Layout.fillWidth: true
                Layout.fillHeight: true

                CutShape {
                    anchors.fill: parent
                    fillColor: Colours.moduleBg
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    RowLayout {
                        spacing: 6
                        Rectangle { width: 3; height: 10; color: Colours.accentPrimary }
                        Text {
                            text: "DISK"
                            font.family: "Oxanium"
                            font.pixelSize: 10
                            font.letterSpacing: 2
                            color: Colours.accentPrimary
                        }
                    }

                    Text {
                        text: (metricsRoot.diskPerc).toFixed(1) + "%"
                        font.family: "Rajdhani"
                        font.pixelSize: 32
                        font.weight: Font.Bold
                        color: Colours.accentPrimary
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6

                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(Colours.accentPrimary.r, Colours.accentPrimary.g, Colours.accentPrimary.b, 0.15)
                        }
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * (metricsRoot.diskPerc / 100)
                            color: Colours.accentPrimary

                            Behavior on width { Anim { duration: 600 } }
                        }
                    }

                    Text {
                        text: metricsRoot.diskUsedGb.toFixed(0) + " / " + metricsRoot.diskTotalGb.toFixed(0) + " GB"
                        font.family: "Chakra Petch"
                        font.pixelSize: 10
                        color: Colours.textSecondary
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Item { Layout.fillHeight: true }
                }

                CutShape {
                    anchors.fill: parent
                    strokeColor: Colours.neonBorder(0.3)
                    strokeWidth: 1
                    inset: 0.5
                }
            }

            // ── ROW 1: MEMORY ──────────────
            Item {
                Layout.row: 1; Layout.column: 1
                Layout.fillWidth: true
                Layout.fillHeight: true

                CutShape {
                    anchors.fill: parent
                    fillColor: Colours.moduleBg
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    RowLayout {
                        spacing: 6
                        Rectangle { width: 3; height: 10; color: metricsRoot.memColor }
                        Text {
                            text: "MEMORY"
                            font.family: "Oxanium"
                            font.pixelSize: 10
                            font.letterSpacing: 2
                            color: metricsRoot.memColor
                        }
                    }

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: memPercText.implicitWidth + 8
                        implicitHeight: memPercText.implicitHeight

                        Text {
                            anchors.centerIn: parent
                            x: metricsRoot.glitching ? -2 : 0
                            text: memPercText.text
                            font: memPercText.font
                            color: CP.aberrationRed(metricsRoot.glitching ? 0.4 : 0)
                        }
                        Text {
                            anchors.centerIn: parent
                            x: metricsRoot.glitching ? 2 : 0
                            text: memPercText.text
                            font: memPercText.font
                            color: CP.aberrationCyan(metricsRoot.glitching ? 0.4 : 0)
                        }

                        Text {
                            id: memPercText
                            anchors.centerIn: parent
                            text: (metricsRoot.procMode ? parseFloat(metricsRoot.selectedProc?.mem ?? 0).toFixed(1) : metricsRoot.memPerc.toFixed(1)) + "%"
                            font.family: "Rajdhani"
                            font.pixelSize: 32
                            font.weight: Font.Bold
                            color: metricsRoot.memColor
                            opacity: metricsRoot.memPerc > 0.9 ? metricsRoot.pulseValue : 1.0

                            layer.enabled: true
                            layer.effect: MultiEffect {
                                shadowEnabled: true
                                shadowColor: memPercText.color
                                shadowBlur: 0.6
                                shadowOpacity: metricsRoot.memPerc > 0.8 ? 0.5 : 0.25
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6

                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(metricsRoot.memColor.r, metricsRoot.memColor.g, metricsRoot.memColor.b, 0.15)
                        }
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * (metricsRoot.memPerc / 100)
                            color: metricsRoot.memColor

                            Behavior on width { Anim { duration: 400 } }
                        }
                    }

                    Text {
                        text: metricsRoot.memUsedGb.toFixed(1) + " / " + metricsRoot.memTotalGb.toFixed(1) + " GB"
                        font.family: "Chakra Petch"
                        font.pixelSize: 10
                        color: Colours.textSecondary
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: "SWAP " + metricsRoot.swapUsedGb.toFixed(1) + " / " + metricsRoot.swapTotalGb.toFixed(1) + " GB"
                        font.family: "Chakra Petch"
                        font.pixelSize: 9
                        color: Colours.textMuted
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Item { Layout.fillHeight: true }
                }

                CutShape {
                    anchors.fill: parent
                    strokeColor: Colours.neonBorder(0.3)
                    strokeWidth: 1
                    inset: 0.5
                }
            }

            // ── ROW 2: NETWORK (full width) ─
            Item {
                Layout.row: 2; Layout.column: 0; Layout.columnSpan: 2
                Layout.fillWidth: true
                Layout.preferredHeight: 140

                CutShape {
                    anchors.fill: parent
                    fillColor: Colours.moduleBg
                    cutBottomLeft: 24
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    RowLayout {
                        spacing: 6
                        Rectangle { width: 3; height: 10; color: Colours.accentSecondary }
                        Text {
                            text: "NETWORK"
                            font.family: "Oxanium"
                            font.pixelSize: 10
                            font.letterSpacing: 2
                            color: Colours.accentSecondary
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: metricsRoot.netStatus === "wifi" ? metricsRoot.netSsid : metricsRoot.netStatus.toUpperCase()
                            font.family: "Chakra Petch"
                            font.pixelSize: 10
                            color: metricsRoot.netStatus === "off" ? Colours.accentDanger : Colours.accentOk
                        }
                    }

                    RowLayout {
                        spacing: 14
                        Text {
                            text: "↓ " + metricsRoot.formatBytes(metricsRoot.netRxBps)
                            font.family: "Chakra Petch"
                            font.pixelSize: 12
                            color: Colours.accentSecondary
                        }
                        Text {
                            text: "↑ " + metricsRoot.formatBytes(metricsRoot.netTxBps)
                            font.family: "Chakra Petch"
                            font.pixelSize: 12
                            color: Colours.accentPrimary
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            visible: metricsRoot.netSignal !== ""
                            text: metricsRoot.netSignal + " dBm"
                            font.family: "Chakra Petch"
                            font.pixelSize: 9
                            color: Colours.textMuted
                        }
                    }
                }

                CutShape {
                    anchors.fill: parent
                    strokeColor: Colours.neonBorder(0.3)
                    strokeWidth: 1
                    inset: 0.5
                    cutBottomLeft: 24
                }
            }
        }
    }

    // ── CPU Expanded: animated overlay ────────────────────────
    Item {
        id: coreOverlay
        visible: metricsRoot.cpuExpanded
        z: 20

        // Position interpolata: from cpuCard to fullscreen
        x: (1 - metricsRoot.cpuExpandProgress) * cpuCard.x
        y: (1 - metricsRoot.cpuExpandProgress) * cpuCard.y
        width: cpuCard.width + (metricsRoot.width - cpuCard.width) * metricsRoot.cpuExpandProgress
        height: cpuCard.height + (metricsRoot.height - cpuCard.height) * metricsRoot.cpuExpandProgress

        clip: true

        CutShape {
            anchors.fill: parent
            fillColor: Colours.moduleBg
            cutBottomLeft: 10
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6
            opacity: metricsRoot.cpuExpandProgress

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "CPU CORES"
                    font.family: "Oxanium"
                    font.pixelSize: 11
                    font.letterSpacing: 2
                    color: metricsRoot.cpuColor
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: metricsRoot.cpuPerc.toFixed(1) + "%"
                    font.family: "Chakra Petch"
                    font.pixelSize: 10
                    color: metricsRoot.tempColor
                }
                Text {
                    text: "[ESC]"
                    font.family: "Oxanium"
                    font.pixelSize: 8
                    color: Colours.textMuted
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            metricsRoot.coreAnimTriggered = false
                            cpuExpandAnim.from = 1; cpuExpandAnim.to = 0
                            cpuExpandAnim.restart()
                        }
                    }
                }
            }

            // Grid core sparklines
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 4
                columnSpacing: 4
                rowSpacing: 4

                Repeater {
                    model: metricsRoot.corePercs.length

                    Item {
                        id: coreWrapper
                        required property int index

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 36

                        SparklineItem {
                            anchors.fill: parent

                            cutBottomLeft: 12
                            strokeWidth: 1
                            strokeColor: Colours.neonBorder(0.3)

                            values: {
                                void metricsRoot.cpuPerc    // trigger rebind every 2s
                                if (!metricsRoot.cpuExpanded) return []
                                return metricsRoot.coreHistories[index] || []
                            }
                            lineColor: metricsRoot.cpuColor
                            fillOpacity: 0.7
                            lineWidth: 1.5
                            label: "C" + index
                            valueText: (metricsRoot.corePercs[index] || 0).toFixed(0) + "%"
                            valueColor: (metricsRoot.corePercs[index] || 0) > 90 ? Colours.accentDanger
                                    : (metricsRoot.corePercs[index] || 0) > 75 ? Colours.accentWarn
                                    : metricsRoot.cpuColor
                            labelColor: Colours.textMuted
                            bgColor: Qt.rgba(0, 0, 0, 0.3)
                        }

                        property bool _animDone: false

                        opacity: _animDone ? 1 : 0
                        scale: _animDone ? 1.0 : 0.2

                        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InQuad } }
                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

                        Timer {
                            interval: index * 100
                            running: metricsRoot.coreAnimTriggered
                            repeat: false
                            onTriggered: coreWrapper._animDone = true
                        }

                        Connections {
                            target: metricsRoot
                            function onCoreAnimTriggeredChanged() {
                                if (!metricsRoot.coreAnimTriggered) _animDone = false
                            }
                        }
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

    // GPU Expanded: animated overaly
    Item {
        id: gpuOverlay
        visible: metricsRoot.gpuExpanded
        z: 20

        x: (1 - metricsRoot.gpuExpandProgress) * gpuCard.x
        y: (1 - metricsRoot.gpuExpandProgress) * gpuCard.y
        width: gpuCard.width + (metricsRoot.width - gpuCard.width) * metricsRoot.gpuExpandProgress
        height: gpuCard.height + (metricsRoot.height - gpuCard.height) * metricsRoot.gpuExpandProgress

        clip: true

        CutShape {
            anchors.fill: parent
            fillColor: Colours.moduleBg
            cutBottomLeft: 24
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 12
            opacity: metricsRoot.gpuExpandProgress

            // ── Header ────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle { width: 3; height: 14; color: metricsRoot.gpuColor }
                Text {
                    text: "GPU DETAILS"
                    font.family: "Oxanium"
                    font.pixelSize: 11
                    font.letterSpacing: 2
                    color: metricsRoot.gpuColor
                }
                Text {
                    text: metricsRoot.gpuName
                    font.family: "Chakra Petch"
                    font.pixelSize: 9
                    color: Colours.textMuted
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: metricsRoot.gpuPerc.toFixed(1) + "%"
                    font.family: "Chakra Petch"
                    font.pixelSize: 10
                    color: metricsRoot.gpuColor
                }
                Text {
                    text: metricsRoot.gpuTemp.toFixed(0) + "°C"
                    font.family: "Chakra Petch"
                    font.pixelSize: 10
                    color: metricsRoot.gpuTempColor
                }
                Text {
                    text: "[ESC]"
                    font.family: "Oxanium"
                    font.pixelSize: 8
                    color: Colours.textMuted
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            metricsRoot.gpuAnimTriggered = false
                            gpuExpandAnim.from = 1; gpuExpandAnim.to = 0
                            gpuExpandAnim.restart()
                        }
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
                    Timer { interval: 0; running: metricsRoot.gpuAnimTriggered; repeat: false; onTriggered: gpuExp0._animDone = true }
                    Connections { target: metricsRoot; function onGpuAnimTriggeredChanged() {
                        if (!metricsRoot.gpuAnimTriggered) {
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
                            text: metricsRoot.gpuVramUsedGb.toFixed(1) + " GB"
                            font.family: "Oxanium"; font.pixelSize: 26
                            font.weight: Font.Bold; color: Colours.accentPrimary
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: "/ " + metricsRoot.gpuVramTotalGb.toFixed(1) + " GB"
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
                                property real pct: metricsRoot.gpuVramTotalGb > 0 ? metricsRoot.gpuVramUsedGb / metricsRoot.gpuVramTotalGb : 0
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
                            text: (metricsRoot.gpuVramTotalGb > 0 ? (metricsRoot.gpuVramUsedGb /  metricsRoot.gpuVramTotalGb * 100).toFixed(0) : "0") + "%"
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
                    Timer { interval: 80; running: metricsRoot.gpuAnimTriggered; repeat: false; onTriggered: gpuExp1._animDone = true }
                    Connections { target: metricsRoot; function onGpuAnimTriggeredChanged() {
                        if (!metricsRoot.gpuAnimTriggered) gpuExp1._animDone = false 
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
                            text: metricsRoot.gpuPowerDraw.toFixed(1) + " W"
                            font.family: "Oxanium"; font.pixelSize: 26; font.weight: Font.Bold
                            color: Colours.accentWarn; Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: "/ " + metricsRoot.gpuPowerLimit.toFixed(0) + " W"
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
                                property real pct: metricsRoot.gpuPowerLimit > 0 ? metricsRoot.gpuPowerDraw / metricsRoot.gpuPowerLimit : 0
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
                            text: (metricsRoot.gpuPowerLimit > 0 ? (metricsRoot.gpuPowerDraw / metricsRoot.gpuPowerLimit * 100).toFixed(0) : "0") + "%"
                            font.family: "Oxanium"; font.pixelSize: 20; font.weight: Font.Bold
                            color: Colours.accentWarn; Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    CutShape { anchors.fill: parent; strokeColor: Colours.neonBorder(0.3); strokeWidth: 1; inset: 0.5 }
                }
            }

            // ── Fascia MID: Clocks + Fan ──
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
                    Timer { interval: 160; running: metricsRoot.gpuAnimTriggered; repeat: false; onTriggered: gpuExp2._animDone = true }
                    Connections { target: metricsRoot; function onGpuAnimTriggeredChanged() { if (!metricsRoot.gpuAnimTriggered) gpuExp2._animDone = false } }

                    CutShape { anchors.fill: parent; fillColor: Qt.rgba(0, 0, 0, 0.3) }
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 6; spacing: 2
                        Text { text: "GPU CLOCK"; font.family: "Oxanium"; font.pixelSize: 8; font.letterSpacing: 1.5; color: Colours.textMuted; Layout.alignment: Qt.AlignHCenter }
                        Text { text: metricsRoot.gpuClockCur + " MHz"; font.family: "Oxanium"; font.pixelSize: 18; font.weight: Font.Bold; color: Colours.accentSecondary; Layout.alignment: Qt.AlignHCenter }
                        Text { text: "MAX " + metricsRoot.gpuClockMax; font.family: "Chakra Petch"; font.pixelSize: 9; color: Colours.textMuted; Layout.alignment: Qt.AlignHCenter }
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
                    Timer { interval: 240; running: metricsRoot.gpuAnimTriggered; repeat: false; onTriggered: gpuExp3._animDone = true }
                    Connections { target: metricsRoot; function onGpuAnimTriggeredChanged() { if (!metricsRoot.gpuAnimTriggered) gpuExp3._animDone = false } }

                    CutShape { anchors.fill: parent; fillColor: Qt.rgba(0, 0, 0, 0.3) }
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 6; spacing: 2
                        Text { text: "MEM CLOCK"; font.family: "Oxanium"; font.pixelSize: 8; font.letterSpacing: 1.5; color: Colours.textMuted; Layout.alignment: Qt.AlignHCenter }
                        Text { text: metricsRoot.gpuMemClockCur + " MHz"; font.family: "Oxanium"; font.pixelSize: 18; font.weight: Font.Bold; color: Colours.accentSecondary; Layout.alignment: Qt.AlignHCenter }
                        Text { text: "MAX " + metricsRoot.gpuMemClockMax; font.family: "Chakra Petch"; font.pixelSize: 9; color: Colours.textMuted; Layout.alignment: Qt.AlignHCenter }
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
                    Timer { interval: 320; running: metricsRoot.gpuAnimTriggered; repeat: false; onTriggered: gpuExp4._animDone = true }
                    Connections { target: metricsRoot; function onGpuAnimTriggeredChanged() { if (!metricsRoot.gpuAnimTriggered) gpuExp4._animDone = false } }

                    readonly property color fanColor: metricsRoot.gpuFanSpeed > 90 ? Colours.accentDanger
                                                    : metricsRoot.gpuFanSpeed > 70 ? Colours.accentWarn
                                                    : Colours.accentOk

                    CutShape { anchors.fill: parent; fillColor: Qt.rgba(0, 0, 0, 0.3) }
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 6; spacing: 2
                        Text { text: "FAN"; font.family: "Oxanium"; font.pixelSize: 8; font.letterSpacing: 1.5; color: Colours.textMuted; Layout.alignment: Qt.AlignHCenter }
                        Text { text: metricsRoot.gpuFanSpeed + "%"; font.family: "Oxanium"; font.pixelSize: 18; font.weight: Font.Bold; color: gpuExp4.fanColor; Layout.alignment: Qt.AlignHCenter }
                    }
                    CutShape { anchors.fill: parent; strokeColor: Colours.neonBorder(0.3); strokeWidth: 1; inset: 0.5 }
                }
            }

            // ── Fascia BOTTOM: Usage bars ──
            Item {
                id: gpuExp5
                Layout.fillWidth: true
                Layout.preferredHeight: childrenRect.height

                property bool _animDone: false
                opacity: _animDone ? 1 : 0
                scale: _animDone ? 1.0 : 0.2
                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InQuad } }
                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                Timer { interval: 400; running: metricsRoot.gpuAnimTriggered; repeat: false; onTriggered: gpuExp5._animDone = true }
                Connections { target: metricsRoot; function onGpuAnimTriggeredChanged() { if (!metricsRoot.gpuAnimTriggered) gpuExp5._animDone = false } }

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
                            Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: parent.width * (metricsRoot.gpuEncoderUtil / 100); color: Colours.accentMem; Behavior on width { Anim { duration: 400 } } }
                        }
                        Text { text: metricsRoot.gpuEncoderUtil + "%"; font.family: "Oxanium"; font.pixelSize: 12; font.weight: Font.Bold; color: Colours.accentMem; Layout.preferredWidth: 35; horizontalAlignment: Text.AlignRight }
                    }

                    // Decoder bar
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text { text: "DECODER"; font.family: "Oxanium"; font.pixelSize: 10; font.letterSpacing: 1; color: Colours.textMuted; Layout.preferredWidth: 70 }
                        Item {
                            Layout.fillWidth: true; Layout.preferredHeight: 12
                            Rectangle { anchors.fill: parent; color: Qt.rgba(Colours.accentMem.r, Colours.accentMem.g, Colours.accentMem.b, 0.08) }
                            Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: parent.width * (metricsRoot.gpuDecoderUtil / 100); color: Colours.accentMem; Behavior on width { Anim { duration: 400 } } }
                        }
                        Text { text: metricsRoot.gpuDecoderUtil + "%"; font.family: "Oxanium"; font.pixelSize: 12; font.weight: Font.Bold; color: Colours.accentMem; Layout.preferredWidth: 35; horizontalAlignment: Text.AlignRight }
                    }

                    // Mem BW bar
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text { text: "MEM BW"; font.family: "Oxanium"; font.pixelSize: 10; font.letterSpacing: 1; color: Colours.textMuted; Layout.preferredWidth: 70 }
                        Item {
                            Layout.fillWidth: true; Layout.preferredHeight: 12
                            Rectangle { anchors.fill: parent; color: Qt.rgba(Colours.accentSecondary.r, Colours.accentSecondary.g, Colours.accentSecondary.b, 0.08) }
                            Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: parent.width * (metricsRoot.gpuMemBwUtil / 100); color: Colours.accentSecondary; Behavior on width { Anim { duration: 400 } } }
                        }
                        Text { text: metricsRoot.gpuMemBwUtil + "%"; font.family: "Oxanium"; font.pixelSize: 12; font.weight: Font.Bold; color: Colours.accentSecondary; Layout.preferredWidth: 35; horizontalAlignment: Text.AlignRight }
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
                Timer { interval: 480; running: metricsRoot.gpuAnimTriggered; repeat: false; onTriggered: gpuExp6._animDone = true }
                Connections { target: metricsRoot; function onGpuAnimTriggeredChanged() { if (!metricsRoot.gpuAnimTriggered) gpuExp6._animDone = false } }

                readonly property color pstateColor: {
                    let n = parseInt(metricsRoot.gpuPState.replace("P", "")) || 0
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
                            Text { text: metricsRoot.gpuPState; font.family: "Oxanium"; font.pixelSize: 11; font.weight: Font.Bold; color: gpuExp6.pstateColor }
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
                            Text { text: "GEN" + metricsRoot.gpuPcieGen + " x" + metricsRoot.gpuPcieWidth; font.family: "Oxanium"; font.pixelSize: 11; font.weight: Font.Bold; color: Colours.accentSecondary }
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
}
