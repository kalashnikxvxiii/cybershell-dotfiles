// DashPerfTab.qml -- the CYBERWARE tab, drawn as a ripperdoc's table: gauges on the sides, core
// array, memory, network, processes. Click a core or GPU slot for its detail, a process to select
// it (gauges and slots then follow it); K or FORCE KILL arms the kill, Y or a second click fires.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../common"
import "../../common/effects"
import "perf"

Item {
    id: root

    implicitWidth: 830
    implicitHeight: 600

    property bool tabActive: true
    // Read by DashboardContent: dragging in the graph must not swipe the tabs
    property bool graphInteraction: false
    property bool graphView: false
    property string searchFilter: ""
    property bool searchOpen: false
    property string selectedPid: ""
    property bool killArmed: false
    // "", "cpu" or "gpu"
    property string detail: ""
    property real detailProgress: 0

    // The selected one on top, and gone with its process
    readonly property var selectedProc: perf.processList.find(p => p.pid === root.selectedPid) ?? null
    readonly property bool procMode: selectedProc !== null
    readonly property var filteredProcessList: {
        const q = root.searchFilter.toLowerCase()
        let list = perf.processList.filter(p => p.name.toLowerCase().indexOf(q) >= 0)
        const num = key => (a, b) => parseFloat(b[key]) - parseFloat(a[key])
        if (perf.sortMode === 1) list.sort(num("mem"))
        else if (perf.sortMode === 2) list.sort((a, b) => a.name.localeCompare(b.name))
        else if (perf.sortMode === 3) list.sort(num("gpu"))
        else if (perf.sortMode === 4) list.sort(num("net"))
        return list
    }
    readonly property var rows: root.selectedProc
        ? [root.selectedProc].concat(root.filteredProcessList.filter(p => p.pid !== root.selectedPid))
        : root.filteredProcessList

    readonly property real shownCpu: procMode ? parseFloat(selectedProc.cpu) : perf.cpuPerc
    readonly property real shownMem: procMode ? parseFloat(selectedProc.mem) : perf.memPerc
    readonly property real shownGpu: procMode ? parseFloat(selectedProc.gpu) : perf.gpuPerc

    onSelectedProcChanged: if (!selectedProc) killArmed = false
    onTabActiveChanged: if (!tabActive) killArmed = false

    PerfDataProvider {
        id: perf
        active: root.tabActive
        graphView: root.graphView
    }

    function select(pid) {
        root.selectedPid = root.selectedPid === pid ? "" : pid
        root.killArmed = false
        flick.contentY = 0
        focusItem.forceActiveFocus()
    }

    function kill() {
        if (!root.killArmed) {
            root.killArmed = root.selectedProc !== null
            return
        }
        perf.killPid(root.selectedPid)
        root.selectedPid = ""
    }

    function setSort(mode) {
        perf.sortMode = mode
        perf.refreshProcesses()
    }

    function openDetail(which) {
        root.detail = which
        detailAnim.from = 0
        detailAnim.to = 1
        detailAnim.restart()
    }
    function closeDetail() {
        detailAnim.from = 1
        detailAnim.to = 0
        detailAnim.restart()
    }
    NumberAnimation {
        id: detailAnim
        target: root
        property: "detailProgress"
        duration: 260
        easing.type: Easing.OutQuad
        onFinished: if (root.detailProgress === 0) root.detail = ""
    }

    Item {
        id: focusItem
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_K && root.selectedProc && !root.killArmed)
                root.kill()
            else if (event.key === Qt.Key_Y && root.killArmed)
                root.kill()
            else if (event.key === Qt.Key_Escape) {
                if (root.killArmed) root.killArmed = false
                else root.selectedPid = ""
            } else
                return
            event.accepted = true
        }
    }

    // Header
    Row {
        x: 12
        y: 4
        spacing: 16
        Figure { value: root.shownCpu; unit: "CPU"; tone: HudState.power }
        Figure { value: root.shownMem; unit: "MEM"; tone: HudState.tech }
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 11
        width: 300
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: root.procMode ? "▶ " + root.selectedProc.name.toUpperCase() : "SYSTEM DIAGNOSTICS"
        color: root.procMode ? HudState.danger : HudState.tech
        font { family: HudState.font; pixelSize: 11; letterSpacing: 2 }
    }
    Column {
        anchors.right: parent.right
        anchors.rightMargin: 12
        y: 2
        spacing: 0
        Text {
            anchors.right: parent.right
            text: Math.round(perf.cpuTemp) + "°C   GPU " + Math.round(perf.gpuTemp) + "°C   "
                + perf.memUsedGb.toFixed(1) + "/" + perf.memTotalGb.toFixed(1) + "G"
            color: HudState.power
            font { family: HudState.font; pixelSize: 12; bold: true }
        }
        Text {
            anchors.right: parent.right
            text: perf.sysHostName.toUpperCase() + "   UP " + perf.sysUpTime.toUpperCase() + "   LOAD " + perf.sysLoad
            color: HudState.alpha(HudState.paper, 0.45)
            font { family: HudState.font; pixelSize: 9; letterSpacing: 1 }
        }
    }
    Rectangle {
        x: 12
        y: 34
        width: parent.width - 24
        height: 1
        color: HudState.alpha(HudState.danger, 0.6)
    }

    Ladder {
        x: 10
        y: 46
        height: parent.height - 52
        value: root.shownCpu / 100
        tone: HudState.power
        caption: "CPU"
    }
    Ladder {
        x: parent.width - 10 - width
        y: 46
        height: parent.height - 52
        value: root.shownMem / 100
        tone: HudState.tech
        caption: "MEM"
        flip: true
    }

    Item {
        id: body
        x: 68
        y: 42
        width: parent.width - 136
        height: parent.height - 46

        ColumnLayout {
            anchors.fill: parent
            spacing: 3
            // The detail views have no opaque fill of their own
            visible: root.detailProgress < 1

            Section { label: "CORE ARRAY" }
            Row {
                spacing: 4
                Repeater {
                    model: perf.corePercs
                    Slot {
                        required property var modelData
                        required property int index
                        width: (body.width - 4 * (perf.corePercs.length - 1)) / perf.corePercs.length
                        height: 34
                        label: "C" + index
                        val: Math.round(modelData) + "%"
                        frac: modelData / 100
                        tone: modelData > 80 ? HudState.danger : HudState.power
                        onClicked: root.openDetail("cpu")
                    }
                }
            }

            Section {
                visible: !root.graphView
                Layout.topMargin: 4
                label: "MEMORY // GPU // STORAGE"
            }
            Row {
                visible: !root.graphView
                spacing: 4
                readonly property real slotWidth: (body.width - 16) / 5
                Slot {
                    width: parent.slotWidth
                    height: 38
                    label: "USED"
                    val: perf.memUsedGb.toFixed(1) + "G"
                    frac: perf.memPerc / 100
                    tone: HudState.tech
                }
                Slot {
                    width: parent.slotWidth
                    height: 38
                    label: "SWAP"
                    val: perf.swapUsedGb.toFixed(1) + "G"
                    frac: perf.swapTotalGb > 0 ? perf.swapUsedGb / perf.swapTotalGb : 0
                    tone: HudState.tech
                }
                Slot {
                    width: parent.slotWidth
                    height: 38
                    label: "VRAM"
                    val: perf.gpuVramUsedGb.toFixed(1) + "G"
                    frac: perf.gpuVramTotalGb > 0 ? perf.gpuVramUsedGb / perf.gpuVramTotalGb : 0
                    tone: HudState.mem
                    onClicked: root.openDetail("gpu")
                }
                Slot {
                    width: parent.slotWidth
                    height: 38
                    label: "GPU"
                    val: Math.round(root.shownGpu) + "%"
                    frac: root.shownGpu / 100
                    tone: HudState.ok
                    onClicked: root.openDetail("gpu")
                }
                Slot {
                    width: parent.slotWidth
                    height: 38
                    label: "DISK /"
                    val: perf.diskUsedGb.toFixed(0) + "G"
                    frac: perf.diskPerc / 100
                    tone: perf.diskPerc > 90 ? HudState.danger : HudState.power
                }
            }

            NetworkCard {
                visible: !root.graphView
                Layout.topMargin: 3
                Layout.fillWidth: true
                Layout.preferredHeight: 136
                provider: perf
                netStatus: perf.netStatus
                netSsid: perf.netSsid
                netSignal: perf.netSignal
                netRxBps: perf.netRxBps
                netTxBps: perf.netTxBps
                netHistory: perf.netHistory
            }

            // Title row: search, graph, kill
            Item {
                Layout.fillWidth: true
                Layout.topMargin: 3
                Layout.preferredHeight: 22

                Section {
                    anchors.verticalCenter: parent.verticalCenter
                    label: "PROC_LIST"
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Item {
                        visible: root.searchOpen
                        width: 130
                        height: 20
                        Rectangle {
                            anchors.fill: parent
                            color: HudState.alpha(HudState.tech, 0.08)
                            border.color: HudState.alpha(HudState.tech, 0.4)
                        }
                        TextInput {
                            id: searchInput
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            color: HudState.tech
                            font { family: HudState.font; pixelSize: 10 }
                            onTextChanged: root.searchFilter = text
                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                visible: parent.text === ""
                                text: "SEARCH..."
                                color: HudState.alpha(HudState.paper, 0.4)
                                font: parent.font
                            }
                        }
                    }
                    ToolButton {
                        glyph: ""
                        on: root.searchOpen
                        onClicked: {
                            root.searchOpen = !root.searchOpen
                            if (root.searchOpen) {
                                searchInput.forceActiveFocus()
                            } else {
                                searchInput.text = ""
                                focusItem.forceActiveFocus()
                            }
                        }
                    }
                    ToolButton {
                        glyph: root.graphView ? "" : ""
                        on: root.graphView
                        onClicked: root.graphView = !root.graphView
                    }
                    CutShape {
                        visible: !root.graphView
                        width: 150
                        height: 20
                        cutTopRight: 6
                        cutBottomLeft: 6
                        fillColor: HudState.alpha(HudState.danger, !root.procMode ? 0.08 : root.killArmed || killHit.containsMouse ? 0.5 : 0.28)
                        strokeColor: HudState.danger
                        inset: 0.5
                        Text {
                            anchors.centerIn: parent
                            text: !root.procMode ? "SELECT A PROC"
                                : root.killArmed ? "[Y] CONFIRM KILL" : "[K] FORCE KILL"
                            color: HudState.paper
                            font { family: HudState.font; pixelSize: 10; bold: true; letterSpacing: 1 }
                        }
                        MouseArea {
                            id: killHit
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: root.procMode
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.kill()
                        }
                    }
                }
            }

            ProcessGraph {
                visible: root.graphView
                Layout.fillWidth: true
                Layout.fillHeight: true
                processList: root.filteredProcessList
                processTree: perf.processTree
                graphActive: root.graphView && root.tabActive
                onInteractionActive: active => root.graphInteraction = active
            }

            // Column titles: click to sort
            Item {
                visible: !root.graphView
                Layout.fillWidth: true
                Layout.preferredHeight: 12
                Sort { x: 10; label: "PROCESS"; mode: 2 }
                Sort { x: colPid; label: "PID"; mode: -1 }
                Sort { x: colCpu; label: "CPU"; mode: 0 }
                Sort { x: colMem; label: "MEM"; mode: 1 }
                Sort { x: colGpu; label: "GPU"; mode: 3 }
                Sort { x: colNet; label: "NET"; mode: 4 }
            }

            Flickable {
                id: flick
                visible: !root.graphView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: procColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: procColumn
                    width: flick.width
                    spacing: 3
                    // By count, not by array: the list refreshes every 3 s and rows should survive it
                    Repeater {
                        model: root.rows.length
                        ProcRow {}
                    }
                }
            }
        }

        // Detail views open over the whole table
        CpuExpandedOverlay {
            visible: root.detail === "cpu"
            anchors.fill: parent
            z: 20
            expandProgress: root.detailProgress
            animTriggered: root.detailProgress === 1
            expanded: root.detail === "cpu"
            cpuColor: perf.cpuColor
            tempColor: perf.tempColor
            cpuPerc: perf.cpuPerc
            corePercs: perf.corePercs
            coreHistories: perf.coreHistories
            onCloseRequested: root.closeDetail()
        }
        GpuExpandedOverlay {
            visible: root.detail === "gpu"
            anchors.fill: parent
            z: 20
            expandProgress: root.detailProgress
            animTriggered: root.detailProgress === 1
            gpuColor: perf.gpuColor
            gpuTempColor: perf.gpuTempColor
            gpuName: perf.gpuName
            gpuPerc: perf.gpuPerc
            gpuTemp: perf.gpuTemp
            gpuVramUsedGb: perf.gpuVramUsedGb
            gpuVramTotalGb: perf.gpuVramTotalGb
            gpuClockCur: perf.gpuClockCur
            gpuClockMax: perf.gpuClockMax
            gpuMemClockCur: perf.gpuMemClockCur
            gpuMemClockMax: perf.gpuMemClockMax
            gpuPowerDraw: perf.gpuPowerDraw
            gpuPowerLimit: perf.gpuPowerLimit
            gpuFanSpeed: perf.gpuFanSpeed
            gpuPState: perf.gpuPState
            gpuPcieGen: perf.gpuPcieGen
            gpuPcieWidth: perf.gpuPcieWidth
            gpuEncoderUtil: perf.gpuEncoderUtil
            gpuDecoderUtil: perf.gpuDecoderUtil
            gpuMemBwUtil: perf.gpuMemBwUtil
            onCloseRequested: root.closeDetail()
        }
    }

    readonly property int colPid: 330
    readonly property int colCpu: 400
    readonly property int colMem: 460
    readonly property int colGpu: 520
    readonly property int colNet: 580

    component Figure: Row {
        id: figure
        property real value
        property string unit
        property color tone
        spacing: 5
        Text {
            text: Math.round(figure.value)
            color: figure.tone
            font { family: HudState.font; pixelSize: 20; bold: true }
        }
        Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3
            text: figure.unit
            color: figure.tone
            font { family: HudState.font; pixelSize: 10; letterSpacing: 1 }
        }
    }

    component Section: Text {
        property string label
        text: "◢ " + label
        color: HudState.danger
        font { family: HudState.font; pixelSize: 10; bold: true; letterSpacing: 1 }
    }

    // Vertical gauge: a stack of bars that flare out towards the value's flag
    component Ladder: Item {
        id: ladder
        property real value: 0
        property color tone
        property string caption
        property bool flip: false
        readonly property int bars: Math.max(0, Math.floor((height - 16) / 5))
        readonly property int level: Math.round(Math.min(1, value) * bars)
        width: 50

        Column {
            width: parent.width
            spacing: 2
            Repeater {
                model: ladder.bars
                Rectangle {
                    required property int index
                    readonly property int fromBottom: ladder.bars - index
                    readonly property int off: Math.abs(fromBottom - ladder.level)
                    x: ladder.flip ? parent.width - width : 0
                    width: 15 + Math.max(0, 3 - off) * 7
                    height: 3
                    color: fromBottom <= ladder.level ? ladder.tone : HudState.alpha(ladder.tone, 0.14)
                }
            }
        }
        Rectangle {
            x: ladder.flip ? 0 : parent.width - width
            y: (ladder.bars - ladder.level) * 5 - 6
            width: 26
            height: 15
            color: ladder.tone
            Text {
                anchors.centerIn: parent
                text: Math.round(ladder.value * 100)
                color: "#140a00"
                font { family: HudState.font; pixelSize: 10; bold: true }
            }
        }
        Text {
            x: ladder.flip ? parent.width - width : 0
            anchors.bottom: parent.bottom
            text: ladder.caption
            color: ladder.tone
            font { family: HudState.font; pixelSize: 9; letterSpacing: 1 }
        }
    }

    component Slot: CutShape {
        id: slot
        property string label
        property string val
        property real frac: 0
        property color tone
        signal clicked()
        cutTopRight: 6
        cutBottomLeft: 6
        fillColor: HudState.alpha(tone, slotHit.containsMouse ? 0.16 : 0.06)
        strokeColor: HudState.alpha(tone, 0.65)
        inset: 0.5

        Text {
            x: 6
            y: 3
            text: slot.label
            color: HudState.alpha(slot.tone, 0.8)
            font { family: HudState.font; pixelSize: 8; letterSpacing: 1 }
        }
        Text {
            x: 6
            y: slot.height - height - 2
            text: slot.val
            color: slot.tone
            font { family: HudState.font; pixelSize: 13; bold: true }
        }
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 5
            width: 2
            height: (parent.height - 12) * Math.min(1, Math.max(0, slot.frac))
            color: slot.tone
        }
        MouseArea {
            id: slotHit
            anchors.fill: parent
            hoverEnabled: true
            onClicked: slot.clicked()
        }
    }

    component ToolButton: CutShape {
        id: tool
        property string glyph
        property bool on: false
        signal clicked()
        width: 24
        height: 20
        cutBottomRight: 5
        fillColor: HudState.alpha(HudState.tech, on || toolHit.containsMouse ? 0.22 : 0.05)
        strokeColor: HudState.alpha(HudState.tech, 0.6)
        inset: 0.5
        Text {
            anchors.centerIn: parent
            text: tool.glyph
            color: HudState.tech
            font { family: HudState.icons; pixelSize: 11 }
        }
        MouseArea {
            id: toolHit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tool.clicked()
        }
    }

    component Sort: Text {
        id: sort
        property string label
        property int mode
        readonly property bool active: perf.sortMode === mode
        text: label + (active ? " ▼" : "")
        color: active ? HudState.tech : HudState.alpha(HudState.paper, 0.45)
        font { family: HudState.font; pixelSize: 8; letterSpacing: 1 }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -3
            enabled: sort.mode >= 0
            cursorShape: Qt.PointingHandCursor
            onClicked: root.setSort(sort.mode)
        }
    }

    component ProcRow: CutShape {
        id: proc
        required property int index
        readonly property var data_: root.rows[index] ?? ({ name: "", pid: "", cpu: "0", mem: "0", gpu: "0", net: "0" })
        readonly property bool current: data_.pid === root.selectedPid
        width: procColumn.width
        height: 25
        cutBottomRight: 6
        fillColor: current ? HudState.alpha(HudState.danger, 0.2)
            : procHit.containsMouse ? HudState.alpha(HudState.tech, 0.14) : HudState.alpha(HudState.tech, 0.04)
        strokeColor: current ? HudState.danger : HudState.alpha(HudState.tech, 0.3)
        inset: 0.5

        Text {
            x: 10
            width: root.colPid - 20
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: proc.data_.name
            color: proc.current ? HudState.paper : HudState.tech
            font { family: HudState.font; pixelSize: 12 }
        }
        Cell { x: root.colPid; text: proc.data_.pid; color: HudState.alpha(HudState.paper, 0.5) }
        Cell { x: root.colCpu; text: proc.data_.cpu; color: HudState.power }
        Cell { x: root.colMem; text: proc.data_.mem; color: HudState.tech }
        Cell { x: root.colGpu; text: proc.data_.gpu; color: HudState.ok }
        Cell {
            readonly property real rate: parseFloat(proc.data_.net)
            x: root.colNet
            text: rate > 0 ? perf.formatBytes(rate) : "0"
            color: rate > 0 ? HudState.tech : HudState.alpha(HudState.paper, 0.5)
        }

        MouseArea {
            id: procHit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.select(proc.data_.pid)
        }
    }

    component Cell: Text {
        anchors.verticalCenter: parent.verticalCenter
        font { family: HudState.font; pixelSize: 11 }
    }
}
