import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../common/Colors.js" as CP
import "../../common"
import "perf"

Item {
    id: root

    implicitWidth:  830
    implicitHeight: 600

    // ── Backend ──────────────────────────────────────────────
    PerfDataProvider {
        id: perf
        active: root.tabActive
        sparklineCanvas: metricsPanel.sparkline
        graphView: root.graphView
    }

    // ── Aliases per accesso diretto dalla UI ──────────────────
    // (evita di scrivere "perf." ovunque per le properties più usate)
    readonly property alias cpuPerc:        perf.cpuPerc
    readonly property alias cpuTemp:        perf.cpuTemp
    readonly property alias cpuHistory:     perf.cpuHistory
    readonly property alias gpuName:        perf.gpuName
    readonly property alias gpuPerc:        perf.gpuPerc
    readonly property alias gpuTemp:        perf.gpuTemp
    readonly property alias gpuVramUsedGb:  perf.gpuVramUsedGb
    readonly property alias gpuVramTotalGb: perf.gpuVramTotalGb
    readonly property alias gpuClockCur:    perf.gpuClockCur
    readonly property alias gpuClockMax:    perf.gpuClockMax
    readonly property alias gpuMemClockCur: perf.gpuMemClockCur
    readonly property alias gpuMemClockMax: perf.gpuMemClockMax
    readonly property alias gpuPowerDraw:   perf.gpuPowerDraw
    readonly property alias gpuPowerLimit:   perf.gpuPowerLimit
    readonly property alias gpuFanSpeed:    perf.gpuFanSpeed
    readonly property alias gpuPState:      perf.gpuPState
    readonly property alias gpuPcieGen:     perf.gpuPcieGen
    readonly property alias gpuPcieWidth:   perf.gpuPcieWidth
    readonly property alias gpuEncoderUtil: perf.gpuEncoderUtil
    readonly property alias gpuDecoderUtil: perf.gpuDecoderUtil
    readonly property alias gpuMemBwUtil:   perf.gpuMemBwUtil
    readonly property alias memPerc:        perf.memPerc
    readonly property alias memUsedGb:      perf.memUsedGb
    readonly property alias memTotalGb:     perf.memTotalGb
    readonly property alias swapUsedGb:     perf.swapUsedGb
    readonly property alias swapTotalGb:    perf.swapTotalGb
    readonly property alias diskPerc:       perf.diskPerc
    readonly property alias diskUsedGb:     perf.diskUsedGb
    readonly property alias diskTotalGb:    perf.diskTotalGb
    readonly property alias netStatus:      perf.netStatus
    readonly property alias netSsid:        perf.netSsid
    readonly property alias netSignal:      perf.netSignal
    readonly property alias netRxBps:       perf.netRxBps
    readonly property alias netTxBps:       perf.netTxBps
    readonly property alias sysHostName:    perf.sysHostName
    readonly property alias sysUpTime:      perf.sysUpTime
    readonly property alias sysLoad:        perf.sysLoad
    readonly property alias cpuColor:       perf.cpuColor
    readonly property alias gpuColor:       perf.gpuColor
    readonly property alias memColor:       perf.memColor
    readonly property alias tempColor:      perf.tempColor
    readonly property alias gpuTempColor:   perf.gpuTempColor
    readonly property real  _pulseValue:    perf.pulseValue

    function formatBytes(b) { return perf.formatBytes(b) }

    // ── UI state ─────────────────────────────────────────────
    property string searchFilter:           ""
    property bool   searchOpen:             false
    property bool   graphView:              false
    property bool   graphInteraction:       false
    property int    selectedProcIndex:      -1
    property bool   _killConfirmVisible:    false
    property string _killProcName:          ""
    property bool   _glitching:             false
    property bool   tabActive:              true
    
    // Selected process for metrics
    readonly property var selectedProc: selectedProcIndex >= 0 && selectedProcIndex < filteredProcessList.length
                                        ? filteredProcessList[selectedProcIndex] : null

    // Sort mode — delegato al provider
    property alias sortMode: perf.sortMode

    // Lista filtrata
    readonly property var filteredProcessList: {
        let list = perf.processList
        if (root.searchFilter.length > 0) {
            let filtered = []
            const q = root.searchFilter.toLowerCase()
            for (let i = 0; i < list.length; i++) {
                if (list[i].name.toLowerCase().indexOf(q) >= 0) filtered.push(list[i])
            }
            list = filtered
        }
        if (root.sortMode === 1) {
            let sorted = list.slice()
            sorted.sort(function(a, b) { return parseFloat(b.mem) - parseFloat(a.mem) })
            return sorted
        }
        if (root.sortMode === 2) {
            let sorted = list.slice()
            sorted.sort(function(a, b) { return a.name.localeCompare(b.name) })
            return sorted
        }
        if (root.sortMode === 3) {
            let sorted = list.slice()
            sorted.sort(function(a, b) { return parseFloat(b.gpu) - parseFloat(a.gpu) })
            return sorted
        }
        return list
    }

    // Kill
    Connections {
        target: perf
        function onKillCompleted() {
            root._killConfirmVisible = false
            root.selectedProcIndex = -1
        }
    }

    // ── Kill handler ────────────────────────────────────────────────────
    function doKill() { perf.killProcess(root._killProcName) }

    // Glitch periodico header (ogni 5-8s)
    Timer {
        id: glitchTrigger
        interval: 6000
        running: true
        repeat: true
        onTriggered: {
            headerGlitch.restart()
            interval = 5000 + Math.floor(Math.random() * 3000)
        }
    }

    // ============
    // VISUAL LAYER
    // ============

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 6

        // ── Header Bar ────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 28

            CutShape {
                anchors.fill: parent
                fillColor: Colours.moduleBg
                cutTopLeft: 12
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                // Indicatore + title
                Rectangle {
                    width: 3; height: 14
                    color: Colours.accentSecondary
                    Layout.alignment: Qt.AlignVCenter
                }
                Item {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: headerLabel.implicitWidth
                    implicitHeight: headerLabel.implicitHeight

                    // red aberration
                    Text {
                        text: headerLabel.text
                        font: headerLabel.font
                        color: CP.aberrationRed(root._glitching ? 0.55 : 0)
                        x: root._glitching ? -2 : 0
                    }

                    // Cyan aberration
                    Text {
                        text: headerLabel.text
                        font: headerLabel.font
                        color: CP.aberrationCyan(root._glitching ? 0.55 : 0)
                        x: root._glitching ? 2 : 0
                    }

                    // Main text
                    Text {
                        id: headerLabel
                        text: "SYSTEM DIAGNOSTICS"
                        font.family: "Oxanium"
                        font.pixelSize: 11
                        font.letterSpacing: 2
                        color: Colours.accentSecondary
                        transform: Translate { id: headerShift }
                    }

                    GlitchAnim {
                        id: headerGlitch
                        labelTarget: headerLabel
                        shiftTarget: headerShift
                        baseColor: Colours.accentSecondary
                        aberrationTarget: root
                    }

                    HoverHandler {
                        onHoveredChanged: if (hovered) headerGlitch.restart()
                    }
                }

                Item { Layout.fillWidth: true }

                // Hostname
                Text {
                    text: root.sysHostName
                    font.family: "Chakra Petch"
                    font.pixelSize: 10
                    font.letterSpacing: 1
                    color: Colours.textSecondary
                    Layout.alignment: Qt.AlignVCenter
                }

                // Separator
                Rectangle { width: 1; height: 12; color: Colours.neonBorder(0.2); Layout.alignment: Qt.AlignVCenter }

                // Uptime
                Text {
                    text: "UP " + root.sysUpTime
                    font.family: "Chakra Petch"
                    font.pixelSize: 10
                    font.letterSpacing: 1
                    color: Colours.textSecondary
                    Layout.alignment: Qt.AlignVCenter
                }

                // Separator
                Rectangle { width: 1; height: 12; color: Colours.neonBorder(0.2); Layout.alignment: Qt.AlignVCenter }

                // Load average
                Text {
                    text: "LOAD " + root.sysLoad
                    font.family: "Chakra Petch"
                    font.pixelSize: 10
                    font.letterSpacing: 1
                    color: Colours.textSecondary
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            CutShape {
                anchors.fill: parent
                strokeColor: Colours.neonBorder(0.3)
                strokeWidth: 1
                inset: 0.5
                cutTopRight: 12
            }
        }

        // ── MAIN BODY: metriche (sx) + processes (dx) ────────
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            // ══ LEFT COLUMN — METRICHE ══
            PerfMetrics {
                id: metricsPanel
                Layout.preferredWidth: 380
                Layout.maximumWidth: 380
                Layout.fillHeight: true

                cpuPerc: root.cpuPerc; cpuTemp: root.cpuTemp; cpuHistory: root.cpuHistory
                gpuName: root.gpuName
                gpuPerc: root.gpuPerc; gpuTemp: root.gpuTemp
                gpuVramUsedGb: root.gpuVramUsedGb; gpuVramTotalGb: root.gpuVramTotalGb
                gpuClockCur: root.gpuClockCur; gpuClockMax: root.gpuClockMax
                gpuMemClockCur: root.gpuMemClockCur; gpuMemClockMax: root.gpuMemClockMax
                gpuPowerDraw: root.gpuPowerDraw; gpuPowerLimit: root.gpuPowerLimit
                gpuFanSpeed: root.gpuFanSpeed; gpuPState: root.gpuPState
                gpuPcieGen: root.gpuPcieGen; gpuPcieWidth: root.gpuPcieWidth
                gpuEncoderUtil: root.gpuEncoderUtil; gpuDecoderUtil: root.gpuDecoderUtil
                gpuMemBwUtil: root.gpuMemBwUtil
                memPerc: root.memPerc; memUsedGb: root.memUsedGb; memTotalGb: root.memTotalGb
                swapUsedGb: root.swapUsedGb; swapTotalGb: root.swapTotalGb
                diskPerc: root.diskPerc; diskUsedGb: root.diskUsedGb; diskTotalGb: root.diskTotalGb
                netStatus: root.netStatus; netSsid: root.netSsid; netSignal: root.netSignal
                netRxBps: root.netRxBps; netTxBps: root.netTxBps
                cpuColor: root.cpuColor; gpuColor: root.gpuColor; memColor: root.memColor
                tempColor: root.tempColor; gpuTempColor: root.gpuTempColor
                pulseValue: root._pulseValue; glitching: root._glitching
                selectedProc: root.selectedProc
                corePercs: perf.corePercs; coreHistories: perf.coreHistories
            }

            // ══ RIGHT COLUMN — PROCESSES ══
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: procMask
                }

                CutShape {
                    anchors.fill: parent
                    fillColor: Colours.moduleBg
                    cutTopRight: 10
                    cutBottomLeft: 24
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    // Processes headers
                    RowLayout {
                        spacing: 8

                        Rectangle { width: 3; height: 10; color: Colours.accentSecondary }
                        Text {
                            text: "TOP PROCESSES"
                            font.family: "Oxanium"
                            font.pixelSize: 10
                            font.letterSpacing: 2
                            color: Colours.accentSecondary
                        }

                        // Search field - icon + input animated
                        Item {
                            Layout.preferredWidth: root.searchOpen ? 130 : 22
                            Layout.preferredHeight: 20

                            Behavior on Layout.preferredWidth {
                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }

                            // Search icon (always visible)
                            Rectangle {
                                id: searchIcon
                                width: 22; height: 18
                                color: searchIconMa.containsMouse
                                    ? Qt.rgba(Colours.accentSecondary.r, Colours.accentSecondary.g, Colours.accentSecondary.b, 0.15)
                                    : "transparent"
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "⌕"
                                    font.pixelSize: 24
                                    color: root.searchOpen ? Colours.accentSecondary : Colours.textMuted
                                }

                                MouseArea {
                                    id: searchIconMa
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.searchOpen) {
                                            searchInput.text = ""
                                            root.searchOpen = false
                                        } else {
                                            root.searchOpen = true
                                            searchEntryAnim.restart()
                                            searchInput.forceActiveFocus()
                                        }
                                    }
                                }
                            }

                            // Input field with chromatic aberration incoming
                            Item {
                                id: searchFieldWrapper
                                anchors.left: searchIcon.right
                                anchors.right: parent.right
                                height: 20
                                visible: root.searchOpen
                                clip: true
                                opacity: root.searchOpen ? 1 : 0

                                Behavior on opacity {
                                    NumberAnimation { duration: 150 }
                                }

                                // Layer cyan (convergence aberration)
                                Text {
                                    anchors.verticalCenter: parent.verticalCentere
                                    x: 6
                                    text: searchInput.text || "SEARCH..."
                                    font.family: "Chakra Petch"
                                    font.pixelSize: 10
                                    color: CP.aberrationCyan(0.5)
                                    visible: searchEntryAnim.running
                                    transform: Translate { id: abCyanShift; x: 0 }
                                }

                                // Layer red (aberrazione convergenza)
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: 6
                                    text: searchInput.text || "SEARCH..."
                                    font.family: "Chakra Petch"
                                    font.pixelSize: 10
                                    color: CP.aberrationRed(0.5)
                                    visible: searchEntryAnim.running
                                    transform: Translate { id: abRedShift; x: 0 }
                                }

                                // Sfondo input
                                Rectangle {
                                    anchors.fill: parent
                                    color: Qt.rgba(Colours.accentSecondary.r, Colours.accentSecondary.g, Colours.accentSecondary.b, 0.08)
                                }

                                TextInput {
                                    id: searchInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    verticalAlignment: TextInput.AlignVCenter
                                    font.family: "Chakra Petch"
                                    font.pixelSize: 10
                                    color: Colours.accentSecondary
                                    selectionColor: Colours.accentSecondary
                                    selectedTextColor: Colours.moduleBg
                                    clip: true
                                    onTextChanged: root.searchFilter = text

                                    Text {
                                        anchors.fill: parent
                                        verticalAlignment: Text.AlignVCenter
                                        text: "SEARCH..."
                                        font: parent.font
                                        color: Colours.textMuted
                                        visible: parent.text === ""
                                    }
                                }

                                GlitchAnim {
                                    id: searchEntryAnim
                                    converge: true
                                    leftShiftTarget: abCyanShift
                                    rightShiftTarget: abRedShift
                                    x1: 14; x2: 10; x3: 4; x4: 2
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Toggle graph view
                        Rectangle {
                            width: 22; height: 20
                            color: root.graphView
                                ? Qt.rgba(Colours.accentSecondary.r, Colours.accentSecondary.g, Colours.accentSecondary.b, 0.15)
                                : "transparent"
                            
                            Text {
                                anchors.centerIn: parent
                                text: root.graphView ? "≡" : "◎"
                                font.family: "Oxanium"
                                font.pixelSize: 12
                                color: root.graphView ? Colours.accentSecondary : Colours.textMuted
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.graphView = !root.graphView
                            }
                        }
                    }

                    // ── GRAPH VIEW ───────────────────────────────────────
                    ProcessGraph {
                        visible: root.graphView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        processList: root.filteredProcessList
                        onInteractionActive: active => root.graphInteraction = active
                        processTree: perf.processTree
                        graphActive: root.graphView && root.tabActive
                    }

                    // Column headers (clickable sort)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        visible: !root.graphView

                        Item {
                            Layout.preferredWidth: 140
                            implicitHeight: procHeaderLabel.implicitHeight

                            Text {
                                id: procHeaderLabel
                                text: "PROCESS" + (root.sortMode === 2 ? " ▼" : "")
                                font.family: "Oxanium"
                                font.pixelSize: 8
                                font.letterSpacing: 1.5
                                color: root.sortMode === 2 ? Colours.accentOk : Colours.textMuted
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.sortMode = 2
                            }
                        }

                        Item {
                            Layout.preferredWidth: 55
                            implicitHeight: cpuHeaderLabel.implicitHeight
                            Text {
                                id: cpuHeaderLabel
                                anchors.right: parent.right
                                text: (root.sortMode === 0 ? "▼ " : "") + "CPU%"
                                font.family: "Oxanium"
                                font.pixelSize: 8
                                font.letterSpacing: 1.5
                                color: root.sortMode === 0 ? Colours.accentSecondary : Colours.textMuted
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.sortMode = 0; perf.refreshProcesses() }
                            }
                        }
                        
                        Item {
                            Layout.preferredWidth: 55
                            implicitHeight: memHeaderLabel.implicitHeight
                            Text {
                                id: memHeaderLabel
                                anchors.right: parent.right
                                text: (root.sortMode === 1 ? "▼ " : "") + "MEM%"
                                font.family: "Oxanium"
                                font.pixelSize: 8
                                font.letterSpacing: 1.5
                                color: root.sortMode === 1 ? Colours.accentMem : Colours.textMuted
                                horizontalAlignment: Text.AlignRight
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.sortMode = 1; perf.refreshProcesses() }
                            }
                        }
                        
                        Item {
                            Layout.preferredWidth: 45
                            implicitHeight: gpuHeaderLabel.implicitHeight
                            Text {
                                id: gpuHeaderLabel
                                anchors.right: parent.right
                                text: (root.sortMode === 3 ? "▼ " : "") + "GPU%"
                                font.family: "Oxanium"
                                font.pixelSize: 8
                                font.letterSpacing: 1.5
                                color: root.sortMode === 3 ? Colours.accentPrimary : Colours.textMuted
                                horizontalAlignment: Text.AlignRight
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { root.sortMode = 3; perf.refreshProcesses() }
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Colours.neonBorder(0.15)
                        visible: !root.graphView
                    }

                    // Processes lines (scrollable)
                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentWidth: width
                        contentHeight: procColumn.implicitHeight
                        clip: true
                        flickableDirection: Flickable.VerticalFlick
                        boundsBehavior: Flickable.StopAtBounds
                        visible: !root.graphView

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: procListMask
                        }

                        ColumnLayout {
                            id: procColumn
                            width: parent.width
                            spacing: 2

                            Repeater {
                                model: root.filteredProcessList

                                delegate: Item {
                                    required property var modelData
                                    required property int index

                                    readonly property bool selected: root.selectedProcIndex === index

                                    Layout.fillWidth: true
                                    implicitHeight: procRowInner.implicitHeight

                                    // Selection background
                                    Rectangle {
                                        anchors.fill: parent
                                        color: selected ? Qt.rgba(Colours.accentDanger.r, Colours.accentDanger.g, Colours.accentDanger.b, 0.1) : "transparent"
                                    }

                                    // Click to select
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            root.selectedProcIndex = (root.selectedProcIndex === index) ? -1 : index
                                            procFocusItem.forceActiveFocus()
                                        }
                                    }

                                    RowLayout {
                                        id: procRowInner
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        spacing: 0

                                        Text {
                                            text: modelData.name
                                            font.family: "Chakra Petch"
                                            font.pixelSize: 11
                                            color: index === 0 ? Colours.accentSecondary : Colours.textPrimary
                                            elide: Text.ElideRight
                                            Layout.preferredWidth: 140
                                        }

                                        Text {
                                            text: modelData.cpu
                                            font.family: "Chakra Petch"
                                            font.pixelSize: 11
                                            color: parseFloat(modelData.cpu) > 50 ? Colours.accentDanger
                                                    : parseFloat(modelData.cpu) > 20 ? Colours.accentWarn
                                                    : Colours.textSecondary
                                            horizontalAlignment: Text.AlignRight
                                            Layout.preferredWidth: 55
                                        }

                                        Text {
                                            text: modelData.mem
                                            font.family: "Chakra Petch"
                                            font.pixelSize: 11
                                            color: parseFloat(modelData.mem) > 50 ? Colours.accentDanger
                                                    : parseFloat(modelData.mem) > 20 ? Colours.accentWarn
                                                    : Colours.textSecondary
                                            horizontalAlignment: Text.AlignRight
                                            Layout.preferredWidth: 55
                                        }

                                        Text {
                                            text: modelData.gpu
                                            font.family: "Chakra Petch"
                                            font.pixelSize: 11
                                            color: parseFloat(modelData.gpu) > 50 ? Colours.accentDanger
                                                : parseFloat(modelData.gpu) > 10 ? Colours.accentWarn
                                                : Colours.textSecondary
                                            horizontalAlignment: Text.AlignRight
                                            Layout.preferredWidth: 45
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 4
                                            Layout.leftMargin: 10

                                            layer.enabled: true
                                            layer.effect: MultiEffect {
                                                maskEnabled: true
                                                maskSource: procListMask
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                color: Qt.rgba(Colours.accentSecondary.r, Colours.accentSecondary.g, Colours.accentSecondary.b, 0.08)
                                            }
                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.top: parent.top
                                                anchors.bottom: parent.bottom
                                                width: parent.width * Math.min(1, parseFloat(root.sortMode === 0 ? modelData.cpu : modelData.mem) / 100)
                                                color: index === 0 ? Colours.accentSecondary
                                                        : Qt.rgba(Colours.accentSecondary.r, Colours.accentSecondary.g, Colours.accentSecondary.b, 0.5)
                                            }

                                            CutShape {
                                                id: procListMask
                                                anchors.fill: parent
                                                layer.enabled: true
                                                fillColor: "white"
                                                visible: false
                                                cutTopRight: 10
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        CutShape {
                            id: procListMask
                            anchors.fill: parent
                            layer.enabled: true
                            fillColor: "white"
                            visible: false
                            cutBottomLeft: 12
                        }
                    }
                }

                // Key handler for "K" = kill
                Item {
                    id: procFocusItem
                    focus: true
                    visible: !root.graphView
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_K && root.selectedProcIndex >= 0 && !root._killConfirmVisible) {
                            root._killProcName = root.filteredProcessList[root.selectedProcIndex].name
                            root._killConfirmVisible = true
                            event.accepted = true
                        } else if (event.key === Qt.Key_Y && root._killConfirmVisible) {
                            root.doKill()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Escape) {
                            if (root._killConfirmVisible) {
                                root._killConfirmVisible = false
                            } else {
                                root.selectedProcIndex = -1
                            }
                            event.accepted = true
                        }
                    }
                }

                // Dialog confirm kill
                Rectangle {
                    visible: root._killConfirmVisible && !root.graphView
                    anchors.centerIn: parent
                    width: killDialogContent.implicitWidth + 40
                    height: killDialogContent.implicitHeight + 30
                    color: Colours.moduleBg
                    border.width: 1
                    border.color: Colours.accentDanger
                    z: 10

                    ColumnLayout {
                        id: killDialogContent
                        anchors.centerIn: parent
                        spacing: 12

                        Text {
                            text: "TERMINATE PROCESS"
                            font.family: "Oxanium"
                            font.pixelSize: 11
                            font.letterSpacing: 2
                            color: Colours.accentDanger
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: "Kill \"" + root._killProcName + "\"?"
                            font.family: "Chakra Petch"
                            font.pixelSize: 13
                            color: Colours.textPrimary
                            Layout.alignment: Qt.AlignHCenter
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 12

                            // Confirm
                            Rectangle {
                                width: confirmLabel.implicitWidth + 24
                                height: 24
                                color: Qt.rgba(Colours.accentDanger.r, Colours.accentDanger.g, Colours.accentDanger.b, 0.2)

                                Text {
                                    id: confirmLabel
                                    anchors.centerIn: parent
                                    text: "[Y] KILL"
                                    font.family: "Oxanium"
                                    font.pixelSize: 10
                                    font.letterSpacing: 1
                                    color: Colours.accentDanger
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.doKill()
                                }
                            }

                            // Cancel
                            Rectangle {
                                width: cancelLabel.implicitWidth + 24
                                height: 24
                                color: Qt.rgba(Colours.textMuted.r, Colours.textMuted.g, Colours.textMuted.b, 0.15)

                                Text {
                                    id: cancelLabel
                                    anchors.centerIn: parent
                                    text: "[ESC] CANCEL"
                                    font.family: "Oxanium"
                                    font.pixelSize: 10
                                    font.letterSpacing: 1
                                    color: Colours.textMuted
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root._killConfirmVisible = false
                                }
                            }
                        }
                    }
                }

                CutShape {
                    id: procMask
                    anchors.fill: parent
                    layer.enabled: true
                    fillColor: "white"
                    visible: false
                    cutBottomLeft: 8
                    cutTopRight: 24
                }

                CutShape {
                    anchors.fill: parent
                    strokeColor: Colours.neonBorder(0.3)
                    strokeWidth: 1
                    inset: 0.5
                    cutTopRight: 24
                    cutBottomLeft: 24
                }
            }
        }
    }

    // ── SCANLINE OVERLAY ───────────────────────────────────
    GlitchEffect {
        Layout.fillWidth: true
        Layout.fillHeight: true
        linesEnabled: true
        linesCount: 5
        linesColor: Colours.scanlineColor
        linesMinWidth: 200
        linesMaxWidth: 600
        linesMaxOpacity: 0.12
        linesMaxPause: 6000
        linesBaseSpeed: 1200
        linesSpeedVariation: 800
    }
}