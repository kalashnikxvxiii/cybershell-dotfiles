// MediaMiniControls.qml — Prev/play/next controls with glow and GlitchAnim
// Extracted from DashMediaMini.qml

import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import "../../common/Colors.js" as CP
import "../../common"

RowLayout {
    id: root

    required property MprisPlayer activePlayer
    required property real buttonSize
    required property real fontSize
    required property bool coverHovered

    spacing: 6
    opacity: root.coverHovered ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 180 } }

    
    // Previous
    Item {
        id: prevBtnMini
        implicitWidth: root.buttonSize; implicitHeight: root.buttonSize
        opacity: root.activePlayer?.canGoPrevious ?? false ? 1 : 0.35

        property real glowOp: 0.0

        SequentialAnimation {
            running: prevArea.containsMouse
            loops: Animation.Infinite
            onStopped: prevBtnMini.glowOp = 0
            NumberAnimation { target: prevBtnMini; property: "glowOp"; to: 1.0; duration: 40 }
            PauseAnimation { duration: 620 }
            NumberAnimation { target: prevBtnMini; property: "glowOp"; to: 0.15; duration: 25 }
            PauseAnimation { duration: 50 }
            NumberAnimation { target: prevBtnMini; property: "glowOp"; to: 1.0; duration: 35 }
            PauseAnimation { duration: 360 }
            NumberAnimation { target: prevBtnMini; property: "glowOp"; to: 0.0; duration: 20 }
            PauseAnimation { duration: 40 }
            NumberAnimation { target: prevBtnMini; property: "glowOp"; to: 0.8; duration: 20 }
            PauseAnimation { duration: 30 }
            NumberAnimation { target: prevBtnMini; property: "glowOp"; to: 0.0; duration: 20 }
            PauseAnimation { duration: 65 }
            NumberAnimation { target: prevBtnMini; property: "glowOp"; to: 1.0; duration: 80; easing.type: Easing.OutQuad }
            PauseAnimation { duration: 510 }
        }

        Text { anchors.centerIn: parent; text: "⏮"; font.family: "JetBrains Mono Nerd Font"; font.pixelSize: root.fontSize * 1.5 + 20; color: Qt.rgba(0.97, 0.94, 0.01, 0.06 * prevBtnMini.glowOp) }
        Text { anchors.centerIn: parent; text: "⏮"; font.family: "JetBrains Mono Nerd Font"; font.pixelSize: root.fontSize * 1.5 + 14; color: Qt.rgba(0.97, 0.94, 0.01, 0.12 * prevBtnMini.glowOp) }
        Text { anchors.centerIn: parent; text: "⏮"; font.family: "JetBrains Mono Nerd Font"; font.pixelSize: root.fontSize * 1.5 + 9; color: Qt.rgba(0.97, 0.94, 0.01, 0.25 * prevBtnMini.glowOp) }
        Text { anchors.centerIn: parent; text: "⏮"; font.family: "JetBrains Mono Nerd Font"; font.pixelSize: root.fontSize * 1.5 + 5; color: Qt.rgba(0.97, 0.94, 0.01, 0.45 * prevBtnMini.glowOp) }
        Text { anchors.centerIn: parent; text: "⏮"; font.family: "JetBrains Mono Nerd Font"; font.pixelSize: root.fontSize * 1.5 + 2; color: Qt.rgba(1, 1, 0.4, 0.70 * prevBtnMini.glowOp) }
        Text {
            id: prevLabel
            anchors.centerIn: parent
            text: "⏮"
            font.pixelSize: root.fontSize * 1.5
            color: Colours.textPrimary
            font.family: "JetBrains Mono Nerd Font"
            transform: Translate { id: labelShift; x: 0 }
        }
        MouseArea {
            id: prevArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activePlayer?.previous()
            onWheel: function(event) { event.accepted = false }
        }
        GlitchAnim {
            id: prevGlitch
            labelTarget: prevLabel
            shiftTarget: labelShift
            baseColor: CP.cyan
            onFinished: if (prevHover.hovered) pausePrevTimer.start()
        }
        Timer {
            id: pausePrevTimer
            interval: 600
            repeat: false
            onTriggered: if (prevHover.hovered) prevGlitch.restart()
        }
        HoverHandler {
            id: prevHover
            onHoveredChanged: {
                if (hovered) prevGlitch.restart()
                else { prevGlitch.reset(); pausePrevTimer.stop() }
            }
        }
    }

    // Play/Pause
    Item {
        id: playBtnMini
        implicitWidth: root.buttonSize * 2; implicitHeight: root.buttonSize * 2
        opacity: root.activePlayer?.canTogglePlaying ?? false ? 1 : 0.35

        property real glowOp: 0.0
        readonly property string icon: (root.activePlayer?.isPlaying ?? false) ? "⏸" : "\udb81\udc0a"

        SequentialAnimation {
            running: playArea.containsMouse
            loops: Animation.Infinite
            onStopped: playBtnMini.glowOp = 0
            NumberAnimation { target: playBtnMini; property: "glowOp"; to: 1.0; duration: 40 }
            PauseAnimation { duration: 500 }
            NumberAnimation { target: playBtnMini; property: "glowOp"; to: 0.0; duration: 18 }
            PauseAnimation { duration: 45 }
            NumberAnimation { target: playBtnMini; property: "glowOp"; to: 1.0; duration: 30 }
            PauseAnimation { duration: 300 }
            NumberAnimation { target: playBtnMini; property: "glowOp"; to: 0.2; duration: 25 }
            PauseAnimation { duration: 35 }
            NumberAnimation { target: playBtnMini; property: "glowOp"; to: 0.9; duration: 20 }
            PauseAnimation { duration: 25 }
            NumberAnimation { target: playBtnMini; property: "glowOp"; to: 0.0; duration: 18 }
            PauseAnimation { duration: 75 }
            NumberAnimation { target: playBtnMini; property: "glowOp"; to: 1.0; duration: 100; easing.type: Easing.OutQuad }
            PauseAnimation { duration: 470 }
        }

        Text { anchors.centerIn: parent; text: playBtnMini.icon; font.family: "JetBrains Mono NF"; font.pixelSize: root.fontSize * 2 + 20; color: Qt.rgba(0.97, 0.94, 0.01, 0.12 * playBtnMini.glowOp) }
        Text { anchors.centerIn: parent; text: playBtnMini.icon; font.family: "JetBrains Mono NF"; font.pixelSize: root.fontSize * 2 + 14; color: Qt.rgba(0.97, 0.94, 0.01, 0.20 * playBtnMini.glowOp) }
        Text { anchors.centerIn: parent; text: playBtnMini.icon; font.family: "JetBrains Mono NF"; font.pixelSize: root.fontSize * 2 + 9; color: Qt.rgba(0.97, 0.94, 0.01, 0.25 * playBtnMini.glowOp) }
        Text { anchors.centerIn: parent; text: playBtnMini.icon; font.family: "JetBrains Mono NF"; font.pixelSize: root.fontSize * 2 + 5; color: Qt.rgba(0.97, 0.94, 0.01, 0.45 * playBtnMini.glowOp) }
        Text { anchors.centerIn: parent; text: playBtnMini.icon; font.family: "JetBrains Mono NF"; font.pixelSize: root.fontSize * 2 + 2; color: Qt.rgba(1, 1, 0.4, 0.70 * playBtnMini.glowOp) }
        Text {
            id: playLabel
            anchors.centerIn: parent
            text: playBtnMini.icon
            font.pixelSize: root.fontSize * 2
            color: CP.cyan
            font.family: "JetBrains Mono NF"
            transform: Translate { id: labelShift2; x: 0 }
        }
        MouseArea {
            id: playArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activePlayer?.togglePlaying()
            onWheel: function(event) { event.accepted = false }
        }
        GlitchAnim {
            id: playGlitch
            labelTarget: playLabel
            shiftTarget: labelShift2
            baseColor: CP.cyan
            onFinished: if (playHover.hovered) pausePlayTimer.start()
        }
        Timer {
            id: pausePlayTimer
            interval: 600
            repeat: false
            onTriggered: if (playHover.hovered) playGlitch.restart()
        }
        HoverHandler {
            id: playHover
            onHoveredChanged: {
                if (hovered) playGlitch.restart()
                else { playGlitch.reset(); pausePlayTimer.stop() }
            }
        }
    }

    // Next
    Item {
        id: nextBtnMini
        implicitWidth: root.buttonSize; implicitHeight: root.buttonSize
        opacity: root.activePlayer?.canGoNext ?? false ? 1 : 0.35

        property real glowOp: 0.0

        SequentialAnimation {
            running: nextArea.containsMouse
            loops: Animation.Infinite
            onStopped: nextBtnMini.glowOp = 0
            NumberAnimation { target: nextBtnMini; property: "glowOp"; to: 1.0; duration: 40 }
            PauseAnimation { duration: 700 }
            NumberAnimation { target: nextBtnMini; property: "glowOp"; to: 0.1; duration: 20 }
            PauseAnimation { duration: 30 }
            NumberAnimation { target: nextBtnMini; property: "glowOp"; to: 1.0; duration: 30 }
            PauseAnimation { duration: 420 }
            NumberAnimation { target: nextBtnMini; property: "glowOp"; to: 0.0; duration: 20 }
            PauseAnimation { duration: 55 }
            NumberAnimation { target: nextBtnMini; property: "glowOp"; to: 0.7; duration: 25 }
            PauseAnimation { duration: 35 }
            NumberAnimation { target: nextBtnMini; property: "glowOp"; to: 0.0; duration: 15 }
            PauseAnimation { duration: 80 }
            NumberAnimation { target: nextBtnMini; property: "glowOp"; to: 1.0; duration: 90; easing.type: Easing.OutQuad }
            PauseAnimation { duration: 540 }
        }

        Text { anchors.centerIn: parent; text: "⏭"; font.family: "JetBrains Mono Nerd Font"; font.pixelSize: root.fontSize * 1.5 + 20; color: Qt.rgba(0.97, 0.94, 0.01, 0.06 * nextBtnMini.glowOp) }
        Text { anchors.centerIn: parent; text: "⏭"; font.family: "JetBrains Mono Nerd Font"; font.pixelSize: root.fontSize * 1.5 + 14; color: Qt.rgba(0.97, 0.94, 0.01, 0.12 * nextBtnMini.glowOp) }
        Text { anchors.centerIn: parent; text: "⏭"; font.family: "JetBrains Mono Nerd Font"; font.pixelSize: root.fontSize * 1.5 + 9; color: Qt.rgba(0.97, 0.94, 0.01, 0.25 * nextBtnMini.glowOp) }
        Text { anchors.centerIn: parent; text: "⏭"; font.family: "JetBrains Mono Nerd Font"; font.pixelSize: root.fontSize * 1.5 + 5; color: Qt.rgba(0.97, 0.94, 0.01, 0.45 * nextBtnMini.glowOp) }
        Text { anchors.centerIn: parent; text: "⏭"; font.family: "JetBrains Mono Nerd Font"; font.pixelSize: root.fontSize * 1.5 + 2; color: Qt.rgba(1, 1, 0.4, 0.70 * nextBtnMini.glowOp) }
        Text {
            id: nextLabel
            anchors.centerIn: parent
            text: "⏭"
            font.pixelSize: root.fontSize * 1.5
            font.family: "JetBrains Mono Nerd Font"
            color: Colours.textPrimary
            transform: Translate { id: labelShift3; x: 0 }
        }
        MouseArea {
            id: nextArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activePlayer?.next()
            onWheel: function(event) { event.accepted = false }
        }
        GlitchAnim {
            id: nextGlitch
            labelTarget: nextLabel
            shiftTarget: labelShift3
            baseColor: CP.cyan
            onFinished: if (nextHover.hovered) pauseNextTimer.start()
        }
        Timer {
            id: pauseNextTimer
            interval: 600
            repeat: false
            onTriggered: if (nextHover.hovered) nextGlitch.restart()
        }
        HoverHandler {
            id: nextHover
            onHoveredChanged: {
                if (hovered) nextGlitch.restart()
                else { nextGlitch.reset(); pauseNextTimer.stop() }
            }
        }
    }
}
