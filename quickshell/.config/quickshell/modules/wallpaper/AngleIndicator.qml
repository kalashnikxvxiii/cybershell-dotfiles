import "../../common/Colors.js" as CP
import QtQuick

Item {
    id: root
    property real angle: 0

    implicitWidth: 40
    implicitHeight: 40

    onAngleChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var cx = width / 2
            var cy = height / 2
            var r = Math.min(width, height) / 2 - 4

            ctx.strokeStyle = "rgba(252, 236, 12, 0.45)"
            ctx.lineWidth = 1
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, 2 * Math.PI)
            ctx.stroke()

            ctx.fillStyle = "rgba(252, 236, 12, 0.30)"
            ctx.fillRect(cx - 1, cy - r - 1, 2, 2)
            ctx.fillRect(cx - 1, cy + r - 1, 2, 2)
            ctx.fillRect(cx - r - 1, cy - 1, 2, 2)
            ctx.fillRect(cx + r - 1, cy - 1, 2, 2)

            var rad = root.angle * Math.PI / 180
            var dx = -Math.cos(rad)
            var dy =  Math.sin(rad)
            var x2 = cx + dx * (r - 2)
            var y2 = cy + dy * (r - 2)

            ctx.strokeStyle = "rgba(0, 255, 210, 0.95)"
            ctx.lineWidth = 1.6
            ctx.beginPath()
            ctx.moveTo(cx, cy)
            ctx.lineTo(x2, y2)
            ctx.stroke()

            var ah = 5.5
            var perpX = -dy
            var perpY =  dx
            ctx.fillStyle = "rgba(0, 255, 210, 0.98)"
            ctx.beginPath()
            ctx.moveTo(x2, y2)
            ctx.lineTo(x2 - dx*ah + perpX*ah*0.5,
                       y2 - dy*ah + perpY*ah*0.5)
            ctx.lineTo(x2 - dx*ah - perpX*ah*0.5,
                       y2 - dy*ah - perpY*ah*0.5)
            ctx.closePath()
            ctx.fill()

            ctx.fillStyle = "rgba(252, 236, 12, 1.0)"
            ctx.fillRect(cx - 1.5, cy - 1.5, 3, 3)
        }
    }
}
