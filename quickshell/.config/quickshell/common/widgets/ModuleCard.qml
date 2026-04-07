// ModuleCard.qml — DRY wrapper for CutShape fill + content + CutShape stroke
// Usage:
//   ModuleCard {
//       cutTopLeft: 24
//       fillColor: Colours.moduleBg
//       DashAppLauncher { anchors.fill: parent }
//   }

import QtQuick
import ".."

Item {
    id: root

    // ── Cuts (passed to both CutShapes) ──
    property real cutTopLeft: 0
    property real cutTopRight: 0
    property real cutBottomLeft: 0
    property real cutBottomRight: 0

    // ── Style ──
    property color fillColor: Colours.moduleBg
    property color borderColor: Colours.neonBorder(0.3)
    property real borderWidth: 1
    property real borderInset: 0.5

    // ── Content ── inline-declared children go here
    default property alias content: _contentArea.children

    // ── Layer mask (optional) ──
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

    // Content
    Item {
        id: _contentArea
        anchors.fill: parent
    }

    // Mask (for layer.effect, hidden)
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
