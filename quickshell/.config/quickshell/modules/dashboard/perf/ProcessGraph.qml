import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../../common/Colors.js" as CP
import "../../../common"

Item {
    id: graphRoot

    property bool   graphActive:    false
    property var    processList:    []
    property var    processTree:    []
    property color  accentCyan:     Colours.accentSecondary
    property color  accentYellow:   Colours.accentPrimary
    property color  accentDanger:   Colours.accentDanger
    property color  accentMagenta:  Colours.accentMagenta || "#c850c0"

    // ── Internal state ──────────────────────────────────
    property var    nodes:          []
    property var    edges:          []
    property real   damping:        0.88
    property real   targetLinkDist: 80
    property int    hoveredNode:    -1

    // ── Viewport ───────────────────────────────────────
    property real   viewScale:      1.0
    property real   panX:           0
    property real   panY:           0
    property var    draggedNodeIdx: -1
    property bool   isPanning:      false
    property real   lastMX:         0
    property real   lastMY:         0

    // ── Expand state ────────────────────────────────────
    property int    expandedNode:       -1
    property var    expandedInfo:       null
    property real   expandProgress:     0.0
    property bool   _expanding:         false
    property real   loadProgress:       0.0
    property bool   _loadingDone:       false
    property real   _loadGlitchSeed:    0
    property real   _waveTime:          0
    property real   _pressStartX:       0
    property real   _pressStartY:       0

    readonly property real _TAU: Math.PI * 2

    signal interactionActive(bool active)

    // ── Update the graph ──────────────────────────────────
    function updateGraph() {
        if (graphRoot.nodes.length === 0) { buildGraph(); return }

        let tree = graphRoot.processTree
        if (tree.length === 0) return

        let ns = graphRoot.nodes
        let es = graphRoot.edges

        // Map PID -> updated data from the tree
        let treeMap = {}
        for (let i = 0; i < tree.length; i++) {
            treeMap[tree[i].pid] = tree[i]
        }

        // Map PID -> existing node index
        let pidIdx = {}
        for (let i = 0; i < ns.length; i++) {
            pidIdx[ns[i].pid] = i
        }

        // Update existing nodes
        let alive = {}
        for (let i = 1; i < ns.length; i++) {
            let data = treeMap[ns[i].pid]
            if (data) {
                ns[i].cpu = data.cpu
                ns[i].mem = data.mem
                ns[i].radius = Math.max(4, Math.min(18, 4 + data.cpu * 1.5))
                alive[ns[i].pid] = true
            }
        }

        // Prune dead nodes
        for (let i = ns.length - 1; i >= 1; i--) {
            if (!alive[ns[i].pid] && !treeMap[ns[i].pid]) {
                ns.splice(i, 1)
            }
        }

        // Add new nodes
        let cx = graphCanvas.width / 2
        let cy = graphCanvas.height / 2
        for (let i = 0; i < tree.length; i++) {
            let p = tree[i]
            if (pidIdx[p.pid] !== undefined) continue

            let parentIdx = pidIdx[p.ppid]
            let px, py
            if (parentIdx !== undefined) {
                px = ns[parentIdx].x
                py = ns[parentIdx].y
            } else {
                px = cx; py = cy
            }
            let angle = Math.random() * graphRoot._TAU
            let dist = 40 + Math.random() * 30

            pidIdx[p.pid] = ns.length
            ns.push({
                x: px + Math.cos(angle) * dist,
                y: py + Math.sin(angle) * dist,
                vx: 0, vy: 0, pinned: false,
                name: p.name, pid: p.pid, ppid: p.ppid,
                cpu: p.cpu, mem: p.mem,
                radius: Math.max(4, Math.min(18, 4 + p.cpu * 1.5)),
                isRoot: false, depth: 1
            })
        }

        // Rebuild edges from parent-child hierarchy
        es.length = 0
        for (let i = 1; i < ns.length; i++) {
            let parentIdx = pidIdx[ns[i].ppid]
            if (parentIdx !== undefined) {
                es.push({ source: parentIdx, target: i })
                ns[i].depth = (ns[parentIdx].depth || 0) + 1
            } else {
                es.push({ source: 0, target: i })
                ns[i].depth = 1
            }
        }

        graphRoot.nodes = ns
        graphRoot.edges = es
        graphCanvas.requestPaint()
    }

    // ── Build graph from processList ────────────────────
    function buildGraph() {
        let cx = graphCanvas.width / 2
        let cy = graphCanvas.height / 2
        let n = []
        let e = []

        graphRoot.panX = 0
        graphRoot.panY = 0
        graphRoot.viewScale = 1.0

        let tree = graphRoot.processTree
        if (tree.length === 0) return

        // Map PID -> node index
        let pidIdx = {}

        // Root node "/" (PID 1)
        n.push({
            x: cx, y: cy, vx: 0, vy: 0,
            pinned: false,
            name: "/", pid: 1, ppid: 0, cpu: 0, mem: 0,
            radius: 16, isRoot: true, depth: 0
        })
        pidIdx[1] = 0

        // Create a node for each process
        let total = tree.length
        for (let i = 0; i < total; i++) {
            let p = tree[i]
            let angle = (i / total) * graphRoot._TAU + (Math.random() - 0.5) * 0.3
            let dist = 120 + Math.random() * 40
            let r = Math.max(4, Math.min(18, 4 + p.cpu * 1.15))

            pidIdx[p.pid] = n.length
            n.push({
                x: cx + Math.cos(angle) * dist,
                y: cy + Math.sin(angle) * dist,
                vx: 0, vy: 0, pinned: false,
                name: p.name, pid: p.pid, ppid: p.ppid,
                cpu: p.cpu, mem: p.mem,
                radius: r, isRoot: false, depth: 1
            })
        }

        // Create edges based on the actual parent-child hierarchy
        for (let i = 1; i < n.length; i++) {
            let ppid = n[i].ppid
            let parentIdx = pidIdx[ppid]
            if (parentIdx !== undefined) {
                e.push({ source: parentIdx, target: i })
                // Calculate depth
                n[i].depth = (n[parentIdx].depth || 0) + 1
            } else {
                // Parent not visible -> link to root
                e.push({ source: 0, target: i })
                n[i].depth = 1
            }
        }

        // Adjust distances based on depth
        for (let i = 1; i < n.length; i++) {
            let angle = Math.atan2(n[i].y - cy, n[i].x - cx)
            let dist = 80 + n[i].depth * 60 + Math.random() * 30
            n[i].x = cx + Math.cos(angle) * dist
            n[i].y = cy + Math.sin(angle) * dist
        }

        graphRoot.nodes = n
        graphRoot.edges = e
        simTimer.running = true
    }

    // ── Force simulation (Fruchterman-Reingold) ─────────────────────────
    function stepSimulation() {
        let ns = graphRoot.nodes
        let es = graphRoot.edges
        if (ns.length < 2) return

        let repelStrength = 3000
        let linkStrength = 0.006
        let centerStrength = 0.002
        let cx = graphCanvas.width / 2
        let cy = graphCanvas.height / 2
        let damp = graphRoot.damping
        let targetDist = graphRoot.targetLinkDist

        // Repulsion (inverse-square)
        for (let i = 0; i < ns.length; i++) {
            for (let j = i + 1; j < ns.length; j++) {
                let dx = ns[i].x - ns[j].x
                let dy = ns[i].y - ns[j].y
                let distSq = dx * dx + dy * dy
                if (distSq < 1) distSq = 1
                let dist = Math.sqrt(distSq)
                let f = repelStrength / distSq
                let fx = (dx / dist) * f
                let fy = (dy / dist) * f
                if (i > 0) { ns[i].vx += fx; ns[i].vy += fy }
                if (j > 0) { ns[j].vx -= fx; ns[j].vy -= fy }
            }
        }

        // Spring attraction with target distance (Hooke's law)
        for (let i = 0; i < es.length; i++) {
            let s = ns[es[i].source]
            let t = ns[es[i].target]
            let dx = t.x - s.x
            let dy = t.y - s.y
            let dist = Math.sqrt(dx * dx + dy * dy) || 1
            let displacement = dist - targetDist
            let fx = (dx / dist) * displacement * linkStrength
            let fy = (dy / dist) * displacement * linkStrength
            let si = es[i].source, ti = es[i].target
            if (si > 0) { s.vx += fx; s.vy += fy }
            if (ti > 0) { t.vx -= fx; t.vy -= fy }
        }

        // Center gravity: nodes attracted toward the root node (index 0)
        let rootNode = ns[0]
        for (let i = 1; i < ns.length; i++) {
            ns[i].vx += (rootNode.x - ns[i].x) * centerStrength
            ns[i].vy += (rootNode.y - ns[i].y) * centerStrength
        }

        // Micro-drift (floating)
        for (let i = 0; i < ns.length; i++) {
            if (ns[i].pinned) continue
            ns[i].vx += (Math.random() - 0.5) * 0.15
            ns[i].vy += (Math.random() - 0.5) * 0.15
        }

        // Apply velocity + damping
        for (let i = 0; i < ns.length; i++) {
            if (ns[i].pinned) continue
            ns[i].vx *= damp
            ns[i].vy *= damp
            ns[i].x += ns[i].vx
            ns[i].y += ns[i].vy
        }

        // Viewport lerp durante expand
        if (graphRoot.expandedNode >= 0 && graphRoot.expandProgress > 0) {
            let en = ns[graphRoot.expandedNode]
            if (en) {
                let w = graphCanvas.width
                let h = graphCanvas.height
                let tScale = 1.0
                let tPanX = w / 2 - en.x * tScale
                let tPanY = h / 2 - en.y * tScale
                let t = 0.1
                graphRoot.panX += (tPanX - graphRoot.panX) * t
                graphRoot.panY += (tPanY - graphRoot.panY) * t
                graphRoot.viewScale += (tScale - graphRoot.viewScale) * t
            }
        }
    }

    // ── Hit test ─────────────────────────────────────────────
    function findNodeAt(wx, wy) {
        let ns = graphRoot.nodes
        for (let i = ns.length - 1; i >= 0; i--) {
            let dx = wx - ns[i].x
            let dy = wy - ns[i].y
            let isCurrentHov = (i === graphRoot.hoveredNode)
            let hitR = isCurrentHov
                    ? Math.max(ns[i].radius * (1.3 + 0.8 / graphRoot.viewScale), 10)
                    : Math.max(ns[i].radius, 10)
            if (dx * dx + dy * dy <= hitR * hitR) return i
        }
        return -1
    }

    // ── Node expansion - process detail view ───────────────────
    function expandNode(idx) {
        if (idx < 0 || idx >= nodes.length) return
        graphRoot.expandedNode = idx
        graphRoot._expanding = true
        expandAnim.from = 0
        expandAnim.to = 1
        expandAnim.restart()
        graphRoot._loadingDone = false
        graphRoot.loadProgress = 0
        loadAnim.restart()

        // Fetch detailed info
        let name = nodes[idx].name
        graphRoot.expandedInfo = null
        if (graphRoot.nodes[idx].isRoot) {
            infoProc.command = ["bash", "-c",
                            "echo \"$(hostname)|$(uname -r)|$(cat /proc/uptime | awk '{d=int($1/86400); " +
                            "h=int(($1%86400)/3600); m=int(($1%3600)/60);" + 
                            "printf \"%dd %dh %dm\",d,h,m}')|$(cat /proc/loadavg | awk " +
                            "'{print $1,$2,$3}')|$(nproc)|$(free -m | awk '/^Mem:/" + 
                            "{printf \"%d/%dMB (%.0f%%)\", $3, $2, $3/$2*100}')|" +
                            "$(free -m | awk '/^Swap:/{printf \"%d/%dMB\", $3, $2}')|" +
                            "$(df -h / | awk 'NR==2{print $3\"/\"$2\" (\"$5\")\"}')|" +
                            "$(cat /proc/cpuinfo | grep 'model name' | head -1 | sed 's/.*: //')|" +
                            "$(nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu,driver.version " +
                            "--format=csv,noheader,nounits 2>/dev/null || echo 'N/A')\""]
            infoProc.running = true
            return
        }
        infoProc.command = ["bash", "-c",
                        "pids=$(pgrep -x '" + name + "' 2>/dev/null);" +
                        "[ -z \"$pids\" ] && echo 'NOTFOUND' && exit 0;" +
                        "first=$(echo \"$pids\" | head -1);" +
                        "pidcsv=$(pgrep -x -d, '" + name + "');" +
                        "np=$(nproc);" +
                        "agg=$(ps -p $pidcsv -o pcpu=,pmem=,rss= --no-headers | " +
                        "awk -v np=$np '{c+=$1; m+=$2; r+=$3} END{printf \"%.1f %.1f %d\", c/np, m, r}');" +
                        "count=$(echo \"$pids\" | wc -l);" +
                        "info=$(ps -p $first -o pid=,etime=,user=,nice=,stat=,nlwp= --no-headers | xargs);" +
                        "cmd=$(tr '\\0' ' ' </proc/$first/cmdline 2>/dev/null);" +
                        "exe=$(readlink /proc/$first/exe 2>/dev/null);" +
                        "printf '%s\\n' \"$agg $count $info|$cmd|$exe\""]
        infoProc.running = true
    }

    function collapseNode() {
        graphRoot._expanding = false
        expandAnim.from = 1
        expandAnim.to = 0
        expandAnim.start()
    }

    // ── Rendering Cards ──────────────────────────────────────────
    function drawMetricBar(ctx, x, y, maxW, label, value, color, alpha) {
        let barW = maxW - 90
        let barH = 5
        let barX = x + 45
        let barY = y - barH

        ctx.textAlign = "left"
        ctx.font = "9px Oxanium"
        ctx.fillStyle = Qt.rgba(1, 1, 1, 0.5 * alpha)
        ctx.fillText(label, x, y)

        ctx.fillStyle = Qt.rgba(1, 1, 1, 0.06 * alpha)
        ctx.fillRect(barX, barY, barW, barH)

        let fillW = barW * Math.min(1, value / 100)
        ctx.fillStyle = Qt.rgba(color.r, color.g, color.b, 0.7 * alpha)
        ctx.fillRect(barX, barY, fillW, barH)

        ctx.textAlign = "right"
        ctx.font = "bold 11px Oxanium"
        ctx.fillStyle = Qt.rgba(color.r, color.g, color.b, alpha)
        ctx.fillText(value.toFixed(1) + "%", x + maxW, y)
    }

    function drawExpandedCard(ctx) {
        let node = graphRoot.nodes[graphRoot.expandedNode]
        if (!node) return

        let w = graphCanvas.width
        let h = graphCanvas.height
        let ep = graphRoot.expandProgress
        let c = graphRoot.nodeColor(node)

        ctx.setTransform(1, 0, 0, 1, 0, 0)

        // Origin: interpolate from node position to view center
        let nodeScreenX = node.x * graphRoot.viewScale + graphRoot.panX
        let nodeScreenY = node.y * graphRoot.viewScale + graphRoot.panY
        let cx = nodeScreenX + (w / 2 - nodeScreenX) * ep
        let cy = nodeScreenY + (h / 2 - nodeScreenY) * ep

        // Scale with cubic easing for a "burst" feel
        let scale = ep * ep * (3 - 2 * ep)      // smoothstep

        // Card dimensions
        let cardW = w * 0.85 * ep
        let cardH = h * 0.85 * ep
        let hw = cardW / 2
        let hh = cardH / 2
        let cut = 18 * scale


        // Dim overlay with card-shaped cutout
        ctx.save()
        ctx.beginPath()
        // Outer path with the same cuts as the parent CutShape
        ctx.moveTo(0, 0)
        ctx.lineTo(w - 24, 0)
        ctx.lineTo(w, 0)
        ctx.lineTo(w, h)
        ctx.lineTo(25, h)
        ctx.lineTo(0, h - 25)
        ctx.closePath()

        ctx.moveTo(cx - hw + cut, cy - hh)
        ctx.lineTo(cx - hw, cy - hh + cut)
        ctx.lineTo(cx - hw, cy + hh)
        ctx.lineTo(cx + hw - cut, cy + hh)
        ctx.lineTo(cx + hw, cy + hh - cut)
        ctx.lineTo(cx + hw, cy - hh)
        ctx.closePath()
        ctx.fillStyle = Qt.rgba(0, 0.02, 0.05, 0.75 * ep)
        ctx.fill("evenodd")
        ctx.restore()

        // Notched card path
        ctx.beginPath()
        ctx.moveTo(cx - hw + cut, cy - hh)
        ctx.lineTo(cx + hw, cy - hh)
        ctx.lineTo(cx + hw, cy + hh - cut)
        ctx.lineTo(cx + hw - cut, cy + hh)
        ctx.lineTo(cx - hw, cy + hh)
        ctx.lineTo(cx - hw, cy - hh + cut)
        ctx.closePath()

        // Card fill
        ctx.fillStyle = Qt.rgba(0, 0.024 ,0.055, 0.96)
        ctx.fill()

        // Border glow (2 layer)
        ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.15 * ep)
        ctx.lineWidth = 4
        ctx.stroke()
        ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.6 * ep)
        ctx.lineWidth = 1
        ctx.stroke()

        // ── FAKE LOADING SCREEN ─────────────────────────────
        if (!graphRoot._loadingDone) {
            let lp = graphRoot.loadProgress
            let seed = graphRoot._loadGlitchSeed
            let glitchOn = (seed > 0.7)

            // Scanlines
            ctx.fillStyle = Qt.rgba(0, 0.8, 1, 0.03)
            let scanY = (lp * 4 % 1) * h
            for (let s = 0; s < 8; s++) {
                let sy = (scanY + s * h / 8) % h
                ctx.fillRect(cx - hw, sy, cardW, 2)
            }

            // Glitch displacement bars
            if (glitchOn) {
                ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.08)
                for (let g = 0; g < 3; g++) {
                    let gy = cy - hh + Math.random() * cardH
                    let gw = cardW * (0.3 + Math.random() * 0.5)
                    ctx.fillRect(cx - hw + Math.random() * 20 - 10, gy, gw, 2 + Math.random() * 4)
                }
            }

            // "LOADING" text with chromatic aberration
            ctx.textAlign = "center"
            let loadText = "ACCESSING PROCESS DATA"
            let dots = ".".repeat(Math.floor(lp * 8) % 4)
            let tx = cx + (glitchOn ? (Math.random() - 0.5) * 6 : 0)
            let ty = cy - 20 + (glitchOn ? (Math.random() - 0.5) * 4 : 0)

            // Red layer
            ctx.font = "bold 13px Oxanium"
            ctx.fillStyle = Qt.rgba(1, 0.1, 0.2, glitchOn ? 0.6 * ep : 0)
            ctx.fillText(loadText + dots, tx + 2, ty)
            // Main layer
            ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.9 * ep)
            ctx.fillText(loadText + dots, cx, cy - 20)

            // Progress bar
            let barW = cardW * 0.5
            let barH = 3
            let barX = cx - barW / 2
            let barY = cy

            // Bar background
            ctx.fillStyle = Qt.rgba(1, 1, 1, 0.06 * ep)
            ctx.fillRect(barX, barY, barW, barH)
            // Fill
            let fillW = barW * lp
            ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.8 * ep)
            ctx.fillRect(barX, barY, fillW, barH)
            // Glow on the tip
            ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.4 * ep)
            ctx.fillRect(barX + fillW - 8, barY - 1, 8, barH + 2)

            // Percentage
            ctx.font = "10px Oxanium"
            ctx.fillStyle = Qt.rgba(1, 1, 1, 0.4 * ep)
            ctx.fillText(Math.floor(lp * 100) + "%", cx, barY + 18)

            // Hex data flickering
            if (lp > 0.2) {
                ctx.font = "8px Oxanium"
                ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.15 * ep)
                let hexLine = ""
                for (let h = 0; h < 12; h++) hexLine += Math.floor(Math.random() * 65536).toString(16).padStart(4, "0") + " "
                ctx.fillText(hexLine.substring(0, 48), cx, cy + 40)
                if (lp > 0.5) {
                    hexLine = ""
                    for (let h = 0; h < 12; h++) hexLine += Math.floor(Math.random() * 65536).toString(16).padStart(4, "0") + " "
                    ctx.fillText(hexLine.substring(0, 48), cx, cy + 52)
                }
            }

            return      // Don't render content while loading
        }

        // Only show content when the card is open enough
        if (ep < 0.3) return
        let contentAlpha = Math.min(1, (ep - 0.3) / 0.5)

        // Transform: draw at final size, scale from center
        ctx.save()
        ctx.translate(cx, cy)
        ctx.scale(scale, scale)
        ctx.translate(-cx, -cy)

        // Coordinates based on the final card dimensions
        let fullW = w * 0.85
        let fullH = h * 0.85
        let left = cx - fullW / 2 + 30
        let right = cx + fullW / 2 - 30
        let contentW = right - left
        let top = cy - fullH / 2 + 40
        let bottom = cy + fullH / 2 - 30

        // ── Title ─────────────────
        ctx.textAlign = "left"
        ctx.font = "bold 22px Oxanium"
        ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, contentAlpha)
        ctx.fillText(node.name.toUpperCase(), left, top)

        let info = graphRoot.expandedInfo
        if (info) {
            ctx.textAlign = "right"
            ctx.font = "13px Oxanium"
            ctx.fillStyle = Qt.rgba(1, 1, 1, 0.4 * contentAlpha)
            ctx.fillText("PID " + info.pid, right, top)
        }
        let y = top + 16

        // Separator
        ctx.beginPath()
        ctx.moveTo(left, y); ctx.lineTo(right, y)
        ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.3 * contentAlpha)
        ctx.lineWidth = 1
        ctx.stroke()
        y += 18

        if (!info) {
            ctx.textAlign = "center"
            ctx.font = "14px Oxanium"
            ctx.fillStyle = Qt.rgba(1, 1, 1, 0.4 * contentAlpha)
            ctx.fillText("FETCHING DATA...", cx, cy)
            return
        }

        if (info._isRoot) {
            // CPU / MEM bars from system totals
            let sysCpu = parseFloat(info.ram.match(/\((\d+)%\)/)?.[1]) || 0
            let loadPct = (parseFloat(info.loadavg.split(" ")[0]) / parseInt(info.cores) * 100)
            graphRoot.drawMetricBar(ctx, left, y, contentW, "LOAD AVG", Math.min(100, loadPct), graphRoot.accentCyan, contentAlpha)
            y += 12
            graphRoot.drawMetricBar(ctx, left, y, contentW, "GPU USG", parseFloat(info.gpuUtil) || 0, graphRoot.accentYellow, contentAlpha)
            y += 12
            graphRoot.drawMetricBar(ctx, left, y, contentW, "RAM USG", sysCpu, graphRoot.accentMagenta, contentAlpha)
            y += 15

            ctx.beginPath()
            ctx.moveTo(left, y); ctx.lineTo(right, y)
            ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.15 * contentAlpha)
            ctx.lineWidth = 1
            ctx.stroke()
            y += 16
            ctx.textAlign = "left"
            ctx.font = "10px Oxanium"
            ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.5 * contentAlpha)
            ctx.fillText("── SYSTEM INFO", left, y)
            y += 16

            let gpuMemPct = Math.round(parseInt(info.gpuMemUsed) / Math.max(1, parseInt(info.gpuMemTotal)) * 100)
            let details = [
                ["HOST",        info.hostname],
                ["KERNEL",      info.kernel],
                ["CPU",         info.cpuModel],
                ["GPU",         info.gpuModel],
                ["GPU VRAM",    info.gpuMemUsed + "/" + info.gpuMemTotal + "MB (" + gpuMemPct + "%)"],
                ["GPU TEMP",    info.gpuTemp + "°C"],
                ["DRIVER",      info.gpuDriver],
                ["CORES",       info.cores],
                ["UPTIME",      info.uptime],
                ["LOAD",        info.loadavg],
                ["RAM",         info.ram],
                ["SWAP",        info.swap],
                ["DISK /",      info.disk]
            ]

            let availableH = bottom - y - 20
            let rowH = Math.max(22, Math.min(32, availableH / details.length))
            let labelW = 100
            let valueFontSize = Math.max(12, Math.min(15, rowH * 0.5))
            let labelFontSize = Math.max(10, valueFontSize - 2)
            let maxChars = Math.floor((contentW - labelW) / (valueFontSize * 0.52))

            for (let i = 0; i < details.length; i++) {
                ctx.textAlign = "left"
                ctx.font = labelFontSize + "px Oxanium"
                ctx.fillStyle = Qt.rgba(1, 1, 1, 0.35 * contentAlpha)
                ctx.fillText(details[i][0], left, y)
                ctx.font = valueFontSize + "px Oxanium"
                ctx.fillStyle = Qt.rgba(1, 1, 1, 0.9 * contentAlpha)
                let val = details[i][1] || "N/A"
                if (val.length > maxChars) val = val.substring(0, maxChars - 3) + "..."
                ctx.fillText(val, left + labelW, y)
                y += rowH
            }

            ctx.textAlign = "right"
            ctx.font = "10px Oxanium"
            ctx.fillStyle = Qt.rgba(1, 1, 1, 0.25 * contentAlpha)
            ctx.fillText("[ESC] CLOSE", right + 10, bottom + 10)
            ctx.restore()
            return
        }

        // ── CPU / GPU / MEM bars ────────────────────────
        y += 9
        graphRoot.drawMetricBar(ctx, left, y, contentW, "CPU", node.cpu, graphRoot.accentCyan, contentAlpha)
        y += 18
        graphRoot.drawMetricBar(ctx, left, y, contentW, "GPU", parseFloat(info.gpuUtil) || 0, graphRoot.accentYellow, contentAlpha)
            y += 18
        graphRoot.drawMetricBar(ctx, left, y, contentW, "MEM", node.mem, graphRoot.accentMagenta, contentAlpha)
        y += 18


        // Separator + DETAILS header
        ctx.beginPath()
        ctx.moveTo(left, y); ctx.lineTo(right, y)
        ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.15 * contentAlpha)
        ctx.lineWidth = 1
        ctx.stroke()
        y += 22
        ctx.textAlign = "left"
        ctx.font = "10px Oxanium"
        ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.5 * contentAlpha)
        ctx.fillText("── DETAILS", left, y)
        y += 26

        // ── Detail rows ─────────────────────────────────────
        let details = [
            ["PATH",    info.path],
            ["COMMAND", info.command],
            ["USER",    info.user],
            ["UPTIME",  info.uptime],
            ["STATE",   info.state],
            ["PIDS",    info.pids + " processes"],
            ["THREADS", info.threads],
            ["RSS",     info.rss],
            ["NICE",    info.nice]
        ]

        let availableH = bottom - y - 20
        let rowH = Math.max(22, Math.min(32, availableH / details.length))
        let labelW = 100
        let valueFontSize = Math.max(12, Math.min(15, rowH * 0.5))
        let labelFontSize = Math.max(10, valueFontSize - 2)
        let maxChars = Math.floor((contentW - labelW) / (valueFontSize * 0.52))

        for (let i = 0; i < details.length; i++) {
            ctx.textAlign = "left"
            ctx.font = labelFontSize + "px Oxanium"
            ctx.fillStyle = Qt.rgba(1, 1, 1, 0.35 * contentAlpha)
            ctx.fillText(details[i][0], left, y)

            ctx.font = valueFontSize + "px Oxanium"
            ctx.fillStyle = Qt.rgba(1, 1, 1, 0.9 * contentAlpha)
            let val = details[i][1] || "N/A"
            if (val.length > maxChars) val = val.substring(0, maxChars - 3) + "..."
            ctx.fillText(val, left + labelW, y)
            y += rowH
        }

        // ── ESC hint ──────────────────────────────
        ctx.textAlign = "right"
        ctx.font = "10px Oxanium"
        ctx.fillStyle = Qt.rgba(1, 1, 1, 0.25 * contentAlpha)
        ctx.fillText("[ESC] CLOSE", right + 10, bottom + 10)

        ctx.restore()
    }

    // ── Node color ────────────────────────────────────────────────

    function nodeColor(node) {
        if (node.isRoot) return graphRoot.accentYellow
        if (node.cpu > 15) return graphRoot.accentDanger
        if (node.mem > 30) return graphRoot.accentMagenta
        return graphRoot.accentCyan
    }

    // ── Rendering ────────────────────────────────────────────────
    function drawGraph(ctx) {
        let w = graphCanvas.width
        let h = graphCanvas.height
        let ns = graphRoot.nodes
        let es = graphRoot.edges
        let hov = graphRoot.hoveredNode
        let TAU = graphRoot._TAU

        ctx.setTransform(1, 0, 0, 1, 0, 0)
        ctx.clearRect(0, 0, w, h)
        ctx.translate(graphRoot.panX, graphRoot.panY)
        ctx.scale(graphRoot.viewScale, graphRoot.viewScale)

        // Set of nodes connected to the hovered one
        let connSet = {}
        if (hov >= 0) {
            connSet[hov] = true
            for (let i = 0; i < es.length; i++) {
                if (es[i].source === hov) connSet[es[i].target] = true
                if (es[i].target === hov) connSet[es[i].source] = true
            }
        }

        // ── EDGES ────────────────────────────────
        ctx.lineWidth = 1
        ctx.beginPath()
        for (let i = 0; i < es.length; i++) {
            let s = ns[es[i].source]
            let t = ns[es[i].target]
            ctx.moveTo(s.x, s.y)
            ctx.lineTo(t.x, t.y)
        }
        // Base edge color
        let ec = graphRoot.accentCyan
        if (hov < 0) {
            ctx.strokeStyle = Qt.rgba(ec.r, ec.g, ec.b, 0.12)
        } else {
            ctx.strokeStyle = Qt.rgba(ec.r, ec.g, ec.b, 0.05)
        }
        ctx.stroke()

        // Edge highlight se hovered
        if (hov >= 0) {
            ctx.lineWidth = 1.5
            ctx.strokeStyle = Qt.rgba(ec.r, ec.g, ec.b, 0.4)
            ctx.beginPath()
            for (let i = 0; i < es.length; i++) {
                if (es[i].source === hov || es[i].target === hov) {
                    let s = ns[es[i].source]
                    let t = ns[es[i].target]
                    ctx.moveTo(s.x, s.y)
                    ctx.lineTo(t.x, t.y)
                }
            }
            ctx.stroke()
        }

        // ── NODES ──────────────────────────
        for (let i = 0; i < ns.length; i++) {
            let n = ns[i]
            let c = graphRoot.nodeColor(n)
            let dimmed = (hov >= 0 && !connSet[i])
            let isConn = (hov >= 0 && connSet[i] && i !== hov)
            let isHov = (i === hov)
            let baseAlpha = dimmed ? 0.08 : 1.0
            let drawR = dimmed ? n.radius 
                    : isConn ? n.radius * (1.3 + 0.8 / graphRoot.viewScale) 
                    : isHov ? n.radius * (1.2 + 0.5 / graphRoot.viewScale)
                    : n.radius
            let a = dimmed ? 0.15 : 1.0

            // Concentric energy waves
            let waves = (isHov || isConn) ? 3 : 2
            let wt = graphRoot._waveTime
            let baseSpeed = n.isRoot ? 0.7 : 0.7 + (n.cpu || 0) * 0.02      // more CPU = faster waves

            for (let w = 0; w < waves; w++) {
                let rawPhase = (wt * baseSpeed * 0.4 + w * (1.0 / waves)) % 1.0
                let phase = rawPhase * rawPhase * (3 - 2 * rawPhase)        // smoothstep
                let waveR = drawR + phase * drawR * 3.0
                let waveAlpha = (1.0 - phase) * (1.0 - phase) * ((isHov || isConn) ? 0.45 : 0.18) * a

                ctx.beginPath()
                ctx.arc(n.x, n.y, waveR, 0, graphRoot._TAU)
                ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, waveAlpha)
                ctx.lineWidth = (1.0 - phase) * ((isHov || isConn) ? 4.0 : 2.5) + 0.5
                ctx.stroke()
            }

            // Node bounce (heartbeat with ease and pause)
            let beat = (graphRoot._waveTime * (n.isRoot ? 0.5 : 0.8 + (n.cpu || 0) * 0.005)) % 1.0
            let breathe
            if (beat < 0.3) {
                // Expand+return phase (ease in-out)
                let t = beat / 0.3
                let ease = t < 0.5 ? 2 * t * t : 1 - 2 * (1 - t) * (1 - t)
                breathe = 1.0 + (1.0 - Math.abs(ease * 2 - 1)) * (isHov ? 0.18 : 0.08)
            } else {
                // Rest at normal size
                breathe = 1.0
            }
            let solidR = drawR * breathe
            // Glow with bounce (core gradient)
            ctx.beginPath()
            ctx.arc(n.x, n.y, drawR * 1.6, 0, graphRoot._TAU)
            let coreGrad = ctx.createRadialGradient(n.x, n.y, drawR * 0.5, n.x, n.y, drawR * 1.6)
            coreGrad.addColorStop(0, Qt.rgba(c.r, c.g, c.b, ((isHov || isConn) ? 0.4 : 0.25) * a))
            coreGrad.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0))
            ctx.fillStyle = coreGrad
            ctx.fill()

            // Core
            ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, baseAlpha)
            ctx.beginPath(); ctx.arc(n.x, n.y, drawR, 0, TAU); ctx.fill()

            // Border ring
            if (!dimmed) {
                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.25)
                ctx.lineWidth = 0.5
                ctx.beginPath(); ctx.arc(n.x, n.y, drawR, 0, TAU); ctx.stroke()
            }
        }

        // ── LABELS (only when zoom > 0.6) ──────────────────
        if (graphRoot.viewScale > 0.6 || hov >= 0) {
            ctx.textAlign = "center"
            for (let i = 0; i < ns.length; i++) {
                let n = ns[i]
                let dimmed = (hov >= 0 && !connSet[i])
                if (dimmed) continue

                let isConn = (hov >= 0 && connSet[i] && i !== hov)
                let isHov = (i === hov)
                let c = graphRoot.nodeColor(n)
                let baseSize = n.isRoot ? 11 : isHov ? 12 : isConn ? 11 : 9
                let nameSize = (isConn || isHov) ? Math.round(baseSize / graphRoot.viewScale * 0.7) : baseSize
                nameSize = Math.min(nameSize, 22)       // max cap
                let drawR = isConn ? n.radius * (1.3 + 0.8 / graphRoot.viewScale)
                            : isHov ? n.radius * (1.2 + 0.5 / graphRoot.viewScale)
                            : n.radius
                ctx.font = (n.isRoot || isHov ? "bold " : "") + nameSize + "px Oxanium"
                ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, isConn || isHov ? 1.0 : 0.9)
                ctx.fillText(n.name.toUpperCase(), n.x, n.y + drawR + 12)

                // CPU% sublabel - always shown for connected nodes
                if (!n.isRoot && graphRoot.viewScale > 0.8 || isConn || isHov) {
                    let subSize = (isConn || isHov) ? Math.min(Math.round(9 / graphRoot.viewScale * 0.7), 16) : 7
                    ctx.font = subSize + "px Oxanium"
                    ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.5)
                    ctx.fillText(n.cpu.toFixed(1) + "%", n.x, n.y + drawR + 12 + subSize + 2)
                }
            }
        }

        // Card overlay when expanded
        if (graphRoot.expandedNode >= 0 && graphRoot.expandProgress > 0) {
            graphRoot.drawExpandedCard(ctx)
        }
    }

    // ── React to processList changes ────────────────────────────────────────────
    onProcessTreeChanged: updateGraph()
    onVisibleChanged: {
        if (visible) Qt.callLater(buildGraph)
    }
    Component.onCompleted: buildGraph()

    // ── Simulation timer (~30fps) ───────────────────────────────────────
    Timer {
        id: simTimer
        interval: graphRoot.expandedNode >= 0 ? 100 : 40
        running: graphRoot.graphActive && graphRoot.nodes.length > 0
        repeat: true
        onTriggered: {
            graphRoot._waveTime += 0.05
            graphRoot.stepSimulation()
            graphCanvas.requestPaint()
            if (!graphRoot._loadingDone && graphRoot.expandedNode >= 0)
                graphRoot._loadGlitchSeed = Math.random()
        }
    }

    // ── Fetch info process ────────────────────────────────────────────────────
    Process {
        id: infoProc
        running: false
        stdout: SplitParser { onRead: data => {
            let raw = data.trim()
            if (raw === "NOTFOUND" || raw.length === 0) return

            // Parsing for root node (system info)
            if (graphRoot.expandedNode >= 0 && graphRoot.nodes[graphRoot.expandedNode].isRoot) {
                let p = raw.split("|")
                if (p.length < 9) return
                let gpuParts = (p[9] || "").split(", ")
                graphRoot.expandedInfo = {
                    hostname:p[0], kernel: p[1], uptime: p[2],
                    loadavg: p[3], cores: p[4], ram: p[5],
                    swap: p[6], disk: p[7], cpuModel: p[8] || "N/A",
                    gpuName: gpuParts[0] || 'N/A',
                    gpuUtil: gpuParts[1] || "0",
                    gpuMemUsed: gpuParts[2] || "0",
                    gpuMemTotal: gpuParts[3] || "0",
                    gpuTemp: gpuParts[4] || "0",
                    gpuDriver: gpuParts[5] || "N/A",
                    _isRoot: true
                }
                graphCanvas.requestPaint()
                return
            }
            let parts = raw.split("|")
            let f = parts[0].trim().split(/\s+/)
            if (f.length < 10) return

            graphRoot.expandedInfo = {
                cpu: f[0], mem: f[1],
                rss: Math.round(parseInt(f[2]) / 1024) + " MB",
                pids: f[3],
                pid: f[4], uptime: f[5], user: f[6],
                nice: f[7], state: f[8], threads: f[9],
                command: (parts[1] || "").trim(),
                path: (parts[2] || "").trim()
            }
            graphCanvas.requestPaint()
        }}
    }

    Timer {
        id: infoRefreshTimer
        interval: 1000
        repeat: true
        running: graphRoot.expandedNode >= 0
        onTriggered: {
            if (graphRoot.expandedNode < 0 || !graphRoot.expandedInfo) return
            if (graphRoot.nodes[graphRoot.expandedNode].isRoot) {
                infoProc.command = ["bash", "-c",
                                "echo \"$(hostname)|$(uname -r)|$(cat /proc/uptime | awk " +
                                "'{d=int($1/86400); h=int(($1%86400)/3600); m=int(($1%3600)/60); " +
                                "printf \"%dd %dh %dm\",d,h,m}')|$(cat /proc/loadavg | awk '{print $1,$2,$3}')|" +
                                "$(nproc)|$(free -m | awk '/^Mem:/{printf \"%d/%dMB (%.0f%%)\", " +
                                "$3, $2, $3/$2*100}')|$(free -m | awk '/^Swap:/{printf \"%d/%dMB\", $3, $2}')|" +
                                "$(df -h / | awk 'NR==2{print $3\"/\"$2\" (\"$5\")\"}')|" +
                                "$(cat /proc/cpuinfo | grep '\"'model name'\"' | head -1 | sed 's/.*: //')" +
                                "$(nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu,driver.version " +
                                "--format=csv,noheader,nounits 2>/dev/null || echo 'N/A')\""]
            }
            let pid = graphRoot.expandedInfo.pid
            infoRefreshProc.command = ["bash", "-c",
                                    "ps -p " + pid + " -o etime=,stat=,nlwp=,rss= --no-headers 2>/dev/null | xargs"]
            infoRefreshProc.running = true
        }
    }

    Process {
        id: infoRefreshProc
        running: false
        stdout: SplitParser { onRead: data => {
            let f = data.trim().split(/\s+/)
            if (f.length < 4 || !graphRoot.expandedInfo) return
            let old = graphRoot.expandedInfo
            graphRoot.expandedInfo = {
                pid: old.pid, cpu: old.cpu, mem: old.mem,
                pids: old.pids, command: old.command,
                path: old.path, user: old.user, nice: old.nice,
                uptime: f[0],
                state: f[1],
                threads: f[2],
                rss: Math.round(parseInt(f[3]) / 1024) + " MB"
            }
            graphCanvas.requestPaint()
        }}
    }

    // ── Expand/collapse animation ─────────────────────────────────────────
    NumberAnimation {
        id: expandAnim
        target: graphRoot
        property: "expandProgress"
        duration: 380
        easing.type: Easing.OutQuad
        onFinished: {
            if (!graphRoot._expanding) {
                graphRoot.expandedNode = -1
                graphRoot.expandedInfo = null
            }
        }
    }

    NumberAnimation {
        id: loadAnim
        target: graphRoot
        property: "loadProgress"
        from: 0; to: 1
        duration: 1700
        easing.type: Easing.InOutQuad
        onFinished: graphRoot._loadingDone = true
    }

    // ── Canvas ────────────────────────────────
    Canvas {
        id: graphCanvas
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Cooperative

        onWidthChanged: if (graphRoot.visible) Qt.callLater(graphRoot.buildGraph)
        onHeightChanged: if (graphRoot.visible) Qt.callLater(graphRoot.buildGraph)

        onPaint: {
            let ctx = getContext("2d")
            graphRoot.drawGraph(ctx)
        }
    }

    // ── Input: node drag, pan, hover ────────────
    MouseArea {
        id: graphMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        preventStealing: true
        propagateComposedEvents: false
        focus: true

        onPressed: function(mouse) {
            graphRoot.interactionActive(true)
            let idx = graphRoot.hoveredNode

            if (idx >= 0) {
                graphRoot.draggedNodeIdx = idx
                graphRoot.nodes[idx].pinned = true
                graphRoot.nodes[idx].vx = 0
                graphRoot.nodes[idx].vy = 0
            } else if (idx < 0) {
                graphRoot.isPanning = true
            }
            graphRoot.lastMX = mouse.x
            graphRoot.lastMY = mouse.y
            graphRoot._pressStartX = mouse.x
            graphRoot._pressStartY = mouse.y
            graphMouse.forceActiveFocus()
        }

        onPositionChanged: function(mouse) {
            let dx = mouse.x - graphRoot.lastMX
            let dy = mouse.y - graphRoot.lastMY

            if (graphRoot.draggedNodeIdx >= 0) {
                graphRoot.nodes[graphRoot.draggedNodeIdx].x += dx / graphRoot.viewScale
                graphRoot.nodes[graphRoot.draggedNodeIdx].y += dy / graphRoot.viewScale
                graphCanvas.requestPaint()
            } else if (graphRoot.isPanning) {
                graphRoot.panX += dx
                graphRoot.panY += dy
                graphCanvas.requestPaint()
            } else {
                if (graphRoot.expandedNode >= 0) {
                    graphRoot.hoveredNode = -1
                    graphCanvas.requestPaint()
                    graphRoot.lastMX = mouse.x
                    graphRoot.lastMY = mouse.y
                    return
                }
                // Hover hit-test
                let wx = (mouse.x - graphRoot.panX) / graphRoot.viewScale
                let wy = (mouse.y - graphRoot.panY) / graphRoot.viewScale
                let idx = graphRoot.findNodeAt(wx, wy)
                if (idx !== graphRoot.hoveredNode) {
                    graphRoot.hoveredNode = (idx === undefined) ? -1 : idx
                    graphCanvas.requestPaint()
                }
            }
            graphRoot.lastMX = mouse.x
            graphRoot.lastMY = mouse.y
        }

        onReleased: function(mouse) {
            let dist = Math.abs(mouse.x - graphRoot._pressStartX) + Math.abs(mouse.y - graphRoot._pressStartY)

            if (graphRoot.draggedNodeIdx >= 0) {
                graphRoot.nodes[graphRoot.draggedNodeIdx].vx = 0
                graphRoot.nodes[graphRoot.draggedNodeIdx].vy = 0
                graphRoot.nodes[graphRoot.draggedNodeIdx].pinned = false

                // Click (not drag) -> expand
                if (dist < 5 && graphRoot.expandedNode < 0) {
                    graphRoot.expandNode(graphRoot.draggedNodeIdx)
                }
                graphRoot.draggedNodeIdx = -1
            } else if (dist < 5 && graphRoot.expandedNode >= 0) {
                // Click outside during expand -> collapse
                graphRoot.collapseNode()
            }
            graphRoot.isPanning = false
            graphRoot.interactionActive(false)
        }

        onExited: function(mouse) {
            if (graphRoot.hoveredNode >= 0) {
                graphRoot.hoveredNode = -1
                graphCanvas.requestPaint()
            }
        }

        // ── Zoom (scroll wheel) ─────────────────────────
        onWheel: function(event) {
            let oldScale = graphRoot.viewScale
            let newScale = Math.max(0.2, Math.min(3.0, oldScale * (event.angleDelta.y > 0 ? 1.12 : 0.88)))
            if (newScale === oldScale) { event.accepted = true; return }
            let factor = newScale / oldScale
            let mx = event.x
            let my = event.y
            graphRoot.panX = mx - (mx - graphRoot.panX) * factor
            graphRoot.panY = my - (my - graphRoot.panY) * factor
            graphRoot.viewScale = newScale
            graphCanvas.requestPaint()
            event.accepted = true
        }

        // ESC to close card
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape && graphRoot.expandedNode >= 0) {
                graphRoot.collapseNode()
                event.accepted = true
            }
        }
    }
}