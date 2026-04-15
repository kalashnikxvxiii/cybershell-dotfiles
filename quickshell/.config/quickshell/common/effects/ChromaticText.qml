// ChromaticText.qml — Chromatic aberration (3 layers: red, cyan, main)
// Usage:
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
    property real restOpacity:       0.0

    // ── Font (delegated to children) ──
    property alias font: _main.font

    implicitWidth: _main.implicitWidth + offsetX * 2
    implicitHeight: _main.implicitHeight

    // Red layer
    Text {
        anchors.centerIn: parent
        x: root.glitching ? -root.offsetX : 0
        text: root.text
        font: _main.font
        color: Colours.aberrationRed(root.glitching ? root.aberrationOpacity : root.restOpacity)
    }

    // Cyan layer
    Text {
        anchors.centerIn: parent
        x: root.glitching ? root.offsetX : 0
        text: root.text
        font: _main.font
        color: Colours.aberrationCyan(root.glitching ? root.aberrationOpacity : root.restOpacity)
    }

    // Main text
    Text {
        id: _main
        anchors.centerIn: parent
        text: root.text
        color: root.color
    }
}
