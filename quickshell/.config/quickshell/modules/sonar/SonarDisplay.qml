// SonarDisplay.qml — the radar face of the Sonar panel.
//
// Draws range rings, a rotating sweep with a fading tail, and one blip per
// entry. A blip lights up when the sweep passes over it and decays until the
// next pass, the way a real display persists: entries are always there, but
// the sweep is what makes them speak.
//
// Entries are passed in, not read from a service, so the same face serves the
// network view and the bluetooth one:
//   { key, label, ring, connected, active, strength }
// ring is 0..1 — 0 at the centre, 1 at the outer range ring.
import QtQuick
import "../../common/Colors.js" as CP
import "../../common"

Item {
    id: face

    property var    entries: []       // see above
    property string accent: CP.cyan
    property string hoveredKey: ""
    property string selectedKey: ""
    // Set while the source is actually scanning: the sweep stops when it is not.
    property bool   sweeping: true
    // Bumped by the owner when the entry set changes, so the blip bookkeeping
    // can follow entries that come and go.
    property int    revision: 0

    signal picked(string key)

    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property real maxR: Math.min(width, height) / 2 - 10

    // ── Sweep state ──────────────────────────────────────────────────────
    // The angle is a plain number driven by the frame loop rather than a
    // NumberAnimation: the blips need to compare against it every frame, and
    // an animator would not publish it.
    property real _angle: -Math.PI / 2
    property real _pingClock: 0
    property var  _lit: ({})          // key -> 0..1 brightness
    property var  _pings: []          // { key, life }

    readonly property real sweepPeriod: 3.4

    FrameAnimation {
        running: face.visible
        onTriggered: face._step(Math.min(frameTime, 0.05))
    }

    function _keyAngle(key) {
        // Stable pseudo-random bearing per entry: the same network keeps its
        // place on the face between sweeps and between openings.
        var h = 0
        for (var i = 0; i < key.length; i++)
            h = (h * 31 + key.charCodeAt(i)) & 0x7fffffff
        return (h % 3600) / 3600 * Math.PI * 2
    }

    function _step(dt) {
        if (sweeping) {
            var before = _angle
            _angle += dt * Math.PI * 2 / sweepPeriod
            // Light every entry the sweep crossed during this frame.
            for (var i = 0; i < entries.length; i++) {
                var a = _keyAngle(entries[i].key)
                if (_crossed(before, _angle, a)) {
                    _lit[entries[i].key] = 1
                    _pings.push({ key: entries[i].key, life: 0 })
                }
            }
            if (_angle > Math.PI * 2) _angle -= Math.PI * 2
        }

        // Decay: a blip stays visible for about one sweep after being hit.
        for (var k in _lit) {
            _lit[k] -= dt / sweepPeriod
            if (_lit[k] <= 0) delete _lit[k]
        }
        for (var p = _pings.length - 1; p >= 0; p--) {
            _pings[p].life += dt
            if (_pings[p].life > 0.9) _pings.splice(p, 1)
        }
        canvas.requestPaint()
    }

    function _crossed(from, to, a) {
        // Works across the wrap at 2π, where `to` has not been folded yet.
        return (from <= a && a <= to) || (from <= a + Math.PI * 2 && a + Math.PI * 2 <= to)
    }

    function _pos(entry) {
        var a = _keyAngle(entry.key)
        var r = Math.max(0.08, Math.min(1, entry.ring)) * face.maxR
        return { x: face.cx + Math.cos(a) * r, y: face.cy + Math.sin(a) * r }
    }

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var c = Qt.color(face.accent)
            var cx = face.cx, cy = face.cy, R = face.maxR

            // Range rings and bearings.
            ctx.lineWidth = 1
            for (var i = 1; i <= 4; i++) {
                ctx.beginPath()
                ctx.arc(cx, cy, R * i / 4, 0, Math.PI * 2)
                ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, i === 4 ? 0.28 : 0.12)
                ctx.stroke()
            }
            ctx.beginPath()
            for (var b = 0; b < 8; b++) {
                var ba = b * Math.PI / 4
                ctx.moveTo(cx + Math.cos(ba) * R * 0.12, cy + Math.sin(ba) * R * 0.12)
                ctx.lineTo(cx + Math.cos(ba) * R, cy + Math.sin(ba) * R)
            }
            ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.07)
            ctx.stroke()

            // Bearing ticks just inside the outer ring, long every 45°.
            ctx.beginPath()
            for (var t = 0; t < 24; t++) {
                var ta = t * Math.PI / 12
                var len = (t % 3 === 0) ? 6 : 3
                ctx.moveTo(cx + Math.cos(ta) * (R - len), cy + Math.sin(ta) * (R - len))
                ctx.lineTo(cx + Math.cos(ta) * R, cy + Math.sin(ta) * R)
            }
            ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.22)
            ctx.stroke()

            // Centre mark: the station itself.
            ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.3)
            ctx.fillRect(cx - 1, cy - 1, 2, 2)

            // Sweep tail: wedges of falling alpha, since Canvas has no conic
            // gradient. Drawn additively so it reads as light, not paint.
            ctx.globalCompositeOperation = "lighter"
            if (face.sweeping) {
                // Wedges of falling alpha, overlapping by a hair so the seams
                // between them do not show as bands.
                var steps = 40, tail = Math.PI / 1.9
                for (var s = 0; s < steps; s++) {
                    var a0 = face._angle - tail * (s + 1.15) / steps
                    var a1 = face._angle - tail * s / steps
                    var fade = Math.pow(1 - s / steps, 1.8)
                    ctx.beginPath()
                    ctx.moveTo(cx, cy)
                    ctx.arc(cx, cy, R, a0, a1)
                    ctx.closePath()
                    ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.075 * fade)
                    ctx.fill()
                }
                // Leading edge, dim at the hub and bright at the rim: a line of
                // even weight read as a stick lying on the face.
                var hx = cx + Math.cos(face._angle) * R
                var hy = cy + Math.sin(face._angle) * R
                var lg = ctx.createLinearGradient(cx, cy, hx, hy)
                lg.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.05))
                lg.addColorStop(0.55, Qt.rgba(c.r, c.g, c.b, 0.45))
                lg.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0.95))
                ctx.beginPath()
                ctx.moveTo(cx, cy)
                ctx.lineTo(hx, hy)
                ctx.strokeStyle = lg
                ctx.lineWidth = 1.4
                ctx.stroke()

                // The rim glows where the sweep meets it.
                var rg = ctx.createRadialGradient(hx, hy, 0, hx, hy, 10)
                rg.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.45))
                rg.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0))
                ctx.beginPath()
                ctx.arc(hx, hy, 10, 0, Math.PI * 2)
                ctx.fillStyle = rg
                ctx.fill()
            }

            // Pings: the ripple a blip gives off as the sweep hits it.
            for (var p = 0; p < face._pings.length; p++) {
                var pg = face._pings[p]
                var e = face._entry(pg.key)
                if (!e) continue
                var pp = face._pos(e)
                var t = pg.life / 0.9
                ctx.beginPath()
                ctx.arc(pp.x, pp.y, 4 + t * 16, 0, Math.PI * 2)
                ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.5 * (1 - t))
                ctx.lineWidth = 1
                ctx.stroke()
            }

            // Blips.
            for (var n = 0; n < face.entries.length; n++) {
                var en = face.entries[n]
                var pos = face._pos(en)
                var lit = face._lit[en.key] || 0
                var sel = en.key === face.selectedKey
                var hov = en.key === face.hoveredKey
                var base = en.connected ? 0.55 : 0.2
                var alpha = Math.min(1, base + lit * 0.6 + (sel || hov ? 0.3 : 0))
                var col = en.connected ? Qt.color(CP.neon) : c

                if (lit > 0.05 || en.connected) {
                    var glow = ctx.createRadialGradient(pos.x, pos.y, 0, pos.x, pos.y, 11)
                    glow.addColorStop(0, Qt.rgba(col.r, col.g, col.b, 0.55 * Math.max(lit, en.connected ? 0.7 : 0)))
                    glow.addColorStop(1, Qt.rgba(col.r, col.g, col.b, 0))
                    ctx.beginPath()
                    ctx.arc(pos.x, pos.y, 11, 0, Math.PI * 2)
                    ctx.fillStyle = glow
                    ctx.fill()
                }
                // Square blips: the shell has no round corners anywhere else.
                var sz = sel || hov ? 5 : 3
                ctx.fillStyle = Qt.rgba(col.r, col.g, col.b, alpha)
                ctx.fillRect(Math.round(pos.x - sz / 2), Math.round(pos.y - sz / 2), sz, sz)

                if (sel) {
                    // Target brackets on the selected contact.
                    ctx.strokeStyle = Qt.rgba(col.r, col.g, col.b, 0.9)
                    ctx.lineWidth = 1
                    var d = 9, arm = 4
                    var corners = [[-1, -1], [1, -1], [-1, 1], [1, 1]]
                    for (var q = 0; q < 4; q++) {
                        var sx = pos.x + corners[q][0] * d, sy = pos.y + corners[q][1] * d
                        ctx.beginPath()
                        ctx.moveTo(sx - corners[q][0] * arm, sy)
                        ctx.lineTo(sx, sy)
                        ctx.lineTo(sx, sy - corners[q][1] * arm)
                        ctx.stroke()
                    }
                }
            }

            ctx.globalCompositeOperation = "source-over"

            // Label for the contact under the cursor or under the brackets.
            var tag = face.hoveredKey || face.selectedKey
            var te = face._entry(tag)
            if (te) {
                var tp = face._pos(te)
                ctx.font = "9px Oxanium"
                ctx.textAlign = tp.x > cx ? "right" : "left"
                ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.95)
                ctx.fillText(te.label, tp.x + (tp.x > cx ? -10 : 10), tp.y - 8)
            }
        }
    }

    function _entry(key) {
        for (var i = 0; i < entries.length; i++) if (entries[i].key === key) return entries[i]
        return null
    }

    // Nearest contact within grabbing distance; nothing otherwise, so the
    // empty face does not swallow the pointer.
    function _hit(mx, my) {
        var best = null, bestD = 14 * 14
        for (var i = 0; i < entries.length; i++) {
            var p = _pos(entries[i])
            var d = (p.x - mx) * (p.x - mx) + (p.y - my) * (p.y - my)
            if (d < bestD) { bestD = d; best = entries[i] }
        }
        return best
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onPositionChanged: mouse => {
            var e = face._hit(mouse.x, mouse.y)
            face.hoveredKey = e ? e.key : ""
        }
        onExited: face.hoveredKey = ""
        onClicked: mouse => {
            var e = face._hit(mouse.x, mouse.y)
            if (e) face.picked(e.key)
        }
    }

    onRevisionChanged: canvas.requestPaint()
}
