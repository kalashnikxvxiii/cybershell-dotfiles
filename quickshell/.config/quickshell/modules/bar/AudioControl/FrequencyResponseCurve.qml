// FrequencyResponseCurve.qml — Interactive EQ response curve.
// 10 control points draggable, smooth cubic interpolation between, gradient fill below,
// live CAVA FFT layer at low opacity behind.
//
// Math:
//   X log-mapping: 31Hz→0, 16kHz→width  (logarithmic spacing of bands)
//   Y mapping: gain in [-12, +12] dB → y in [height, 0]
//
// Drawing layers (z-order):
//   1. CAVA bars (alpha 0.18, separate Canvas at z=0, redraws 30Hz)
//   2. Grid lines (z=1)
//   3. Zero reference (z=2)
//   4. Gradient fill below curve (z=3)
//   5. Curve stroke (z=4)
//   6. 10 control point circles (z=5)
import "../../../common/Colors.js" as CP
import "../../../common"
import QtQuick

Item {
    id: root

    // ── Public API ───────────────────────────────────────────────
    signal bandSelected(int idx)
    signal bandEdited(int idx, real gain)

    // ── Constants ────────────────────────────────────────────────
    readonly property var freqs: [31, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    readonly property real logMin: Math.log10(freqs[0])
    readonly property real logMax: Math.log10(freqs[9])
    readonly property real logRange: logMax - logMin

    // X position for band index
    function _xForBand(idx) {
        var t = (Math.log10(freqs[idx]) - logMin) / logRange
        return t * width
    }
    // Y position for gain in dB
    function _yForGain(gain) {
        var clamped = Math.max(-12, Math.min(12, gain))
        var t = (clamped + 12) / 24    // 0..1
        return height * (1 - t)
    }
    // Inverse: gain from Y
    function _gainFromY(y) {
        if (height <= 0) return 0
        var t = 1 - y / height
        var g = t * 24 - 12
        return Math.max(-12, Math.min(12, g))
    }
    // Hit test: find closest band to X within tolerance
    function _bandAtX(x, tol) {
        var bestIdx = -1
        var bestDist = tol
        for (var i = 0; i < 10; i++) {
            var bx = _xForBand(i)
            var d = Math.abs(bx - x)
            if (d < bestDist) {
                bestDist = d
                bestIdx = i
            }
        }
        return bestIdx
    }

    // ── State for drag ───────────────────────────────────────────
    property int  _draggingBand: -1
    property real _dragGain: 0

    // ── CAVA layer (background, alpha 0.18) ──────────────────────
    Canvas {
        id: cavaLayer
        anchors.fill: parent
        z: 0
        renderTarget: Canvas.FramebufferObject

        // Redraw every CAVA value update via Connections
        Connections {
            target: Audio.cava
            function onValuesChanged() { cavaLayer.requestPaint() }
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (!Audio.cava || !Audio.cava.values) return
            var vals = Audio.cava.values
            var n = vals.length
            if (n === 0) return
            ctx.fillStyle = CP.alpha(CP.neon, 0.18).toString()
            var barW = Math.max(1, width / n - 1)
            var midY = height / 2
            for (var i = 0; i < n; i++) {
                var x = (i / n) * width
                var bh = Math.min(height * 0.45, vals[i] * height * 0.45)
                ctx.fillRect(x, midY, barW, -bh)
            }
        }
    }

    // ── Curve layer (foreground) ─────────────────────────────────
    Canvas {
        id: curve
        anchors.fill: parent
        z: 1
        renderTarget: Canvas.FramebufferObject

        Connections {
            target: AudioControlState
            function onEqBandsChanged() { curve.requestPaint() }
            function onEqSelectedBandChanged() { curve.requestPaint() }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var w = width, h = height
            if (w <= 0 || h <= 0) return

            // ── Grid: 10 vertical band lines
            ctx.strokeStyle = CP.alpha(CP.neon, 0.08).toString()
            ctx.lineWidth = 0.5
            for (var i = 0; i < 10; i++) {
                var x = root._xForBand(i)
                ctx.beginPath()
                ctx.moveTo(x, 0)
                ctx.lineTo(x, h)
                ctx.stroke()
            }

            // ── Horizontal grid: ±6 dashed
            ctx.strokeStyle = CP.alpha(CP.neon, 0.10).toString()
            ctx.setLineDash([2, 2])
            ctx.beginPath()
            ctx.moveTo(0, h * 0.25); ctx.lineTo(w, h * 0.25)
            ctx.moveTo(0, h * 0.75); ctx.lineTo(w, h * 0.75)
            ctx.stroke()
            ctx.setLineDash([])

            // ── Zero reference (mid)
            ctx.strokeStyle = CP.alpha(CP.neon, 0.5).toString()
            ctx.lineWidth = 0.8
            ctx.beginPath()
            ctx.moveTo(0, h / 2); ctx.lineTo(w, h / 2)
            ctx.stroke()

            // ── Collect 10 points
            var pts = []
            for (var b = 0; b < 10; b++) {
                var gain = (AudioControlState.eqBands[b] !== undefined) ? AudioControlState.eqBands[b] : 0
                if (b === root._draggingBand) gain = root._dragGain
                pts.push({ x: root._xForBand(b), y: root._yForGain(gain) })
            }

            // ── Curve path with Catmull-Rom-like cubic Bezier
            ctx.beginPath()
            ctx.moveTo(pts[0].x, pts[0].y)
            for (var k = 0; k < 9; k++) {
                var p0 = (k > 0) ? pts[k - 1] : pts[k]
                var p1 = pts[k]
                var p2 = pts[k + 1]
                var p3 = (k < 8) ? pts[k + 2] : pts[k + 1]
                // Tangent control points (Catmull-Rom-like)
                var cp1x = p1.x + (p2.x - p0.x) / 6
                var cp1y = p1.y + (p2.y - p0.y) / 6
                var cp2x = p2.x - (p3.x - p1.x) / 6
                var cp2y = p2.y - (p3.y - p1.y) / 6
                ctx.bezierCurveTo(cp1x, cp1y, cp2x, cp2y, p2.x, p2.y)
            }

            // ── Gradient fill under curve
            ctx.lineTo(pts[9].x, h)
            ctx.lineTo(pts[0].x, h)
            ctx.closePath()
            var grad = ctx.createLinearGradient(0, 0, 0, h)
            grad.addColorStop(0, CP.alpha(CP.neon, 0.25).toString())
            grad.addColorStop(1, CP.alpha(CP.neon, 0.0).toString())
            ctx.fillStyle = grad
            ctx.fill()

            // ── Curve stroke (redraw the curve sans closure for stroke)
            ctx.beginPath()
            ctx.moveTo(pts[0].x, pts[0].y)
            for (var k2 = 0; k2 < 9; k2++) {
                var p0b = (k2 > 0) ? pts[k2 - 1] : pts[k2]
                var p1b = pts[k2]
                var p2b = pts[k2 + 1]
                var p3b = (k2 < 8) ? pts[k2 + 2] : pts[k2 + 1]
                var cp1xb = p1b.x + (p2b.x - p0b.x) / 6
                var cp1yb = p1b.y + (p2b.y - p0b.y) / 6
                var cp2xb = p2b.x - (p3b.x - p1b.x) / 6
                var cp2yb = p2b.y - (p3b.y - p1b.y) / 6
                ctx.bezierCurveTo(cp1xb, cp1yb, cp2xb, cp2yb, p2b.x, p2b.y)
            }
            ctx.strokeStyle = CP.neon.toString()
            ctx.lineWidth = 2
            ctx.stroke()

            // ── 10 control point circles
            for (var c = 0; c < 10; c++) {
                ctx.beginPath()
                ctx.arc(pts[c].x, pts[c].y, c === AudioControlState.eqSelectedBand ? 6 : 4, 0, Math.PI * 2)
                ctx.fillStyle = CP.neon.toString()
                ctx.fill()
                ctx.strokeStyle = "white"
                ctx.lineWidth = 1
                ctx.stroke()
            }
        }
    }

    // ── Drag interaction ─────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.SizeVerCursor
        onPressed: mouse => {
            var idx = root._bandAtX(mouse.x, 24)
            if (idx >= 0) {
                root._draggingBand = idx
                root._dragGain = root._gainFromY(mouse.y)
                AudioControlState.eqSelectedBand = idx
                root.bandSelected(idx)
                curve.requestPaint()
            }
        }
        onPositionChanged: mouse => {
            if (root._draggingBand < 0 || !pressed) return
            var g = root._gainFromY(mouse.y)
            // Snap to 0 within ±0.5
            if (Math.abs(g) < 0.5) g = 0
            root._dragGain = Math.round(g)
            curve.requestPaint()
        }
        onReleased: {
            if (root._draggingBand >= 0) {
                root.bandEdited(root._draggingBand, root._dragGain)
                AudioControlState.setEqBand(root._draggingBand + 1, root._dragGain)
                root._draggingBand = -1
                curve.requestPaint()
            }
        }
        onWheel: wheel => {
            // Wheel over a band → ±1 dB
            var idx = root._bandAtX(wheel.x, 24)
            if (idx < 0) return
            var cur = (AudioControlState.eqBands[idx] !== undefined) ? AudioControlState.eqBands[idx] : 0
            var newG = Math.max(-12, Math.min(12, cur + (wheel.angleDelta.y > 0 ? 1 : -1)))
            AudioControlState.setEqBand(idx + 1, newG)
            AudioControlState.eqSelectedBand = idx
            root.bandSelected(idx)
            wheel.accepted = true
        }
    }
}
