// VolumePopup.qml — popup volume (cyberpunk style)
// Enhancements: CutShape (no border-radius), CornerAccents, glow border

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Effects
import "../../common/Colors.js" as CP
import "../../common"

Item {
    id: root
    width: 200
    height: 92

    signal closeRequested()

    PwObjectTracker {
        objects: [Pipewire.preferredDefaultAudioSink]
    }
    property var  sink:  Pipewire.preferredDefaultAudioSink
    property bool muted: sink && sink.audio ? sink.audio.muted : false
    property int  vol:   sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0

    // ── Enter animation: opacity + slide ──────────────────────────────────
    opacity: 0
    property real slideY: -20
    Component.onCompleted: {
        enterOpacityAnim.start()
        enterSlideAnim.start()
    }
    NumberAnimation {
        id: enterOpacityAnim
        target: root; property: "opacity"
        from: 0; to: 1; duration: 180; easing.type: Easing.OutCubic
    }
    NumberAnimation {
        id: enterSlideAnim
        target: root; property: "slideY"
        from: -20; to: 0; duration: 200; easing.type: Easing.OutCubic
    }

    // ── Card with CutShape (top-right and bottom-left corners cut) ─────────
    Item {
        id: card
        x: 0; y: root.slideY
        width: parent.width; height: parent.height

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor:            CP.cyan
            shadowBlur:             0.7
            shadowOpacity:          0.35
            shadowHorizontalOffset: 0
            shadowVerticalOffset:   0
        }

        CutShape {
            anchors.fill: parent
            fillColor:   CP.moduleBg
            strokeColor: Qt.rgba(0, 1, 0.824, 0.45)
            strokeWidth: 1
            inset: 0.5
            cutTopRight:    10
            cutBottomLeft:  10
        }

        // Left accent border
        Rectangle {
            width: 3; height: parent.height
            color: root.muted ? Qt.rgba(0.5, 0.5, 0.5, 1) : CP.cyan
        }
        // Bottom glow line
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width; height: 1
            color: Qt.rgba(0, 1, 0.824, 0.40)
        }
    }

    // ── CornerAccents (brackets on the 2 non-cut corners) ─────────────────
    CornerAccents {
        x: 0; y: root.slideY
        width: parent.width; height: parent.height
        accentColor:    CP.cyan
        size:           7
        showTopLeft:    true
        showTopRight:   false
        showBottomLeft: false
        showBottomRight: true
        opacity: 0.7
    }

    // ── Volume label ──────────────────────────────────────────────────────
    Text {
        id: volLabel
        anchors { left: parent.left; leftMargin: 14; top: parent.top; topMargin: 10 }
        y: root.slideY + 10
        text: muted ? "MUTE" : (vol + "%")
        font.family: "Oxanium"
        font.pixelSize: 13
        color: muted ? Qt.rgba(0.5, 0.5, 0.5, 1) : CP.yellow
    }

    // ── Volume bar track ──────────────────────────────────────────────────
    Item {
        id: trackArea
        anchors { left: parent.left; leftMargin: 14; right: parent.right; rightMargin: 14 }
        y: root.slideY + volLabel.implicitHeight + 18
        height: 8

        Rectangle {
            id: track
            anchors.fill: parent
            color: Qt.rgba(0.1, 0.1, 0.15, 1)
            // No border-radius — cyberpunk means sharp corners, always
            // Thin accent border
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(0, 1, 0.824, 0.22)
            }
            Rectangle {
                width: parent.width * (root.vol / 100)
                height: parent.height
                color: root.muted ? Qt.rgba(0.4, 0.4, 0.4, 1) : CP.cyan
            }
        }

        // Slider mouse area
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => {
                if (root.sink && root.sink.audio) {
                    var pct = Math.max(0, Math.min(1, mouse.x / track.width))
                    root.sink.audio.volume = pct
                    root.sink.audio.muted = false
                }
            }
            onPositionChanged: mouse => {
                if (pressed && root.sink && root.sink.audio) {
                    var pct = Math.max(0, Math.min(1, mouse.x / track.width))
                    root.sink.audio.volume = pct
                }
            }
        }
    }

    // ── Mute toggle ───────────────────────────────────────────────────────
    Text {
        id: muteBtn
        anchors { right: closeBtn.left; rightMargin: 10; top: parent.top; topMargin: 10 }
        y: root.slideY
        text: root.muted ? "UNMUTE" : "MUTE"
        font.family: "Oxanium"
        font.pixelSize: 11
        color: CP.magenta
        HoverHandler { id: muteHover }
        opacity: muteHover.hovered ? 1 : 0.85
        MouseArea {
            cursorShape: Qt.PointingHandCursor
            anchors.fill: parent
            anchors.margins: -4
            onClicked: {
                if (root.sink && root.sink.audio)
                    root.sink.audio.muted = !root.sink.audio.muted
            }
        }
    }

    // ── Close button ──────────────────────────────────────────────────────
    Text {
        id: closeBtn
        anchors { right: parent.right; rightMargin: 12; top: parent.top; topMargin: 10 }
        y: root.slideY
        text: "✕"
        font.pixelSize: 14
        color: CP.red
        HoverHandler { id: closeHover }
        opacity: closeHover.hovered ? 1 : 0.8
        MouseArea {
            cursorShape: Qt.PointingHandCursor
            anchors.fill: parent
            anchors.margins: -4
            onClicked: root.closeRequested()
        }
    }
}
