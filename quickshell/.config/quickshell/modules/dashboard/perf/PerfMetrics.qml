// PerfMetrics.qml — Left column: 5 metric cards (CPU, GPU, Disk, Memory, Network)
// Requires the parent to expose PerfDataProvider properties via alias.

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import CyberGraphics
import PlasmaFX
import "../../../common/Colors.js" as CP
import "../../../common"

Item {
    id: metricsRoot

    // ── Required properties from parent ──
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

    // ── Sparkline alias (parent assigns via id) ──
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

        // Selected process indicator
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
                            font.family: "Oxanium"
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
                        font.family: "Oxanium"
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
                            font.family: "Oxanium"
                            font.pixelSize: 32
                            font.weight: Font.Bold
                            color: metricsRoot.memColor
                            opacity: metricsRoot.memPerc > 90 ? metricsRoot.pulseValue : 1.0

                            layer.enabled: true
                            layer.effect: MultiEffect {
                                shadowEnabled: true
                                shadowColor: memPercText.color
                                shadowBlur: 0.6
                                shadowOpacity: metricsRoot.memPerc > 80 ? 0.5 : 0.25
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
                            text: "↓ " + perf.formatBytes(metricsRoot.netRxBps)
                            font.family: "Chakra Petch"
                            font.pixelSize: 12
                            color: Colours.accentSecondary
                        }
                        Text {
                            text: "↑ " + perf.formatBytes(metricsRoot.netTxBps)
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

    // ── CPU Expanded: animated overlay (extracted to CpuExpandedOverlay.qml) ──
    CpuExpandedOverlay {
        visible: metricsRoot.cpuExpanded
        z: 20

        x: (1 - metricsRoot.cpuExpandProgress) * cpuCard.x
        y: (1 - metricsRoot.cpuExpandProgress) * cpuCard.y
        width: cpuCard.width + (metricsRoot.width - cpuCard.width) * metricsRoot.cpuExpandProgress
        height: cpuCard.height + (metricsRoot.height - cpuCard.height) * metricsRoot.cpuExpandProgress

        expandProgress:  metricsRoot.cpuExpandProgress
        animTriggered:   metricsRoot.coreAnimTriggered
        expanded:        metricsRoot.cpuExpanded
        cpuColor:        metricsRoot.cpuColor
        tempColor:       metricsRoot.tempColor
        cpuPerc:         metricsRoot.cpuPerc
        corePercs:       metricsRoot.corePercs
        coreHistories:   metricsRoot.coreHistories

        onCloseRequested: {
            metricsRoot.coreAnimTriggered = false
            cpuExpandAnim.from = 1; cpuExpandAnim.to = 0
            cpuExpandAnim.restart()
        }
    }

    // ── GPU Expanded: animated overlay (extracted to GpuExpandedOverlay.qml) ──
    GpuExpandedOverlay {
        visible: metricsRoot.gpuExpanded
        z: 20

        x: (1 - metricsRoot.gpuExpandProgress) * gpuCard.x
        y: (1 - metricsRoot.gpuExpandProgress) * gpuCard.y
        width: gpuCard.width + (metricsRoot.width - gpuCard.width) * metricsRoot.gpuExpandProgress
        height: gpuCard.height + (metricsRoot.height - gpuCard.height) * metricsRoot.gpuExpandProgress

        expandProgress:  metricsRoot.gpuExpandProgress
        animTriggered:   metricsRoot.gpuAnimTriggered
        gpuColor:        metricsRoot.gpuColor
        gpuTempColor:    metricsRoot.gpuTempColor
        gpuName:         metricsRoot.gpuName
        gpuPerc:         metricsRoot.gpuPerc
        gpuTemp:         metricsRoot.gpuTemp
        gpuVramUsedGb:   metricsRoot.gpuVramUsedGb
        gpuVramTotalGb:  metricsRoot.gpuVramTotalGb
        gpuClockCur:     metricsRoot.gpuClockCur
        gpuClockMax:     metricsRoot.gpuClockMax
        gpuMemClockCur:  metricsRoot.gpuMemClockCur
        gpuMemClockMax:  metricsRoot.gpuMemClockMax
        gpuPowerDraw:    metricsRoot.gpuPowerDraw
        gpuPowerLimit:   metricsRoot.gpuPowerLimit
        gpuFanSpeed:     metricsRoot.gpuFanSpeed
        gpuPState:       metricsRoot.gpuPState
        gpuPcieGen:      metricsRoot.gpuPcieGen
        gpuPcieWidth:    metricsRoot.gpuPcieWidth
        gpuEncoderUtil:  metricsRoot.gpuEncoderUtil
        gpuDecoderUtil:  metricsRoot.gpuDecoderUtil
        gpuMemBwUtil:    metricsRoot.gpuMemBwUtil

        onCloseRequested: {
            metricsRoot.gpuAnimTriggered = false
            gpuExpandAnim.from = 1; gpuExpandAnim.to = 0
            gpuExpandAnim.restart()
        }
    }
}
