// Clock.qml — cyberpunk center clock
// Enhancements: real chromatic aberration (R/C split) activated during glitch bursts

import Quickshell
import QtQuick
import "../../common/Colors.js" as CP

Item {
    id: root
    implicitHeight: 24
    implicitWidth:  label.implicitWidth + 24

    // Aberration state (active during glitch bursts)
    property bool _aberrating: false

    // ── SystemClock ────────────────────────────────────────────────────────
    SystemClock {
        id: clk
        precision: SystemClock.Seconds
    }

    property string timeStr: {
        var hh  = String(clk.hours).padStart(2, "0")
        var mm  = String(clk.minutes).padStart(2, "0")
        var now = new Date()
        var dd  = String(now.getDate()).padStart(2, "0")
        var mo  = String(now.getMonth() + 1).padStart(2, "0")
        return hh + ":" + mm + " " + dd + "/" + mo
    }

    // ── Red channel (+3px right) ───────────────────────────────────────────
    Text {
        id: abeRed
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: 3
        text:  root.timeStr
        font:  label.font
        color: CP.aberrationRed(0.65)
        opacity: root._aberrating ? 1.0 : 0.0
        z: 0
        Behavior on opacity { NumberAnimation { duration: 25 } }
    }

    // ── Cyan channel (−3px left) ───────────────────────────────────────────
    Text {
        id: abeCyan
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -3
        text:  root.timeStr
        font:  label.font
        color: CP.aberrationCyan(0.65)
        opacity: root._aberrating ? 1.0 : 0.0
        z: 0
        Behavior on opacity { NumberAnimation { duration: 25 } }
    }

    // ── Glow shadow layer 2 (far) ──────────────────────────────────────────
    Text {
        id: shadowLabel2
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: 2
        anchors.verticalCenterOffset:   2
        text:  root.timeStr
        font:  label.font
        color: CP.aberrationCyan(0.35)
        z: 0
    }
    // ── Glow shadow layer 1 (close) ────────────────────────────────────────
    Text {
        id: shadowLabel1
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: 1
        anchors.verticalCenterOffset:   1
        text:  root.timeStr
        font:  label.font
        color: CP.aberrationCyan(0.65)
        z: 1
    }

    // ── Main clock text ────────────────────────────────────────────────────
    Text {
        id: label
        anchors.centerIn: parent
        text:               root.timeStr
        font.family:        "Cyberpunk"
        font.pixelSize:     14
        font.bold:          true
        font.letterSpacing: 3
        color:              CP.yellow
        z: 2
        transform: Translate { id: labelShift; x: 0 }
    }

    // ── Continuous stepped glitch ──────────────────────────────────────────
    SequentialAnimation {
        running: true; loops: Animation.Infinite

        PropertyAction  { target: root;       property: "_aberrating"; value: false }
        PropertyAction  { target: label;      property: "color";       value: CP.yellow }
        PropertyAction  { target: labelShift; property: "x";           value: 0 }
        PauseAnimation  { duration: 1400 }

        // Burst 1: aberration ON + magenta color
        PropertyAction  { target: root;       property: "_aberrating"; value: true }
        PropertyAction  { target: label;      property: "color";       value: CP.magenta }
        PropertyAction  { target: labelShift; property: "x";           value: 3 }
        PauseAnimation  { duration: 55 }

        PropertyAction  { target: label;      property: "color";       value: CP.yellow }
        PropertyAction  { target: labelShift; property: "x";           value: -3 }
        PauseAnimation  { duration: 55 }

        PropertyAction  { target: label;      property: "color";       value: CP.cyan }
        PropertyAction  { target: labelShift; property: "x";           value: 2 }
        PauseAnimation  { duration: 55 }

        // Burst 1 end — aberration OFF
        PropertyAction  { target: root;       property: "_aberrating"; value: false }
        PropertyAction  { target: label;      property: "color";       value: CP.yellow }
        PropertyAction  { target: labelShift; property: "x";           value: 0 }
        PauseAnimation  { duration: 120 }

        // Burst 2: quick micro glitch
        PropertyAction  { target: root;       property: "_aberrating"; value: true }
        PropertyAction  { target: label;      property: "color";       value: CP.magenta }
        PropertyAction  { target: labelShift; property: "x";           value: -1 }
        PauseAnimation  { duration: 40 }

        PropertyAction  { target: root;       property: "_aberrating"; value: false }
        PropertyAction  { target: label;      property: "color";       value: CP.yellow }
        PropertyAction  { target: labelShift; property: "x";           value: 0 }
        PauseAnimation  { duration: 230 }
    }

    // ── Opacity flicker (breathing) ────────────────────────────────────────
    SequentialAnimation {
        running: true; loops: Animation.Infinite
        PropertyAction  { target: root; property: "opacity"; value: 1.0 }
        PauseAnimation  { duration: 2400 }
        PropertyAction  { target: root; property: "opacity"; value: 0.85 }
        PauseAnimation  { duration: 50 }
        PropertyAction  { target: root; property: "opacity"; value: 1.0 }
        PauseAnimation  { duration: 50 }
        PropertyAction  { target: root; property: "opacity"; value: 0.92 }
        PauseAnimation  { duration: 50 }
        PropertyAction  { target: root; property: "opacity"; value: 1.0 }
        PauseAnimation  { duration: 500 }
    }
}
