// ScanlineOverlay.qml — Overlay scanlines CRT
// Uso:
//   ScanlineOverlay { opacity: 0.08; spacing: 2 }

import QtQuick

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real lineSpacing: 2
    property color lineColor: "#000000"

    Repeater {
        model: root.height > 0 ? Math.ceil(root.height / root.lineSpacing) + 1 : 0
        delegate: Rectangle {
            required property int index
            y: index * root.lineSpacing
            width: root.width
            height: 1
            color: root.lineColor
        }
    }
}
