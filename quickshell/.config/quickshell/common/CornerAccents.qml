// CornerAccents.qml — CP2077-style corner bracket decorations
// Overlay su qualsiasi pannello per aggiungere i caratteristici marcatori angolari.
//
// Usage: CornerAccents { anchors.fill: parent; color: CP.yellow; size: 10 }
// Props: color, size (lunghezza braccio), thickness, opacity
//        showTopLeft/Right/BottomLeft/Right: abilita singoli angoli

import QtQuick

Item {
    id: root

    anchors.fill: parent
    z: 10

    property color accentColor:    "#fcec0c"
    property int   size:           10
    property int   thickness:      1
    property bool  showTopLeft:     true
    property bool  showTopRight:    true
    property bool  showBottomLeft:  true
    property bool  showBottomRight: true

    // ── Top-Left ─────────────────────────────────────────────────────────
    Rectangle {
        visible: root.showTopLeft
        x: 0; y: 0; width: root.thickness; height: root.size
        color: root.accentColor
    }
    Rectangle {
        visible: root.showTopLeft
        x: 0; y: 0; width: root.size; height: root.thickness
        color: root.accentColor
    }

    // ── Top-Right ────────────────────────────────────────────────────────
    Rectangle {
        visible: root.showTopRight
        x: parent.width - root.thickness; y: 0
        width: root.thickness; height: root.size
        color: root.accentColor
    }
    Rectangle {
        visible: root.showTopRight
        x: parent.width - root.size; y: 0
        width: root.size; height: root.thickness
        color: root.accentColor
    }

    // ── Bottom-Left ──────────────────────────────────────────────────────
    Rectangle {
        visible: root.showBottomLeft
        x: 0; y: parent.height - root.size
        width: root.thickness; height: root.size
        color: root.accentColor
    }
    Rectangle {
        visible: root.showBottomLeft
        x: 0; y: parent.height - root.thickness
        width: root.size; height: root.thickness
        color: root.accentColor
    }

    // ── Bottom-Right ─────────────────────────────────────────────────────
    Rectangle {
        visible: root.showBottomRight
        x: parent.width - root.thickness; y: parent.height - root.size
        width: root.thickness; height: root.size
        color: root.accentColor
    }
    Rectangle {
        visible: root.showBottomRight
        x: parent.width - root.size; y: parent.height - root.thickness
        width: root.size; height: root.thickness
        color: root.accentColor
    }
}
