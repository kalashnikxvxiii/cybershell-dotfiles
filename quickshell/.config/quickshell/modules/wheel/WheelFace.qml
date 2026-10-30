// WheelFace.qml -- the quick action wheel, after Cyberpunk 2077's weapon wheel:
// notched cards around a thin ring, with a pointer from the hub to the active one.
//
// Hover and selection are separate states. The hit areas never move, only the
// card inside them does, so a card sliding away cannot drop its own hover. All
// the motion steps on one Ticker, which sleeps once everything has settled.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/effects"
import "../../common/Colors.js" as CP

Item {
    id: root

    // [{ key: "P", label: "Picker" }, ...]
    property var items: []
    property string title: ""
    property color accent: CP.cyan
    property string selectedKey: ""

    readonly property int cardWidth: 172
    readonly property int cardHeight: 58
    readonly property int orbitX: 290
    readonly property int orbitY: 190
    readonly property int ringRadius: 118
    readonly property int hoverSlide: 16
    readonly property int selectSlide: 30
    readonly property real hoverScale: 1.08
    readonly property real selectScale: 1.16
    readonly property int traceRevealMs: 170
    readonly property int count: items.length
    readonly property real step: count > 0 ? 2 * Math.PI / count : 0

    property int hovered: -1
    readonly property int selected: {
        for (var i = 0; i < count; i++)
            if (items[i].key === selectedKey) return i
        return -1
    }
    readonly property int active: selected >= 0 ? selected : hovered
    readonly property real activeAngle: active >= 0 ? Math.atan2(slotY(active), slotX(active)) : 0

    // Motion state, advanced by the Ticker
    property real traceProgress: 0
    property real glowPower: 0
    property real glowAngle: 0
    property int mutation: 0
    readonly property color glowColor: selected >= 0 ? CP.yellow : accent
    // On a pick the glow stutters, one value per mutation
    readonly property real glowOpacity: glowPower
        * (selected >= 0 ? 0.55 + core.noise(mutation * 3.1) * 0.6 : 1)

    signal picked(string key)
    signal cancelled()

    // Slot 0 sits at twelve o'clock, then clockwise
    function slotX(i) {
        return orbitX * Math.cos(-Math.PI / 2 + i * step)
    }

    function slotY(i) {
        return orbitY * Math.sin(-Math.PI / 2 + i * step)
    }

    // Shortest way round, so the glow never sweeps the long way
    function angleDelta(from, to) {
        var d = (to - from) % (2 * Math.PI)
        if (d > Math.PI) d -= 2 * Math.PI
        if (d < -Math.PI) d += 2 * Math.PI
        return d
    }

    function keyLabel(key) {
        if (key === "equal") return "="
        if (key === "minus") return "-"
        return key
    }

    onItemsChanged: { hovered = -1; core.requestPaint() }
    onActiveChanged: {
        traceProgress = 0
        // Coming out of nothing, the glow rises in place instead of sweeping in
        if (active >= 0 && glowPower === 0) glowAngle = activeAngle
        core.requestPaint()
    }
    onSelectedChanged: core.requestPaint()
    onAccentChanged: core.requestPaint()
    onGlowColorChanged: glow.requestPaint()

    // Any click on the free space between the cards cancels
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: root.cancelled()
    }

    // Drives the wheel's motion. Sleeps as soon as everything has settled, and
    // while the wheel is hidden.
    Ticker {
        id: motion
        running: root.visible && (root.selected >= 0
            || (root.active >= 0 && root.traceProgress < 1)
            || root.glowPower !== (root.active >= 0 ? 1 : 0)
            || (root.active >= 0 && root.glowAngle !== root.activeAngle))
        onTicked: {
            root.traceProgress = Math.min(1, root.traceProgress + motion.delta / root.traceRevealMs)

            var target = root.active >= 0 ? 1 : 0
            var dp = target - root.glowPower
            root.glowPower = Math.abs(dp) < 0.04 ? target : root.glowPower + dp * 0.5

            if (root.active >= 0) {
                var da = root.angleDelta(root.glowAngle, root.activeAngle)
                root.glowAngle = Math.abs(da) < 0.02 ? root.activeAngle : root.glowAngle + da * 0.55
            }

            if (root.selected >= 0) root.mutation++
            core.requestPaint()
        }
    }

    // The soft part of the glow: a wedge that fades towards the hub, blurred on
    // the GPU. It only repaints when the colour changes, and turning to follow
    // the active card costs a rotation.
    Canvas {
        id: glow
        anchors.centerIn: parent
        width: 2 * (root.ringRadius + 70)
        height: width
        rotation: root.glowAngle * 180 / Math.PI
        opacity: root.glowOpacity
        visible: opacity > 0
        onVisibleChanged: if (visible) requestPaint()

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1
            blurMax: 48
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var c = width / 2
            var col = root.glowColor
            var inner = 24
            var outer = root.ringRadius + 10
            var g = ctx.createRadialGradient(c, c, inner, c, c, outer)
            g.addColorStop(0, Qt.rgba(col.r, col.g, col.b, 0))
            g.addColorStop(0.4, Qt.rgba(col.r, col.g, col.b, 0.05))
            g.addColorStop(0.7, Qt.rgba(col.r, col.g, col.b, 0.2))
            g.addColorStop(0.9, Qt.rgba(col.r, col.g, col.b, 0.5))
            g.addColorStop(1, Qt.rgba(col.r, col.g, col.b, 0.7))
            ctx.fillStyle = g
            ctx.beginPath()
            ctx.moveTo(c, c)
            ctx.arc(c, c, outer, -0.55, 0.55)
            ctx.closePath()
            ctx.fill()
        }
    }

    Canvas {
        id: core
        anchors.fill: parent

        // Repeatable noise, so every slot keeps its own wiring between repaints
        function noise(seed) {
            var v = Math.sin(seed * 127.1 + 311.7) * 43758.5453
            return v - Math.floor(v)
        }

        // Where the ray from the hub enters the card, and along which axis
        function entryPoint(i) {
            var s = i === root.selected ? root.selectScale
                : i === root.hovered ? root.hoverScale : 1
            var slide = i === root.selected ? root.selectSlide
                : i === root.hovered ? root.hoverSlide : 0
            var angle = Math.atan2(root.slotY(i), root.slotX(i))
            var dx = root.slotX(i) + slide * Math.cos(angle)
            var dy = root.slotY(i) + slide * Math.sin(angle)
            var hx = root.cardWidth / 2 * s
            var hy = root.cardHeight / 2 * s
            var t = Math.min(hx / Math.max(Math.abs(dx), 1), hy / Math.max(Math.abs(dy), 1))
            return {
                x: width / 2 + dx * (1 - t),
                y: height / 2 + dy * (1 - t),
                vertical: hx / Math.max(Math.abs(dx), 1) > hy / Math.max(Math.abs(dy), 1),
                dirX: dx > 0 ? 1 : -1,
                dirY: dy > 0 ? 1 : -1
            }
        }

        // One PCB-style route, octilinear only: straight run, 45 degree run,
        // straight run, then a last stub that enters the card square on.
        function route(entry, offset, seed) {
            var stub = 12 + noise(seed + 1) * 22
            var bx = entry.x + (entry.vertical ? offset : 0)
            var by = entry.y + (entry.vertical ? 0 : offset)
            var px = bx - (entry.vertical ? 0 : entry.dirX * stub)
            var py = by - (entry.vertical ? entry.dirY * stub : 0)
            var ax = width / 2
            var ay = height / 2
            var dx = px - ax
            var dy = py - ay
            var diag = Math.min(Math.abs(dx), Math.abs(dy))
            var sx = dx > 0 ? 1 : -1
            var sy = dy > 0 ? 1 : -1
            var run = Math.max(Math.abs(dx), Math.abs(dy)) - diag
            var first = run * (0.15 + noise(seed + 2) * 0.7)
            var flat = Math.abs(dx) > Math.abs(dy)
            var e1 = [ax + (flat ? sx * first : 0), ay + (flat ? 0 : sy * first)]
            var e2 = [e1[0] + sx * diag, e1[1] + sy * diag]
            return [[ax, ay], e1, e2, [px, py], [bx, by]]
        }

        // Strokes the first `progress` (0..1) of the route and returns its tip
        function drawRoute(ctx, points, progress) {
            var total = 0
            for (var l = 1; l < points.length; l++)
                total += Math.hypot(points[l][0] - points[l - 1][0], points[l][1] - points[l - 1][1])
            var left = total * progress
            var tip = points[0]
            ctx.beginPath()
            ctx.moveTo(tip[0], tip[1])
            for (var p = 1; p < points.length && left > 0; p++) {
                var from = points[p - 1]
                var to = points[p]
                var len = Math.hypot(to[0] - from[0], to[1] - from[1])
                var f = len > 0 ? Math.min(1, left / len) : 1
                tip = [from[0] + (to[0] - from[0]) * f, from[1] + (to[1] - from[1]) * f]
                ctx.lineTo(tip[0], tip[1])
                left -= len
            }
            ctx.stroke()
            return tip
        }

        // Dead-end branches and pads that make each slot's wiring its own
        function drawBranches(ctx, points, seed) {
            for (var b = 1; b <= 2; b++) {
                if (noise(seed + 10 * b) < 0.35) continue
                var from = points[b]
                var to = points[b + 1]
                var f = 0.25 + noise(seed + 11 * b) * 0.5
                var mx = from[0] + (to[0] - from[0]) * f
                var my = from[1] + (to[1] - from[1]) * f
                var len = 10 + noise(seed + 12 * b) * 24
                var side = noise(seed + 13 * b) > 0.5 ? 1 : -1
                var ex = mx + side * len
                var ey = my + (noise(seed + 14 * b) > 0.5 ? len : -len)
                ctx.beginPath()
                ctx.moveTo(mx, my)
                ctx.lineTo(ex, ey)
                ctx.stroke()
                ctx.fillRect(ex - 2, ey - 2, 4, 4)
            }
        }

        // The bright edge of the glow, fading out sideways along the ring
        function drawGlowEdge(ctx, cx, cy, color, power, spread) {
            var slices = 28
            var size = 2 * spread / slices
            ctx.lineWidth = 1.5
            for (var k = 0; k < slices; k++) {
                var mid = root.glowAngle - spread + (k + 0.5) * size
                var u = (mid - root.glowAngle) / spread
                var strength = power * Math.pow(0.5 + 0.5 * Math.cos(Math.PI * u), 2)
                ctx.strokeStyle = Qt.rgba(color.r, color.g, color.b, 0.9 * strength)
                ctx.beginPath()
                ctx.arc(cx, cy, root.ringRadius, mid - size * 0.5, mid + size * 0.5)
                ctx.stroke()
            }
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var cx = width / 2
            var cy = height / 2
            var a = root.accent
            var tint = (alpha) => Qt.rgba(a.r, a.g, a.b, alpha)
            var i = root.active
            var picked = root.selected >= 0
            var live = root.glowColor

            ctx.lineWidth = 1
            ctx.strokeStyle = tint(0.25)
            ctx.beginPath()
            ctx.arc(cx, cy, root.ringRadius, 0, 2 * Math.PI)
            ctx.stroke()

            if (root.glowPower > 0) {
                // On a pick the edge opens up and stutters, in step with the traces
                var spread = picked ? 0.8 + noise(root.mutation * 5.3) * 0.25 : 0.72
                drawGlowEdge(ctx, cx, cy, live, root.glowOpacity, spread)
            }

            if (i >= 0) {
                var entry = entryPoint(i)
                var traces = 5
                for (var t = 0; t < traces; t++) {
                    // A pick re-rolls the wiring on every step: the traces mutate
                    var seed = (i + 1) * 37 + t * 5 + (picked ? root.mutation * 97 : 0)
                    var center = t === (traces - 1) / 2
                    var alpha = center ? 1 : 0.35 + noise(seed) * 0.45
                    if (picked && noise(seed + 40) < 0.2) alpha *= 0.25
                    var jitter = picked ? (noise(seed + 41) - 0.5) * 6 : 0
                    var offset = (t - (traces - 1) / 2) * 7 + jitter
                    var points = route(entry, offset, seed)
                    // Outer traces start a little later than the central one
                    var delay = Math.abs(t - (traces - 1) / 2) * 0.1
                    var progress = Math.min(1, Math.max(0, (root.traceProgress - delay) / (1 - delay)))
                    if (progress <= 0) continue

                    ctx.lineWidth = center ? 1.5 : 1
                    ctx.strokeStyle = Qt.rgba(live.r, live.g, live.b, alpha)
                    ctx.fillStyle = Qt.rgba(live.r, live.g, live.b, alpha)
                    var tip = drawRoute(ctx, points, progress)
                    if (progress >= 1) {
                        drawBranches(ctx, points, seed)
                        ctx.fillRect(tip[0] - 2, tip[1] - 2, 4, 4)
                    } else {
                        // The bright head of a trace still on its way
                        ctx.fillStyle = Qt.rgba(1, 1, 1, 0.9)
                        ctx.fillRect(tip[0] - 1.5, tip[1] - 1.5, 3, 3)
                    }
                }
            }

            // Hub block, opaque and painted last so the traces pass behind it:
            // an octagon filled with a faint dot grid
            var h = 66
            var n = 20
            ctx.lineWidth = 1
            ctx.beginPath()
            ctx.moveTo(cx - h + n, cy - h)
            ctx.lineTo(cx + h - n, cy - h)
            ctx.lineTo(cx + h, cy - h + n)
            ctx.lineTo(cx + h, cy + h - n)
            ctx.lineTo(cx + h - n, cy + h)
            ctx.lineTo(cx - h + n, cy + h)
            ctx.lineTo(cx - h, cy + h - n)
            ctx.lineTo(cx - h, cy - h + n)
            ctx.closePath()
            ctx.fillStyle = "#00060e"
            ctx.fill()
            ctx.strokeStyle = tint(0.35)
            ctx.stroke()
            ctx.fillStyle = tint(0.22)
            for (var gx = -h + 8; gx < h - 4; gx += 8)
                for (var gy = -h + 8; gy < h - 4; gy += 8)
                    if (Math.abs(gx) + Math.abs(gy) < 2 * h - n - 4)
                        ctx.fillRect(cx + gx, cy + gy, 1, 1)
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 3

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "◢ " + root.title.toUpperCase()
            font.family: "Oxanium"
            font.pixelSize: 13
            font.bold: true
            font.letterSpacing: 1.5
            color: root.accent
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "ESC"
            font.family: "Oxanium"
            font.pixelSize: 10
            font.letterSpacing: 2
            color: "#8a9a9c"
        }
    }

    Repeater {
        model: root.items

        // Stationary hit area
        Item {
            id: slot
            required property var modelData
            required property int index

            readonly property bool isHovered: index === root.hovered && root.selected < 0
            readonly property bool isSelected: index === root.selected
            readonly property real angle: Math.atan2(root.slotY(index), root.slotX(index))
            readonly property real slide: isSelected ? root.selectSlide : isHovered ? root.hoverSlide : 0

            x: root.width / 2 + root.slotX(index) - width / 2
            y: root.height / 2 + root.slotY(index) - height / 2
            z: isSelected || isHovered ? 1 : 0
            width: root.cardWidth
            height: root.cardHeight

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onEntered: root.hovered = slot.index
                onExited: if (root.hovered === slot.index) root.hovered = -1
                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton) root.picked(slot.modelData.key)
                    else root.cancelled()
                }
            }

            // The card that moves
            Item {
                id: card
                width: parent.width
                height: parent.height
                x: slot.slide * Math.cos(slot.angle)
                y: slot.slide * Math.sin(slot.angle)
                scale: slot.isSelected ? root.selectScale : slot.isHovered ? root.hoverScale : 1

                Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutQuart } }
                Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutQuart } }
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuart } }

                CutShape {
                    anchors.fill: parent
                    cutBottomRight: 14
                    inset: 0.5
                    fillColor: slot.isSelected ? CP.yellow
                        : slot.isHovered ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.24)
                        : "#080b14"
                    strokeColor: slot.isSelected ? CP.yellow
                        : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, slot.isHovered ? 1 : 0.35)

                    Behavior on fillColor { ColorAnimation { duration: 100 } }
                }

                Rectangle {
                    width: 5
                    height: parent.height
                    color: slot.isSelected ? "#00060e" : root.accent
                    opacity: slot.isHovered || slot.isSelected ? 1 : 0.7
                }

                Text {
                    x: 16
                    width: 34
                    height: parent.height
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: root.keyLabel(slot.modelData.key)
                    font.family: "Oxanium"
                    font.pixelSize: 24
                    font.bold: true
                    color: slot.isSelected ? "#00060e" : CP.yellow
                }

                Text {
                    x: 58
                    width: parent.width - x - 12
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    text: slot.modelData.label.toUpperCase()
                    font.family: "Oxanium"
                    font.pixelSize: 11
                    font.letterSpacing: 1
                    color: slot.isSelected ? "#00060e" : "#d8e6e8"
                }
            }
        }
    }
}
