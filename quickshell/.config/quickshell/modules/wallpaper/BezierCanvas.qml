import "../../common/Colors.js" as CP
import "../../common"
import "BezierPresets.js" as Presets
import QtQuick

Item {
    id: root

    property string bezier: "0.54,0,0.34,0.99"
    signal bezierEdited(string newBezier)

    // Parsed math coords
    property real _x1: 0.54
    property real _y1: 0.0
    property real _x2: 0.34
    property real _y2: 0.99

    readonly property real _yMin: -0.6
    readonly property real _yMax:  1.6

    implicitWidth: 260
    implicitHeight: 260

    onBezierChanged: _parseBezier()
    Component.onCompleted: _parseBezier()

    function _parseBezier() {
        var p = bezier.split(",")
        if (p.length === 4) {
            _x1 = parseFloat(p[0])
            _y1 = parseFloat(p[1])
            _x2 = parseFloat(p[2])
            _y2 = parseFloat(p[3])
            canvas.requestPaint()
        }
    }

    function _mathToCanvas(mx, my) {
        var pad = canvas.pad
        var w = canvas.width
        var h = canvas.height
        var px = pad + mx * (w - 2*pad)
        var yNorm = (my - _yMin) / (_yMax - _yMin)
        var py = pad + (1 - yNorm) * (h - 2*pad)
        return [px, py]
    }

    function _canvasToMath(px, py) {
        var pad = canvas.pad
        var w = canvas.width
        var h = canvas.height
        var mx = (px - pad) / (w - 2*pad)
        var yNorm = 1 - (py - pad) / (h - 2*pad)
        var my = _yMin + yNorm * (_yMax - _yMin)
        return [mx, my]
    }

    function _emit() {
        canvas.requestPaint()
        root.bezierEdited(Presets.formatBezier(_x1, _y1, _x2, _y2))
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject
        property int pad: 26

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var pad = canvas.pad
            var w = width, h = height

            // Background grid 10x10
            ctx.strokeStyle = "rgba(0, 255, 210, 0.08)"
            ctx.lineWidth = 1
            for (var i = 1; i < 10; i++) {
                var gx = pad + (i / 10) * (w - 2*pad)
                ctx.beginPath(); ctx.moveTo(gx, pad); ctx.lineTo(gx, h - pad); ctx.stroke()
                var gy = pad + (i / 10) * (h - 2*pad)
                ctx.beginPath(); ctx.moveTo(pad, gy); ctx.lineTo(w - pad, gy); ctx.stroke()
            }

            // y=0 and y=1 reference lines
            var p0 = root._mathToCanvas(0, 0)
            var p3 = root._mathToCanvas(1, 1)
            ctx.strokeStyle = "rgba(0, 255, 210, 0.28)"
            ctx.lineWidth = 1
            ctx.beginPath(); ctx.moveTo(pad, p0[1]); ctx.lineTo(w - pad, p0[1]); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(pad, p3[1]); ctx.lineTo(w - pad, p3[1]); ctx.stroke()

            // Border
            ctx.strokeStyle = "rgba(252, 236, 12, 0.50)"
            ctx.lineWidth = 1
            ctx.strokeRect(pad, pad, w - 2*pad, h - 2*pad)

            // Control lines (dashed)
            var cp1 = root._mathToCanvas(root._x1, root._y1)
            var cp2 = root._mathToCanvas(root._x2, root._y2)
            ctx.setLineDash([4, 3])
            ctx.strokeStyle = "rgba(252, 236, 12, 0.45)"
            ctx.lineWidth = 1
            ctx.beginPath(); ctx.moveTo(p0[0], p0[1]); ctx.lineTo(cp1[0], cp1[1]); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(p3[0], p3[1]); ctx.lineTo(cp2[0], cp2[1]); ctx.stroke()
            ctx.setLineDash([])

            // Glow halo + main curve
            ctx.strokeStyle = "rgba(252, 236, 12, 0.30)"
            ctx.lineWidth = 6
            ctx.beginPath()
            ctx.moveTo(p0[0], p0[1])
            ctx.bezierCurveTo(cp1[0], cp1[1], cp2[0], cp2[1], p3[0], p3[1])
            ctx.stroke()

            ctx.strokeStyle = "rgba(252, 236, 12, 0.98)"
            ctx.lineWidth = 2
            ctx.beginPath()
            ctx.moveTo(p0[0], p0[1])
            ctx.bezierCurveTo(cp1[0], cp1[1], cp2[0], cp2[1], p3[0], p3[1])
            ctx.stroke()

            // Anchor points P0, P3 (yellow squares)
            ctx.fillStyle = "rgba(252, 236, 12, 1.0)"
            ctx.fillRect(p0[0] - 3, p0[1] - 3, 6, 6)
            ctx.fillRect(p3[0] - 3, p3[1] - 3, 6, 6)

            // ── Axis tick labels (0, 1 on both axes) ──────────────
            ctx.fillStyle = "rgba(252, 236, 12, 0.80)"
            ctx.font = "8px Oxanium"
            ctx.textAlign = "right"
            ctx.textBaseline = "middle"
            ctx.fillText("1", pad - 4, p3[1])
            ctx.fillText("0", pad - 4, p0[1])

            ctx.textAlign = "center"
            ctx.textBaseline = "top"
            ctx.fillText("0", p0[0], h - pad + 5)
            ctx.fillText("1", p3[0], h - pad + 5)

            // ── Axis legend (instructional) ────────────────────────
            ctx.fillStyle = "rgba(0, 255, 210, 0.70)"
            ctx.font = "9px Oxanium"
            ctx.textAlign = "center"
            ctx.textBaseline = "bottom"
            ctx.fillText("X · TIME ▶", w / 2, h - 3)

            // Y axis: routed label on the left margin
            ctx.save()
            ctx.translate(9, h / 2)
            ctx.rotate(-Math.PI / 2)
            ctx.textAlign = "center"
            ctx.textBaseline = "middle"
            ctx.fillText("Y · VALUE ▶", 0, 0)
            ctx.restore()

            // ── Zone hints (extended Y range explanation) ───────────
            ctx.fillStyle = "rgba(234, 0, 217, 0.3)"
            ctx.font = "12px Oxanium"
            ctx.textAlign = "right"
            ctx.textBaseline = "middle"
            var oy = root._mathToCanvas(0, 1.46)[1]
            ctx.fillText("OVERSHOOT", w - pad - 4, oy)
            var ay = root._mathToCanvas(0, -0.50)[1]
            ctx.fillText("ANTICIPATE", w - pad - 4, ay)

            // ── Modifier hint (top-right) ──────────────────────────
            ctx.fillStyle = "rgba(0, 255, 210, 0.45)"
            ctx.font = "8px Oxanium"
            ctx.textBaseline = "top"
            ctx.fillText("⇧ SHIFT · SNAP 0.05", w - pad - 2, 4)
        }
    }

    // Handle P1
    Item {
        id: handle1
        width: 14; height: 14
        property var pos: root._mathToCanvas(root._x1, root._y1)
        x: pos[0] - width/2
        y: pos[1] - height/2

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: ma1.pressed ? CP.cyan : CP.alpha(CP.cyan, 0.85)
            border.color: "white"
            border.width: 1
        }

        MouseArea {
            id: ma1
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            onPositionChanged: function(mouse) {
                if (!pressed) return
                var cpos = mapToItem(canvas, mouse.x, mouse.y)
                var m = root._canvasToMath(cpos.x, cpos.y)
                var mx = Math.max(0, Math.min(1, m[0]))
                var my = Math.max(root._yMin, Math.min(root._yMax, m[1]))
                if (mouse.modifiers & Qt.ShiftModifier) {
                    mx = Math.round(mx / 0.05) * 0.05
                    my = Math.round(my / 0.05) * 0.05
                }
                root._x1 = mx
                root._y1 = my
                root._emit()
            }
        }
    }

    // Handle P2
    Item {
        id: handle2
        width: 14; height: 14
        property var pos: root._mathToCanvas(root._x2, root._y2)
        x: pos[0] - width/2
        y: pos[1] - height/2

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: ma2.pressed ? CP.cyan : CP.alpha(CP.cyan, 0.85)
            border.color: "white"
            border.width: 1
        }

        MouseArea {
            id: ma2
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            onPositionChanged: function(mouse) {
                if (!pressed) return
                var cpos = mapToItem(canvas, mouse.x, mouse.y)
                var m = root._canvasToMath(cpos.x, cpos.y)
                var mx = Math.max(0, Math.min(1, m[0]))
                var my = Math.max(root._yMin, Math.min(root._yMax, m[1]))
                if (mouse.modifiers & Qt.ShiftModifier) {
                    mx = Math.round(mx / 0.05) * 0.05
                    my = Math.round(my / 0.05) * 0.05
                }
                root._x2 = mx
                root._y2 = my
                root._emit()
            }
        }
    }
}
