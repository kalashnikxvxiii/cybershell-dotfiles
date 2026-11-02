// CyberpunkModule.qml — base component for right-side modules
// Enhancements: CutShape background (diagonal cuts), chromatic aberration on hover,
// beefed-up shadow glow.

import QtQuick
import QtQuick.Effects
import "../../common/Colors.js" as CP
import "../../common"

Item {
    id: root

    property color  accent:       Theme.cyan
    property string text:         ""
    property bool   hovered:      hoverHandler.hovered
    property bool showBackground: true
    property int  pixelSize:      12

    property var onLeftClick:   function() {}
    property var onRightClick:  function() {}
    property var onMiddleClick: function() {}
    property var onScroll:      function(delta) {}

    // Internal chromatic aberration state
    property bool _glitching: false

    implicitHeight: 24
    implicitWidth:  moduleLabel.implicitWidth + 26

    // ── Background with diagonal cut (no border-radius) ───────────────────
    CutShape {
        id: moduleBg
        visible: root.showBackground
        anchors.fill: parent
        fillColor: Theme.moduleBg
        strokeColor: "transparent"
        cutBottomLeft: 8

        // Left accent border
        Rectangle {
            width: 2; height: parent.height
            color: root.accent
        }

        // Bottom line (double-layer glow)
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width; height: 1
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.55)
        }
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            width: parent.width; height: 1
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)
        }
    }

    // ── Chromatic aberration: red channel (+2px) ──────────────────────────
    Text {
        id: abeRed
        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 14 }
        text:  root.text
        font:  moduleLabel.font
        color: Theme.red
        opacity: root._glitching ? 0.55 : 0.0
        z: 0
        Behavior on opacity { NumberAnimation { duration: 20 } }
    }

    // ── Chromatic aberration: cyan channel (−2px) ─────────────────────────
    Text {
        id: abeCyan
        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 10 }
        text:  root.text
        font:  moduleLabel.font
        color: Theme.cyan
        opacity: root._glitching ? 0.55 : 0.0
        z: 0
        Behavior on opacity { NumberAnimation { duration: 20 } }
    }

    // ── Shadow glow (fakes multi-layer text-shadow) ───────────────────────
    Text {
        id: shadowLabel2
        anchors {
            verticalCenter: parent.verticalCenter
            verticalCenterOffset: 2
            left: parent.left
            leftMargin: 13
        }
        text:  root.text
        font:  moduleLabel.font
        color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.20)
        z: 0
    }
    Text {
        id: shadowLabel
        anchors {
            verticalCenter: parent.verticalCenter
            verticalCenterOffset: 1
            left: parent.left
            leftMargin: 13
        }
        text:  root.text
        font:  moduleLabel.font
        color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.42)
        z: 0
    }

    // ── Main text ─────────────────────────────────────────────────────────
    Text {
        id: moduleLabel
        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 12 }
        text:               root.text
        font.family:        "Oxanium"
        font.pixelSize:     root.pixelSize
        font.letterSpacing: 0
        color:              root.accent
        z: 1
        transform: Translate { id: moduleLabelShift; x: 0 }
    }

    // ── Adaptive glitch colors ────────────────────────────────────────────
    property color _c1: Theme.magenta
    property color _c2: Theme.yellow

    onAccentChanged: {
        if (Qt.colorEqual(accent, Theme.yellow))       { _c1 = Theme.magenta; _c2 = Theme.cyan   }
        else if (Qt.colorEqual(accent, Theme.magenta)) { _c1 = Theme.cyan;    _c2 = Theme.yellow }
        else if (Qt.colorEqual(accent, Theme.red))     { _c1 = Theme.magenta; _c2 = Theme.yellow }
        else                                         { _c1 = Theme.magenta; _c2 = Theme.yellow }
    }

    // ── Glitch stepped hover ──────────────────────────────────────────────
    GlitchAnim {
        id: glitchAnim
        labelTarget: moduleLabel
        shiftTarget: moduleLabelShift
        baseColor: root.accent
        c1: root._c1
        c3: root.accent
        aberrationTarget: root
    }

    HoverHandler { id: hoverHandler; onHoveredChanged: if (hovered) glitchAnim.restart() }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)        root.onLeftClick()
            else if (mouse.button === Qt.RightButton)  root.onRightClick()
            else if (mouse.button === Qt.MiddleButton) root.onMiddleClick()
        }
        onWheel: wheel => root.onScroll(wheel.angleDelta.y)
    }
}
