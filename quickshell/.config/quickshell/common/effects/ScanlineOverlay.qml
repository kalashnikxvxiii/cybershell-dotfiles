// ScanlineOverlay.qml — CRT scanline overlay
// Usage:
//   ScanlineOverlay { opacity: 0.08; spacing: 2 }

import QtQuick

Item {
    id: root
    anchors.fill: parent
    clip: true

    property color lineColor: "#000000"
    property real lineSpacing: 2

    Canvas {
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.strokeStyle = root.lineColor
            ctx.lineWidth = 1
            for (var y = 0; y < height; y += root.lineSpacing) {
                ctx.beginPath()
                ctx.moveTo(0, y + 0.5)
                ctx.lineTo(width, y + 0.5)
                ctx.stroke()
            }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()
    }
}
