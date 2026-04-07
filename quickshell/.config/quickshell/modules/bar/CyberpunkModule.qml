// CyberpunkModule.qml — base component for right-side modules
// Enhancements: CutShape background (diagonal cuts), chromatic aberration on hover,
// beefed-up shadow glow.

import QtQuick
import QtQuick.Effects
import "../../common/Colors.js" as CP
import "../../common"

Item {
    id: root

    property color  accent:       CP.cyan
    property string text:         ""
    property bool   hovered:      hoverHandler.hovered
    property bool showBackground: true

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
        fillColor: CP.moduleBg
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
            color: Qt.rgba(Qt.color(root.accent).r, Qt.color(root.accent).g, Qt.color(root.accent).b, 0.55)
        }
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            width: parent.width; height: 1
            color: Qt.rgba(Qt.color(root.accent).r, Qt.color(root.accent).g, Qt.color(root.accent).b, 0.22)
        }
    }

    // ── Chromatic aberration: red channel (+2px) ──────────────────────────
    Text {
        id: abeRed
        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 14 }
        text:  root.text
        font:  moduleLabel.font
        color: CP.red
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
        color: CP.cyan
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
        color: Qt.rgba(Qt.color(root.accent).r, Qt.color(root.accent).g, Qt.color(root.accent).b, 0.20)
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
        color: Qt.rgba(Qt.color(root.accent).r, Qt.color(root.accent).g, Qt.color(root.accent).b, 0.42)
        z: 0
    }

    // ── Main text ─────────────────────────────────────────────────────────
    Text {
        id: moduleLabel
        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 12 }
        text:               root.text
        font.family:        "Oxanium"
        font.pixelSize:     12
        font.letterSpacing: 0
        color:              root.accent
        z: 1
        transform: Translate { id: moduleLabelShift; x: 0 }
    }

    // ── Adaptive glitch colors ────────────────────────────────────────────
    property color _c1: CP.magenta
    property color _c2: CP.yellow

    onAccentChanged: {
        if (Qt.colorEqual(accent, CP.yellow))       { _c1 = CP.magenta; _c2 = CP.cyan   }
        else if (Qt.colorEqual(accent, CP.magenta)) { _c1 = CP.cyan;    _c2 = CP.yellow }
        else if (Qt.colorEqual(accent, CP.red))     { _c1 = CP.magenta; _c2 = CP.yellow }
        else                                         { _c1 = CP.magenta; _c2 = CP.yellow }
    }

    // ── Glitch stepped hover ──────────────────────────────────────────────
    SequentialAnimation {
        id: glitchAnim
        running: false; loops: 1

        // Aberration ON at first visible step
        PropertyAction  { target: root;             property: "_glitching";  value: false }
        PropertyAction  { target: moduleLabel;      property: "color";       value: root.accent }
        PropertyAction  { target: moduleLabelShift; property: "x";           value: 0 }
        PauseAnimation  { duration: 30 }

        PropertyAction  { target: root;             property: "_glitching";  value: true }
        PropertyAction  { target: moduleLabel;      property: "color";       value: root._c1 }
        PropertyAction  { target: moduleLabelShift; property: "x";           value: 4 }
        PauseAnimation  { duration: 42 }

        PropertyAction  { target: moduleLabel;      property: "color";       value: root._c2 }
        PropertyAction  { target: moduleLabelShift; property: "x";           value: -4 }
        PauseAnimation  { duration: 42 }

        PropertyAction  { target: moduleLabel;      property: "color";       value: root.accent }
        PropertyAction  { target: moduleLabelShift; property: "x";           value: 3 }
        PauseAnimation  { duration: 42 }

        PropertyAction  { target: root;             property: "_glitching";  value: false }
        PropertyAction  { target: moduleLabel;      property: "color";       value: root._c1 }
        PropertyAction  { target: moduleLabelShift; property: "x";           value: -2 }
        PauseAnimation  { duration: 42 }

        PropertyAction  { target: root;             property: "_glitching";  value: true }
        PropertyAction  { target: moduleLabel;      property: "color";       value: root.accent }
        PropertyAction  { target: moduleLabelShift; property: "x";           value: 2 }
        PauseAnimation  { duration: 42 }

        // Aberration OFF — back to stable
        PropertyAction  { target: root;             property: "_glitching";  value: false }
        PropertyAction  { target: moduleLabel;      property: "color";       value: root.accent }
        PropertyAction  { target: moduleLabelShift; property: "x";           value: 0 }
        PauseAnimation  { duration: 42 }

        PropertyAction  { target: moduleLabel;      property: "color";       value: root.accent }
        PropertyAction  { target: moduleLabelShift; property: "x";           value: 0 }
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
