// ModuleCard.qml — Wrapper DRY per CutShape fill + content + CutShape stroke
// Uso:
//   ModuleCard {
//       cutTopLeft: 24
//       fillColor: Colours.moduleBg
//       DashAppLauncher { anchors.fill: parent }
//   }

import QtQuick
import ".."

Item {
    id: root

    // ── Tagli (passati a entrambi i CutShape) ──
    property real cutTopLeft: 0
    property real cutTopRight: 0
    property real cutBottomLeft: 0
    property real cutBottomRight: 0

    // ── Stile ──
    property color fillColor: Colours.moduleBg
    property color borderColor: Colours.neonBorder(0.3)
    property real borderWidth: 1
    property real borderInset: 0.5

    // ── Contenuto ── figli dichiarati inline vanno qui
    default property alias content: _contentArea.children

    // ── Layer mask (opzionale) ──
    property bool maskEnabled: false

    // Fill
    CutShape {
        anchors.fill: parent
        fillColor: root.fillColor
        cutTopLeft: root.cutTopLeft
        cutTopRight: root.cutTopRight
        cutBottomLeft: root.cutBottomLeft
        cutBottomRight: root.cutBottomRight
    }

    // Contenuto
    Item {
        id: _contentArea
        anchors.fill: parent
    }

    // Mask (per layer.effect, hidden)
    CutShape {
        id: _mask
        anchors.fill: parent
        fillColor: "white"
        visible: false
        layer.enabled: root.maskEnabled
        cutTopLeft: root.cutTopLeft
        cutTopRight: root.cutTopRight
        cutBottomLeft: root.cutBottomLeft
        cutBottomRight: root.cutBottomRight
    }

    // Stroke border
    CutShape {
        anchors.fill: parent
        strokeColor: root.borderColor
        strokeWidth: root.borderWidth
        inset: root.borderInset
        cutTopLeft: root.cutTopLeft
        cutTopRight: root.cutTopRight
        cutBottomLeft: root.cutBottomLeft
        cutBottomRight: root.cutBottomRight
    }
}
