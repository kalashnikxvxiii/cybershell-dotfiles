// ChromaticText.qml — Aberrazione cromatica (3 layer: rosso, cyan, principale)
// Uso:
//   ChromaticText {
//       text: "CPU 42%"; font.family: "Oxanium"; font.pixelSize: 38
//       color: Colours.accentSecondary
//       glitching: root._glitching
//   }

import QtQuick
import ".."

Item {
    id: root

    // ── API ──
    required property string text
    required property color color
    property bool glitching: false
    property real offsetX: 2
    property real aberrationOpacity: 0.55

    // ── Font (delegato ai figli) ──
    property alias font: _main.font

    implicitWidth: _main.implicitWidth + offsetX * 2
    implicitHeight: _main.implicitHeight

    // Layer rosso
    Text {
        anchors.centerIn: parent
        x: root.glitching ? -root.offsetX : 0
        text: root.text
        font: _main.font
        color: Colours.aberrationRed(root.glitching ? root.aberrationOpacity : 0)
    }

    // Layer cyan
    Text {
        anchors.centerIn: parent
        x: root.glitching ? root.offsetX : 0
        text: root.text
        font: _main.font
        color: Colours.aberrationCyan(root.glitching ? root.aberrationOpacity : 0)
    }

    // Testo principale
    Text {
        id: _main
        anchors.centerIn: parent
        text: root.text
        color: root.color
    }
}
