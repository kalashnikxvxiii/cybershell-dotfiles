// PerfDataProvider.qml — Data backend for DashPerfTab
// All metric properties, data providers (Timer+Process), helpers.
// Used by DashPerfTab: PerfDataProvider { id: perf }

import Quickshell
import Quickshell.Io
import QtQuick
import "../../../common"

Item {
    id: root
    property bool active: true

    // The last speed-test result is read once at startup so the card can show
    // it immediately, with its age, instead of looking like it never ran.
    Component.onCompleted: _speedStateFile.reload()

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
    property var    corePercs:      []      // [float] per-core percentage (0-100)
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
    // Recent throughput, newest last, as {rx, tx} pairs. Feeds the graph drawn
    // behind the network card. Sampled by the same timer as the rest of the
    // network figures, so it only fills while the tab is on screen.
    property var    netHistory: []

    // ── Speed test ───────────────────────────────────────────────────────
    // On demand only: a test saturates the link for about twenty seconds, so
    // nothing here runs unless runSpeedTest() is called.
    //
    // Figures use -1 for "not measured": a run that is cancelled or fails part
    // way keeps what it did measure, and the card has to tell a real zero
    // from a figure that never came.
    property bool   speedRunning:   false
    property bool   speedCancelled: false
    property string speedPhase:     ""     // connecting|latency|download|upload|done
    property real   speedProgress:  0      // 0..1 across the whole test
    property real   speedRate:      -1     // bit/s, live figure of the current transfer
    property real   speedDown:      -1     // bit/s
    property real   speedUp:        -1     // bit/s
    property real   speedPing:      -1     // ms, median idle round trip
    property real   speedJitter:    -1     // ms
    property real   speedLoss:      -1     // % of latency probes that timed out
    property real   speedLoaded:    -1     // ms, round trip while downloading
    property real   speedBloat:     -1     // ms, loaded minus idle
    property string speedColo:      ""     // Cloudflare edge, e.g. MXP
    property string speedVia:       ""     // interface the test left through
    property string speedWhen:      ""     // ISO timestamp of the last result
    property string speedError:     ""

    // The helper that runs the test. A property rather than a literal so the
    // parsing can be exercised against a recorded run instead of the network.
    property string speedScript: Quickshell.env("HOME")
                                 + "/.config/quickshell/scripts/speedtest-run.py"

    readonly property string _speedStatePath:
        Quickshell.env("HOME") + "/.cache/qs-perf/speedtest.json"

    // Share of the ring each phase owns, in proportion to how long it runs:
    // latency about 2 s, download and upload about 8 s each.
    function _speedOverall(phase, p) {
        switch (phase) {
        case "connecting": return 0.01
        case "latency":    return 0.01 + p * 0.09
        case "download":   return 0.10 + p * 0.45
        case "upload":     return 0.55 + p * 0.45
        case "done":       return 1.0
        }
        return root.speedProgress
    }

    function runSpeedTest() {
        if (root.speedRunning) return
        root.speedError     = ""
        root.speedCancelled = false
        root.speedPhase     = "connecting"
        root.speedProgress  = 0
        root.speedRate      = -1
        root.speedDown      = -1
        root.speedUp        = -1
        root.speedPing      = -1
        root.speedJitter    = -1
        root.speedLoss      = -1
        root.speedLoaded    = -1
        root.speedBloat     = -1
        root.speedColo      = ""
        root.speedVia       = ""
        root.speedWhen      = ""
        root.speedRunning   = true
        speedProc.running   = false
        speedProc.running   = true
    }

    function cancelSpeedTest() {
        if (!root.speedRunning) return
        root.speedRunning   = false
        root.speedCancelled = true
        // SIGTERM: the helper closes its sockets on the way out, so the link
        // is released at once rather than when the transfers would have ended.
        speedProc.running = false
        // The phase and figures are left as they were: the card keeps showing
        // whatever had already been measured, which is what a cancel preserves.
    }

    function _num(v) { return (typeof v === "number" && isFinite(v)) ? v : -1 }

    Process {
        id: speedProc
        command: ["python3", root.speedScript]
        running: false

        onExited: (code, status) => {
            // Covers the crash case too: without this the card would sit in
            // "testing" for ever if the helper died without an error event.
            if (root.speedRunning) {
                root.speedRunning = false
                if (root.speedPhase !== "done" && root.speedError === "")
                    root.speedError = "test interrupted"
            }
        }

        stdout: SplitParser {
            onRead: line => {
                var e
                try { e = JSON.parse(line) } catch (err) { return }
                if (!e || !e.phase) return
                // A cancelled run may still flush a line or two on its way out.
                if (!root.speedRunning) return

                switch (e.phase) {
                case "error":
                    root.speedError   = e.message || "unknown error"
                    root.speedRunning = false
                    return
                case "cancelled":
                    root.speedCancelled = true
                    root.speedRunning   = false
                    return
                case "latency":
                    root.speedPing = root._num(e.ms)
                    if (e.done) {
                        root.speedJitter = root._num(e.jitter)
                        root.speedLoss   = root._num(e.loss)
                    }
                    break
                case "download":
                case "upload":
                    // The done event carries the sustained figure, which then
                    // stays under the key until the next phase has a reading.
                    root.speedRate = root._num(e.done ? e.value : e.rate)
                    if (e.done) {
                        if (e.phase === "download") root.speedDown = root.speedRate
                        else                        root.speedUp   = root.speedRate
                    }
                    break
                case "done":
                    root.speedDown    = root._num(e.download)
                    root.speedUp      = root._num(e.upload)
                    root.speedPing    = root._num(e.ping)
                    root.speedJitter  = root._num(e.jitter)
                    root.speedLoss    = root._num(e.loss)
                    root.speedLoaded  = root._num(e.loaded)
                    root.speedBloat   = root._num(e.bufferbloat)
                    root.speedColo    = e.colo || ""
                    root.speedVia     = e.via || ""
                    root.speedWhen    = e.timestamp || new Date().toISOString()
                    root.speedRunning = false
                    root._saveSpeedState()
                    break
                }
                root.speedPhase    = e.phase
                root.speedProgress = root._speedOverall(e.phase, e.done ? 1 : (e.progress || 0))
            }
        }
    }

    function _saveSpeedState() {
        var d = { down: root.speedDown, up: root.speedUp, ping: root.speedPing,
                  jitter: root.speedJitter, loss: root.speedLoss,
                  loaded: root.speedLoaded, bloat: root.speedBloat,
                  colo: root.speedColo, via: root.speedVia, when: root.speedWhen }
        _speedSaveProc.command = [
            "python3", "-c",
            "import sys,os,json; os.makedirs(os.path.dirname(sys.argv[1]), exist_ok=True); open(sys.argv[1], 'w').write(sys.argv[2])",
            root._speedStatePath,
            JSON.stringify(d)
        ]
        _speedSaveProc.running = false
        _speedSaveProc.running = true
    }

    property var _speedSaveProc: Process { command: ["true"]; running: false }

    property var _speedStateFile: FileView {
        path: root._speedStatePath
        onLoaded: {
            try {
                var d = JSON.parse(text())
                // Fields missing from a file written by the old helper read
                // as not measured rather than as zero.
                root.speedDown   = root._num(d.down)
                root.speedUp     = root._num(d.up)
                root.speedPing   = root._num(d.ping)
                root.speedJitter = root._num(d.jitter)
                root.speedLoss   = root._num(d.loss)
                root.speedLoaded = root._num(d.loaded)
                root.speedBloat  = root._num(d.bloat)
                root.speedColo   = d.colo || ""
                root.speedVia    = d.via || ""
                root.speedWhen   = d.when || ""
            } catch (e) {
                console.log("[perf] speedtest state parse error:", e)
            }
        }
    }

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

    // ── Critical pulse ─────────────────────────────────────────
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
    // The sparkline Canvas must be passed in from the parent
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
                root.coreHistories = hists
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

                    let nh = root.netHistory.slice()
                    nh.push({ rx: root.netRxBps, tx: root.netTxBps })
                    if (nh.length > 60) nh.shift()
                    root.netHistory = nh
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

    // Full process tree for the graph (every 3s)
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
