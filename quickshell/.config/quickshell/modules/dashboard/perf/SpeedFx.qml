// SpeedFx.qml — particle and glitch layer for the network card's speed test.
//
// One canvas, one frame loop, and nothing running unless there is something
// on screen: the loop starts with the test or a burst and stops by itself once
// the last particle has died.
//
//   rain     — hex glyph columns, falling while downloading and rising while
//              uploading, faster with the live rate
//   packets  — small squares pulled into the ring (download) or thrown out of
//              it (upload)
//   sonar    — thin rings leaving the ring while latency is probed
//   burst()  — shards, a shockwave and tearing bars, for the test's milestones
//   tear()   — the tearing bars alone, for the sparse glitch after a test
import QtQuick
import "../../../common/Colors.js" as CP
import "../../../common"

Canvas {
    id: fx

    // Ring geometry, in this canvas's coordinates: the stroke's centre and
    // radius. Particles are born on it and absorbed by it.
    property real cx: width / 2
    property real cy: height / 2
    property real radius: 50
    // The card's bottom-left cut, so the effects follow its outline.
    property real cutBottomLeft: 24

    // Readouts the rain must not cross: it is cleared from their bounds, so
    // figures stay legible while it falls around them.
    property var keepOut: []

    // What drives the continuous effects.
    property bool   streaming: false
    property string phase: ""        // connecting|latency|download|upload
    property real   rate: 0          // bit/s

    // 0..1 on a log scale, so a 20 Mbit/s line already looks busy and a
    // gigabit one does not blow the effects out.
    readonly property real intensity: Math.max(0.15, Math.min(1,
        Math.log(Math.max(0, rate) / 1e6 + 1) / Math.LN10 / 3))

    readonly property color downColor: Colours.accentSecondary
    readonly property color upColor:   Colours.accentPrimary

    // ── State ────────────────────────────────────────────────────────────
    // Plain arrays mutated in place: the canvas repaints every frame anyway,
    // so nothing needs change notifications. _alive is the one reactive
    // figure, and only to let the loop stop.
    property var _rain: []
    property var _packets: []
    property var _shards: []
    property var _waves: []
    property var _bars: []
    property int _alive: 0
    property real _packetDebt: 0
    property real _sonarClock: 0
    property real _paintClock: 0

    // Hex only: block shades rendered as grey smudges at this size.
    readonly property string _glyphs: "0123456789ABCDEF"

    FrameAnimation {
        running: fx.visible && (fx.streaming || fx._alive > 0)
        onTriggered: fx._step(Math.min(frameTime, 0.05))
        onRunningChanged: if (!running) { fx._paintClock = 0; fx.requestPaint() }
    }

    // ── Public ───────────────────────────────────────────────────────────
    // kind: "start" | "phase" | "done" | "fail". forPhase names the phase the
    // burst belongs to: called from a phase-change handler, the phase
    // binding here may not have caught up yet.
    function burst(kind, forPhase) {
        var ph = forPhase !== undefined ? forPhase : phase
        var n = { start: 28, phase: 14, done: 44, fail: 22 }[kind] || 16
        var palette = kind === "fail" ? [CP.red, CP.red, CP.magenta]
                    : kind === "done" ? [downColor, upColor, CP.neon]
                    : ph === "upload" ? [upColor, upColor, CP.magenta]
                    : [downColor, downColor, CP.magenta]
        for (var i = 0; i < n; i++) {
            var a = Math.random() * Math.PI * 2
            var sp = 110 + Math.random() * (kind === "done" ? 260 : 200)
            _shards.push({
                x: cx + Math.cos(a) * radius, y: cy + Math.sin(a) * radius,
                vx: Math.cos(a) * sp, vy: Math.sin(a) * sp,
                len: 3 + Math.random() * 7,
                life: 0, ttl: 0.4 + Math.random() * 0.4,
                square: Math.random() < 0.3,
                color: _c(palette[i % palette.length])
            })
        }
        if (kind !== "phase")
            _waves.push({ r: radius, speed: kind === "done" ? 150 : 120, life: 0, ttl: 0.45,
                          color: _c(palette[0]), width: 2 })
        if (kind === "done")
            _waves.push({ r: radius, speed: 90, life: -0.08, ttl: 0.5, color: _c(palette[1]), width: 1 })
        tear(kind === "fail" ? [CP.red, CP.magenta] : [downColor, CP.magenta, upColor],
             kind === "phase" ? 3 : 6)
        _alive = _count()
    }

    // Digital tearing: a few thin horizontal bars that jump to new places a
    // couple of times and vanish. Stepped, never eased.
    function tear(colors, count) {
        colors = colors || [downColor, CP.magenta, upColor]
        count = count || 4
        for (var i = 0; i < count; i++)
            _bars.push({ colors: colors, life: 0, ttl: 0.08 + Math.random() * 0.14,
                         hop: 0, x: 0, y: 0, w: 0, h: 0, color: _c(colors[0]) })
        _alive = _count()
    }

    // ── Simulation ───────────────────────────────────────────────────────
    function _count() {
        var r = 0
        for (var i = 0; i < _rain.length; i++) if (_rain[i].on) r++
        return r + _packets.length + _shards.length + _waves.length + _bars.length
    }

    // Palette entries arrive both as colour strings (Colors.js) and as colour
    // values (Colours); stored normalised so drawing can read .r/.g/.b.
    function _c(v) { return typeof v === "string" ? Qt.color(v) : v }

    function _glyph() { return _glyphs.charAt(Math.floor(Math.random() * _glyphs.length)) }

    function _step(dt) {
        var flowing = streaming && (phase === "download" || phase === "upload")
        var dir = phase === "upload" ? -1 : 1

        // Rain: one column every 12 px. Sparse and slow until data flows.
        var cols = Math.floor(width / 12)
        if (_rain.length !== cols) {
            _rain = []
            for (var c = 0; c < cols; c++)
                _rain.push({ on: false, y: 0, speed: 0, len: 5, glyphs: [] })
        }
        var density = flowing ? 0.25 + intensity * 0.5 : 0.08
        for (var k = 0; k < _rain.length; k++) {
            var col = _rain[k]
            if (!col.on) {
                if (streaming && Math.random() < density * dt * 1.6) {
                    col.on = true
                    col.len = 3 + Math.floor(Math.random() * 4)
                    col.dir = flowing ? dir : 1
                    col.speed = flowing ? 45 + intensity * 150 + Math.random() * 40
                                        : 18 + Math.random() * 14
                    col.y = col.dir > 0 ? -col.len * 10 : height + col.len * 10
                    col.glyphs = []
                    for (var g = 0; g < col.len; g++) col.glyphs.push(_glyph())
                }
                continue
            }
            col.y += col.speed * col.dir * dt
            for (var gi = 0; gi < col.len; gi++)
                if (Math.random() < 0.06) col.glyphs[gi] = _glyph()
            if (col.y > height + col.len * 10 || col.y < -col.len * 10) col.on = false
        }

        // Packets.
        if (flowing) {
            _packetDebt += (8 + intensity * 46) * dt
            while (_packetDebt >= 1 && _packets.length < 80) {
                _packetDebt -= 1
                var a = Math.random() * Math.PI * 2
                var far = radius + 40 + Math.random() * 110
                _packets.push({
                    a: a,
                    d: dir > 0 ? far : radius + 2,
                    end: dir > 0 ? radius : far,
                    dir: dir,
                    speed: 50 + intensity * 130 + Math.random() * 50,
                    color: dir > 0 ? downColor : upColor
                })
            }
        } else {
            _packetDebt = 0
        }
        for (var p = _packets.length - 1; p >= 0; p--) {
            var pk = _packets[p]
            pk.d -= pk.dir * pk.speed * dt
            if ((pk.dir > 0 && pk.d <= pk.end) || (pk.dir < 0 && pk.d >= pk.end))
                _packets.splice(p, 1)
        }

        // Sonar while latency is probed.
        if (streaming && phase === "latency") {
            _sonarClock += dt
            if (_sonarClock >= 0.38) {
                _sonarClock = 0
                _waves.push({ r: radius, speed: 70, life: 0, ttl: 0.7,
                              color: _c(downColor), width: 1 })
            }
        }

        for (var s = _shards.length - 1; s >= 0; s--) {
            var sh = _shards[s]
            sh.life += dt
            var drag = Math.exp(-3.2 * dt)
            sh.vx *= drag; sh.vy *= drag
            sh.x += sh.vx * dt; sh.y += sh.vy * dt
            if (sh.life >= sh.ttl) _shards.splice(s, 1)
        }
        for (var w = _waves.length - 1; w >= 0; w--) {
            var wv = _waves[w]
            wv.life += dt
            if (wv.life > 0) wv.r += wv.speed * dt
            if (wv.life >= wv.ttl) _waves.splice(w, 1)
        }
        for (var b = _bars.length - 1; b >= 0; b--) {
            var bar = _bars[b]
            bar.life += dt
            // Hop every 45 ms: discrete jumps read as a signal fault.
            var hop = Math.floor(bar.life / 0.045)
            if (hop !== bar.hop || bar.w === 0) {
                bar.hop = hop
                bar.w = 20 + Math.random() * width * 0.45
                bar.x = Math.random() * (width - bar.w)
                bar.y = Math.random() * height
                bar.h = 1 + Math.floor(Math.random() * 3)
                bar.color = _c(bar.colors[Math.floor(Math.random() * bar.colors.length)])
            }
            if (bar.life >= bar.ttl) _bars.splice(b, 1)
        }

        _alive = _count()

        // ~40 fps is plenty for this and halves the text drawing on a
        // high refresh monitor.
        _paintClock += dt
        if (_paintClock >= 0.024) {
            _paintClock = 0
            requestPaint()
        }
    }

    // ── Drawing ──────────────────────────────────────────────────────────
    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        if (_alive === 0 && !streaming) return

        var w = width, h = height
        ctx.save()
        ctx.beginPath()
        ctx.moveTo(0, 0); ctx.lineTo(w, 0); ctx.lineTo(w, h)
        ctx.lineTo(cutBottomLeft, h); ctx.lineTo(0, h - cutBottomLeft)
        ctx.closePath()
        ctx.clip()

        // Rain, then the ring's inside cleared so the key and value stay
        // readable over it.
        ctx.font = "9px 'JetBrains Mono'"
        ctx.textAlign = "center"
        var rainColor = phase === "upload" ? upColor : downColor
        for (var k = 0; k < _rain.length; k++) {
            var col = _rain[k]
            if (!col.on) continue
            var x = k * 12 + 6
            for (var g = 0; g < col.len; g++) {
                // Index 0 is the head: the leading glyph in the direction of travel.
                var y = col.y - g * 10 * col.dir
                var alpha = g === 0 ? 0.42 : 0.24 * (1 - g / col.len)
                ctx.fillStyle = g === 0
                    ? Qt.rgba(Math.min(1, rainColor.r + 0.4), Math.min(1, rainColor.g + 0.4),
                              Math.min(1, rainColor.b + 0.4), alpha)
                    : Qt.rgba(rainColor.r, rainColor.g, rainColor.b, alpha)
                ctx.fillText(col.glyphs[g], x, y)
            }
        }
        ctx.globalCompositeOperation = "destination-out"
        ctx.fillStyle = "black"
        ctx.beginPath()
        ctx.arc(cx, cy, radius - 3, 0, Math.PI * 2)
        ctx.fill()
        for (var ko = 0; ko < keepOut.length; ko++) {
            var item = keepOut[ko]
            if (!item || !item.visible || item.opacity <= 0) continue
            var tl = item.mapToItem(fx, 0, 0)
            ctx.fillRect(tl.x - 4, tl.y - 3, item.width + 8, item.height + 6)
        }

        ctx.globalCompositeOperation = "lighter"

        for (var p = 0; p < _packets.length; p++) {
            var pk = _packets[p]
            var px = cx + Math.cos(pk.a) * pk.d
            var py = cy + Math.sin(pk.a) * pk.d
            // Brighter near the ring: incoming ones fade in as they
            // approach, outgoing ones fade out as they leave. A hard pop at
            // the far end looks like a bug.
            var t = 1 - Math.min(1, (pk.d - radius) / 150)
            var pa = pk.dir > 0 ? 0.25 + t * 0.6 : 0.85 * t
            var tx = Math.cos(pk.a) * 6 * pk.dir, ty = Math.sin(pk.a) * 6 * pk.dir
            ctx.strokeStyle = Qt.rgba(pk.color.r, pk.color.g, pk.color.b, pa * 0.5)
            ctx.lineWidth = 1
            ctx.beginPath()
            ctx.moveTo(px + tx, py + ty)
            ctx.lineTo(px, py)
            ctx.stroke()
            ctx.fillStyle = Qt.rgba(pk.color.r, pk.color.g, pk.color.b, pa)
            ctx.fillRect(Math.round(px) - 1, Math.round(py) - 1, 2, 2)
        }

        for (var wI = 0; wI < _waves.length; wI++) {
            var wv = _waves[wI]
            if (wv.life <= 0) continue
            var wa = 0.5 * (1 - wv.life / wv.ttl)
            var wc = wv.color
            ctx.strokeStyle = Qt.rgba(wc.r, wc.g, wc.b, wa)
            ctx.lineWidth = wv.width
            ctx.beginPath()
            ctx.arc(cx, cy, wv.r, 0, Math.PI * 2)
            ctx.stroke()
        }

        for (var s = 0; s < _shards.length; s++) {
            var sh = _shards[s]
            var sc = sh.color
            var sa = 1 - sh.life / sh.ttl
            if (sh.square) {
                ctx.fillStyle = Qt.rgba(sc.r, sc.g, sc.b, sa)
                ctx.fillRect(Math.round(sh.x) - 1, Math.round(sh.y) - 1, 2, 2)
            } else {
                var v = Math.sqrt(sh.vx * sh.vx + sh.vy * sh.vy) || 1
                ctx.strokeStyle = Qt.rgba(sc.r, sc.g, sc.b, sa)
                ctx.lineWidth = 1.2
                ctx.beginPath()
                ctx.moveTo(sh.x, sh.y)
                ctx.lineTo(sh.x - sh.vx / v * sh.len, sh.y - sh.vy / v * sh.len)
                ctx.stroke()
            }
        }

        ctx.globalCompositeOperation = "source-over"
        for (var b = 0; b < _bars.length; b++) {
            var bar = _bars[b]
            if (bar.w === 0) continue    // not placed until its first step
            var bc = bar.color
            ctx.fillStyle = Qt.rgba(bc.r, bc.g, bc.b, 0.45)
            ctx.fillRect(Math.round(bar.x), Math.round(bar.y), Math.round(bar.w), bar.h)
        }

        ctx.restore()
    }
}
