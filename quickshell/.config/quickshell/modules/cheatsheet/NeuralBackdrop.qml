// NeuralBackdrop.qml -- a faint neural mesh that breathes behind the keymap.
//
// Two static meshes breathe in opposite phase: painted once, then only their
// opacity moves. A few signals travel along the links. Everything steps on one
// Ticker and rests when `live` is false.
pragma ComponentBehavior: Bound

import QtQuick
import "../../common/effects"
import "../../common/Colors.js" as CP

Item {
    id: root

    property bool live: false

    readonly property int cols: 15
    readonly property int rows: 9
    property var mesh: ({ a: [], b: [] })

    function noise(seed) {
        var v = Math.sin(seed * 127.1 + 311.7) * 43758.5453
        return v - Math.floor(v)
    }

    function nodeAt(c, r) {
        var seed = c * 31 + r * 17
        return [(c + 0.5 + (noise(seed) - 0.5) * 0.7) * width / cols,
                (r + 0.5 + (noise(seed + 1) - 0.5) * 0.7) * height / rows]
    }

    // A link between two nodes: straight run then a 45 degree run, like the wheel
    function link(p, q) {
        var dx = q[0] - p[0], dy = q[1] - p[1]
        var diag = Math.min(Math.abs(dx), Math.abs(dy))
        var flat = Math.abs(dx) > Math.abs(dy)
        var run = Math.max(Math.abs(dx), Math.abs(dy)) - diag
        var mid = [p[0] + (flat ? Math.sign(dx) * run : 0), p[1] + (flat ? 0 : Math.sign(dy) * run)]
        return [p, mid, q]
    }

    function buildMesh() {
        if (width <= 0 || height <= 0) return
        var a = [], b = []
        for (var c = 0; c < cols; c++) {
            for (var r = 0; r < rows; r++) {
                var seed = c * 13 + r * 7
                var p = nodeAt(c, r)
                var targets = [[c + 1, r], [c, r + 1], [c + 1, r + 1], [c + 1, r - 1]]
                for (var t = 0; t < targets.length; t++) {
                    var tc = targets[t][0], tr = targets[t][1]
                    if (tc >= cols || tr >= rows || tr < 0) continue
                    if (noise(seed + t * 3) > 0.5) continue
                    var line = link(p, nodeAt(tc, tr));
                    (noise(seed + t * 5 + 9) > 0.5 ? a : b).push(line)
                }
            }
        }
        mesh = { a: a, b: b }
    }

    onWidthChanged: buildMesh()
    onHeightChanged: buildMesh()
    Component.onCompleted: buildMesh()

    component Mesh: Canvas {
        id: layer
        property var lines: []
        property color tone: CP.cyan

        anchors.fill: parent
        onLinesChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.lineWidth = 1
            ctx.strokeStyle = tone
            ctx.fillStyle = tone
            for (var i = 0; i < lines.length; i++) {
                var l = lines[i]
                ctx.beginPath()
                ctx.moveTo(l[0][0], l[0][1])
                ctx.lineTo(l[1][0], l[1][1])
                ctx.lineTo(l[2][0], l[2][1])
                ctx.stroke()
                ctx.fillRect(l[0][0] - 1.5, l[0][1] - 1.5, 3, 3)
                ctx.fillRect(l[2][0] - 1.5, l[2][1] - 1.5, 3, 3)
            }
        }
    }

    Pulse {
        id: breath
        running: root.live
        from: 0
        to: 1
        halfMs: 2800
        sine: true
    }

    Mesh {
        lines: root.mesh.a
        tone: CP.cyan
        opacity: 0.05 + 0.16 * breath.k
    }

    Mesh {
        lines: root.mesh.b
        tone: CP.magenta
        opacity: 0.05 + 0.16 * (1 - breath.k)
    }

    // Signals running along the links
    Repeater {
        id: signals
        model: 12

        Rectangle {
            required property int index
            property var path: null
            property real progress: 0
            width: 4
            height: 4
            visible: path !== null
            color: index % 2 === 0 ? CP.cyan : CP.magenta
            opacity: 0.8
        }
    }

    Ticker {
        running: root.live
        onTicked: {
            var all = root.mesh.a.concat(root.mesh.b)
            if (all.length === 0) return
            for (var i = 0; i < signals.count; i++) {
                var s = signals.itemAt(i)
                if (s.path === null || s.progress >= 1) {
                    s.path = all[Math.floor(Math.random() * all.length)]
                    s.progress = 0
                }
                s.progress += 0.03
                var p = s.path
                // First half of the progress on the straight run, then the diagonal
                var from = s.progress < 0.5 ? p[0] : p[1]
                var to = s.progress < 0.5 ? p[1] : p[2]
                var f = s.progress < 0.5 ? s.progress * 2 : (s.progress - 0.5) * 2
                s.x = from[0] + (to[0] - from[0]) * f - 2
                s.y = from[1] + (to[1] - from[1]) * f - 2
            }
        }
    }
}
