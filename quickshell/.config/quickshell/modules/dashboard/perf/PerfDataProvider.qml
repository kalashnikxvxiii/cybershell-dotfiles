// PerfDataProvider.qml — Backend dati per DashPerfTab
// Tutte le properties metriche, data providers (Timer+Process), helpers.
// Usato da DashPerfTab: PerfDataProvider { id: perf }

import Quickshell.Io
import QtQuick
import "../../../common"

Item {
    id: root
    property bool active: true

    // ── Helpers ──────────────────────────────────────────────
    function formatBytes(b) {
        if (b < 1024) return b.toFixed(0) + " B/s"
        if (b < 1048576) return (b / 1024).toFixed(1) + " KB/s"
        return (b / 1048576).toFixed(2) + " MB/s"
    }

    // ── Data properties ──────────────────────────────────────
    // CPU
    property real   cpuPerc:        0
    property real   cpuTemp:        0
    property string _cpuPrev:       ""
    property var    cpuHistory:     []
    property var    corePercs:      []      // [float] percentual per core (0-100)
    property var    coreHistories:  []      // [[float]] history for each core
    property string _corePrev:      ""      // previous state for delta

    // GPU
    property string gpuName:        ""
    property real   gpuPerc:        0
    property real   gpuTemp:        0
    property real   gpuVramUsedGb:  0
    property real   gpuVramTotalGb: 0
    property int    gpuClockCur:    0
    property int    gpuClockMax:    0
    property int    gpuMemClockCur: 0
    property int    gpuMemClockMax: 0
    property real   gpuPowerDraw:   0
    property real   gpuPowerLimit:  0
    property int    gpuFanSpeed:    0
    property string gpuPState:      ""
    property string gpuPcieGen:     ""
    property string gpuPcieWidth:   ""
    property int    gpuEncoderUtil: 0
    property int    gpuDecoderUtil: 0
    property int    gpuMemBwUtil:   0

    // RAM + Swap
    property real   memPerc:        0
    property real   memUsedGb:      0
    property real   memTotalGb:     0
    property real   swapUsedGb:     0
    property real   swapTotalGb:    0

    // Disk
    property real   diskPerc:       0
    property real   diskUsedGb:     0
    property real   diskTotalGb:    0

    // Network
    property string netStatus:  "off"
    property string netSsid:    ""
    property string netSignal:  ""
    property real   netRxBps:   0
    property real   netTxBps:   0
    property string _netPrev:   ""

    // System
    property string sysHostName:    ""
    property string sysUpTime:      ""
    property string sysLoad:        ""

    // Processes
    property int    sortMode:       0       // 0=CPU, 1=MEM, 2=NAME
    property var    processList:    []
    property var    processTree:    []

    // ── Threshold colors ────────────────────────────────────────────
    readonly property color cpuColor:   cpuPerc > 90 ? Colours.accentDanger
                                        : cpuPerc > 75 ? Colours.accentWarn
                                        : Colours.accentSecondary
    readonly property color gpuColor:   gpuPerc > 90 ? Colours.accentDanger
                                        : gpuPerc > 75 ? Colours.accentWarn
                                        : Colours.accentPrimary
    readonly property color memColor:   memPerc > 90 ? Colours.accentDanger
                                        : memPerc > 80 ? Colours.accentWarn
                                        : Colours.accentMem
    readonly property color tempColor:  cpuTemp >= 80 ? Colours.accentDanger
                                        : cpuTemp >= 60 ? Colours.accentWarn
                                        : Colours.textSecondary
    readonly property color gpuTempColor: gpuTemp >= 80 ? Colours.accentDanger
                                        : gpuTemp >= 60 ? Colours.accentWarn
                                        : Colours.textSecondary

    // ── Pulse critico ────────────────────────────────────────────
    property real _pulsePhase: 0
    readonly property real pulseValue: 0.55 + 0.45 * Math.cos(_pulsePhase)
    Timer {
        interval: 50
        running: root.active && (root.cpuPerc > 90 || root.gpuPerc > 90 || root.memPerc > 90)
        repeat: true
        onTriggered: root._pulsePhase = (root._pulsePhase + 0.1) % (2 * Math.PI)
        onRunningChanged: if (!running) root._pulsePhase = 0
    }

    // ── Sparkline callback ──────────────────────────────────────
    // Il Canvas della sparkline deve essere passato dall'esterno
    property var sparklineCanvas: null

    // ── Data providers ───────────────────────────────────────────────────

    // CPU (2s)
    Timer { interval: 2000; running: root.active; repeat: true; triggeredOnStart: true; onTriggered: cpuProc.running = true }
    Process {
        id: cpuProc
        command: ["bash", "-c",
                "awk '/^cpu/{print $2+$3+$4+$5+$6+$7+$8, $2+$3+$4+$7+$8}' /proc/stat | tr '\\n' '|' | sed 's/|$//'"]
        running: false
        stdout: SplitParser { onRead: data => {
            const lines = data.trim().split("|")
            if (lines.length < 2) return

            const prevLines = root._corePrev.split("|")

            if (prevLines.length === lines.length) {
                // Total core (index 0)
                const cur0 = lines[0].split(" ")
                const prv0 = prevLines[0].split(" ")
                const dt0 = parseInt(cur0[0]) - parseInt(prv0[0])
                const da0 = parseInt(cur0[1]) - parseInt(prv0[1])
                root.cpuPerc = dt0 > 0 ? (da0 / dt0) * 100 : 0

                let h = root.cpuHistory.slice()
                h.push(root.cpuPerc)
                if (h.length > 30) h.shift()
                root.cpuHistory = h
                if (root.sparklineCanvas && root.sparklineCanvas.visible) root.sparklineCanvas.requestPaint()

                // Per-core (indexes 1+)
                let percs = []
                let hists = root.coreHistories.length > 0 ? root.coreHistories : []
                for (let i = 1; i < lines.length; i++) {
                    const cur = lines[i].split(" ")
                    const prv = prevLines[i].split(" ")
                    const dt = parseInt(cur[0]) - parseInt(prv[0])
                    const da = parseInt(cur[1]) - parseInt(prv[1])
                    const pct = dt > 0 ? (da / dt) * 100 : 0
                    percs.push(pct)

                    if (hists.length < i) hists.push([])
                    let ch = hists[i - 1].slice()
                    ch.push(pct)
                    if (ch.length > 20) ch.shift()
                    hists[i - 1] = ch
                }
                root.corePercs = percs
                root.coreHistories = hists
            }
            root._corePrev = data.trim()

            // First sample: initialize histories with value 0 for instant rendering
            if (root.corePercs.length === 0 && lines.length > 1) {
                let percs = []
                let hists = []
                for (let i = 1; i < lines.length; i++) {
                    percs.push(0)
                    hists.push([0, 0])
                }
                root.corePercs = percs
                root.coreHistories - hists
            }
        }}
    }

    // CPU Temp (4s)
    Timer { interval: 4000; running: root.active; repeat: true; triggeredOnStart: true; onTriggered: tempProc.running = true }
    Process {
        id: tempProc
        command: ["bash", "-c", 
                "for d in /sys/class/hwmon/hwmon*; do [ \"$(cat $d/name 2>/dev/null)\" = k10temp ] && cat $d/temp1_input && exit; done; echo 0"]
        running: false
        stdout: SplitParser { onRead: data => { root.cpuTemp = (parseFloat(data.trim()) || 0) / 1000 } }
    }

    // RAM + Swap (2s)
    Timer { interval: 2000; running: root.active; repeat: true; triggeredOnStart: true; onTriggered: memProc.running = true }
    Process {
        id: memProc
        command: ["bash", "-c",
                "awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}/SwapTotal/{st=$2}/SwapFree/{sf=$2}" +
                "END{printf \"%.1f %.2f %.2f %.2f %.2f\",(t-a)/t*100,(t-a)/1024/1024,t/1024/1024,(st-sf)/1024/1024,st/1024/1024}' /proc/meminfo"]
        running: false
        stdout: SplitParser { onRead: data => {
            const p = data.trim().split(" ")
            if (p.length >= 5) {
                root.memPerc     = parseFloat(p[0]) || 0
                root.memUsedGb   = parseFloat(p[1]) || 0
                root.memTotalGb  = parseFloat(p[2]) || 0
                root.swapUsedGb  = parseFloat(p[3]) || 0
                root.swapTotalGb = parseFloat(p[4]) || 0
            }
        }}
    }

    // GPU (4s)
    Timer { interval: 4000; running: root.active; repeat: true; triggeredOnStart: true; onTriggered: gpuProc.running = true }
    Process {
        id: gpuProc
        command: ["bash", "-c",
                "if command -v nvidia-smi &>/dev/null; then " +
                "nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,name,memory.used,memory.total," +
                "clocks.current.graphics,clocks.max.graphics,clocks.current.memory,clocks.max.memory," +
                "power.draw,power.limit,fan.speed,pstate," +
                "pcie.link.gen.gpucurrent,pcie.link.width.current," +
                "utilization.encoder,utilization.decoder,utilization.memory " +
                "--format=csv,noheader,nounits | tr -d ' '; " +
                "elif [ -f /sys/class/drm/card0/device/gpu_busy_percent ]; then " +
                "p=$(cat /sys/class/drm/card0/device/gpu_busy_percent); " +
                "t=$(cat /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input 2>/dev/null | head -1); " +
                "echo \"$p,$t\"; else echo '0,0'; fi"]
        running: false
        stdout: SplitParser { onRead: data => {
            const p = data.trim().split(",")
            if (p.length >= 2) {
                root.gpuPerc = parseFloat(p[0]) || 0
                root.gpuTemp = parseFloat(p[1]) / (parseFloat(p[1]) > 200 ? 1000 : 1) || 0
            }
            if (p.length >= 18) {
                root.gpuName = p[2].replace("NVIDIAGeForce", "").replace(/(\D)(\d)/, "$1 $2")
                //root.gpuName = p[2].replace("NVIDIAGeForce", "").trim()
                root.gpuVramUsedGb = (parseFloat(p[3]) || 0) / 1024
                root.gpuVramTotalGb = (parseFloat(p[4]) || 0) /1024
                root.gpuClockCur = parseInt(p[5]) || 0
                root.gpuClockMax = parseInt(p[6]) || 0
                root.gpuMemClockCur = parseInt(p[7]) || 0
                root.gpuMemClockMax = parseInt(p[8]) || 0
                root.gpuPowerDraw = parseFloat(p[9]) || 0
                root.gpuPowerLimit = parseFloat(p[10]) || 0
                root.gpuFanSpeed = parseInt(p[11]) || 0
                root.gpuPState = p[12]
                root.gpuPcieGen = p[13]
                root.gpuPcieWidth = p[14]
                root.gpuEncoderUtil = parseInt(p[15]) || 0
                root.gpuDecoderUtil = parseInt(p[16]) || 0
                root.gpuMemBwUtil = parseInt(p[17]) || 0
            }
        }}
    }

    // Disk (10s)
    Timer { interval: 10000; running: root.active; repeat: true; triggeredOnStart: true; onTriggered: diskProc.running = true }
    Process {
        id: diskProc
        command: ["bash", "-c",
                "df / --output=pcent,used,size | awk 'NR==2{gsub(/%/,\"\",$1); printf \"%.1f %.2f %.2f\",$1,$2/1024/1024,$3/1024/1024}'"]
        running: false
        stdout: SplitParser { onRead: data => {
            const p = data.trim().split(" ")
            if (p.length >= 3) {
                root.diskPerc = parseFloat(p[0]) || 0
                root.diskUsedGb = parseFloat(p[1]) || 0
                root.diskTotalGb = parseFloat(p[2]) || 0
            }
        }}
    }

    // Network status (5s)
    Timer { interval: 5000; running: root.active; repeat: true; triggeredOnStart: true; onTriggered: netStatusProc.running = true }
    Process {
        id: netStatusProc
        command: ["bash", "-c",
                "if ip route show default 2>/dev/null | grep -q ' dev e'; then echo 'ethernet||'; " +
                "elif ip route show default 2>/dev/null | grep -q default; then " +
                "s=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2); " +
                "g=$(nmcli -t -f active.signal dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2); " +
                "echo \"wifi|${s}|${g}\"; else echo 'off||'; fi"]
        running: false
        stdout: SplitParser { onRead: data => {
            const p = data.trim().split("|")
            root.netStatus = p[0] || "off"
            root.netSsid = p[1] || ""
            root.netSignal = p[2] || ""
        }}
    }

    // Network throughput (2s)
    Timer { interval: 2000; running: root.active; repeat: true; triggeredOnStart: true; onTriggered: netThruProc.running = true }
    Process {
        id: netThruProc
        command: ["bash", "-c",
                "awk '/^ *(w|e)/{print $2,$10}' /proc/net/dev | head -1"]
        running: false
        stdout: SplitParser { onRead: data => {
            const p = data.trim().split(" ")
            if (p.length >= 2) {
                const rx = parseInt(p[0]) || 0, tx = parseInt(p[1]) || 0
                const prev = root._netPrev.split(" ")
                if (prev.length === 2) {
                    root.netRxBps = Math.max(0, (rx - parseInt(prev[0])) / 2)
                    root.netTxBps = Math.max(0, (tx - parseInt(prev[1])) / 2)
                }
                root._netPrev = rx + " " + tx
            }
        }}
    }

    // System info (5s)
    Timer { interval: 5000; running: root.active; repeat: true; triggeredOnStart: true; onTriggered: sysProc.running = true }
    Process {
        id: sysProc
        command: ["bash", "-c",
                "h=$(cat /proc/sys/kernel/hostname); s=$(cut -d. -f1 /proc/uptime); " +
                "d=$((s/86400)); hr=$(((s%86400)/3600)); m=$(((s%3600)/60)); " +
                "l=$(cut -d' ' -f1-3 /proc/loadavg); echo \"${h}|${d}D ${hr}H ${m}M|${l}\""]
        running: false
        stdout: SplitParser { onRead: data => {
            const p = data.trim().split("|")
            root.sysHostName = (p[0] || "").toUpperCase()
            root.sysUpTime = p[1] || ""
            root.sysLoad = p[2] || ""
        }}
    }

    // Top processes (3s)
    property bool graphView: false
    Timer { interval: 3000; running: root.active; repeat: true; triggeredOnStart: true; onTriggered: procProc.running = true }
    Process {
        id: procProc
        command: ["bash", "-c",
                "n=$(nproc);" +
                "gmap=$(nvidia-smi pmon -c 1 -s u 2>/dev/null | awk 'NR>2 && $2+0>0{gsub(/-/,\"0\",$4); printf \"%s=%s \", $2, $4}');" +
                "LC_ALL=C top -bn2 -d0.5 -w512 -o %" + (root.sortMode === 1 ? "MEM" : "CPU") +
                " | awk -v np=$n -v gm=\"$gmap\" 'BEGIN{s=0; n=split(gm,pairs,\" \"); for(i=1;i<=n;i++){split(pairs[i],kv,\"=\"); " +
                "gpu[kv[1]]=kv[2]}} /^top -/{s++} s==2 && $1+0>0{cmd=$12; gsub(/.*\\//,\"\",cmd);" +
                " if(cmd~/^[a-zA-Z]/ && ($9+0>0.1||$10+0>0.1)){g=($1 in gpu)?gpu[$1]:\"0\";" +
                " printf \"%s|%.1f|%.1f|%s;\",cmd,$9/np,$10+0,g}}'"]
        running: false
        stdout: SplitParser { onRead: data => {
            let raw = data.trim()
            if (raw.endsWith(";")) raw = raw.slice(0, -1)
            if (raw.length === 0) return
            const entries = raw.split(";")
            let list = []
            for (let i = 0; i < entries.length; i++) {
                const p = entries[i].split("|")
                if (p.length >= 3) list.push({name: p[0], cpu: p[1], mem: p[2], gpu: p[3] || "0"})
            }
            root.processList = list
        }}
    }

    // Albero processi completi per grafo (ogni 3s)
    Timer { interval: 3000; running: root.active && root.graphView; repeat: true; triggeredOnStart: true; onTriggered: treeProc.running = true }
    Process {
        id: treeProc
        command: ["bash", "-c",
                "n=$(nproc);" +
                "LC_ALL=C ps -eo pid,ppid,pcpu,pmem,comm --no-headers | " +
                "awk -v np=$n '$2!=2 && $5!=\"ps\" && $5!=\"awk\" && ($3+0>0.0||$4+0>0.1)" +
                "{printf \"%d:%d:%s:%.1f:%.1f;\", $1, $2, $5, $3/np, $4}'"]
        running: false
        stdout: SplitParser { onRead: data => {
            let raw = data.trim()
            if (raw.endsWith(";")) raw = raw.slice(0, -1)
            if (raw.length === 0) return
            let entries = raw.split(";")
            let list = []
            for (let i = 0; i < entries.length; i++) {
                let p = entries[i].split(":")
                if (p.length >= 5) list.push({
                    pid: parseInt(p[0]), ppid: parseInt(p[1]),
                    name: p[2], cpu: parseFloat(p[3]), mem: parseFloat(p[4])
                })
            }
            root.processTree = list
        }}
    }

    // ── Kill process ─────────────────────────────────────────────
    property string killProcName: ""
    signal killCompleted()

    Process {
        id: killProc
        command: ["pkill", "-f", root.killProcName]
        running: false
        onExited: {
            root.killProcName = ""
            procProc.running = true
            root.killCompleted()
        }
    }

    function killProcess(name) {
        root.killProcName = name
        killProc.running = true
    }

    function refreshProcesses() {
        procProc.running = true
    }
}
