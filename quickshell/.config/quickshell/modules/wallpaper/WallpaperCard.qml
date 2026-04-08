import "../../common/Colors.js" as CP
import "../../common"
import QtQuick.Effects
import QtQuick
import QtMultimedia
import Quickshell.Io

Item {
    id: root

    required property string    videoFile
    required property string    source
    required property string    thumb
    required property string    title
    required property string    color
    required property string    path
    required property string    type
    required property int       index

    property string searchPreviewThumb: ""
    property string searchPreviewUrl:   ""
    property string resolution:         ""
    property color  _borderColor:       CP.cyan
    property bool   videoPlaying:       false
    property bool   animEnabled:        false
    property bool   _glitching:         false
    property bool   isCurrent:          false
    property bool   isVisible:          true
    property real   videoVolume:        0.5
    property int    viewCurrentIndex:   0

    Timer {
        id: videoDelayTimer
        interval: 2500
        repeat: false
        onTriggered: root.videoPlaying = true
    }

    Timer {
        id: volumeFixTimer
        interval: 500
        repeat: false
        onTriggered: {
            volumeFixProc.command = ["bash", "-c",
                "wpctl status 2>/dev/null | awk 'quickshell/{id=$1; sub(/\\.$/,\"\",id)} END{if(id) system(\"wpctl set-volume \" id \" " + root.videoVolume.toFixed(2) + "\")}'"
            ]
            volumeFixProc.running = true
        }
    }

    Process {
        id: volumeFixProc
        command: ["true"]
        running: false
    }

    property int distFromCurrent: 0

    // ── Dimensions set imperatively by carousel ─────────────────
    property real cardWidth:  0
    property real cardHeight: 0

    Behavior on x          { enabled: root.animEnabled; NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
    Behavior on cardWidth  { enabled: root.animEnabled; NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
    Behavior on cardHeight { enabled: root.animEnabled; NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

    opacity: isVisible ? 1.0 : 0
    Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }

    z: isCurrent ? 100 : (50 - distFromCurrent)
    clip: false
    visible: isVisible && cardWidth > 0 && distFromCurrent <= Math.floor(viewTotalVisible / 2) + 1
    property int viewTotalVisible: 0

    width: cardWidth
    height: 460

    // ── Start/Stop video/gif preview ────────────────────────────────
    onIsCurrentChanged: {
        if (isCurrent && videoFile !== "") {
            videoDelayTimer.restart()
        } else {
            videoDelayTimer.stop()
            videoPlaying = false
        }
    }

    onVideoVolumeChanged: {
        if (videoPlaying && type === "video") {
            volumeFixTimer.restart()
        }
    }

    // ── Reveal glitch animation ────────────────────────────────────
    function reveal() {
        if (isCurrent) return       // current card is already visible
        revealAnim.start()
    }

    SequentialAnimation {
        id: revealAnim

        // Stagger start based on distance
        PropertyAction { target: root; property: "opacity"; value: 0 }
        PropertyAction { target: root; property: "_glitching"; value: false }
        PropertyAction { target: glitchShader; property: "iTime"; value: 0 }
        PauseAnimation { duration: 80 + root.distFromCurrent * 60 }

        // Burst 1: magenta flash
        PropertyAction { target: root; property: "_glitching"; value: true }
        PropertyAction { target: root; property: "_borderColor"; value: CP.magenta }
        PropertyAction { target: root; property: "opacity"; value: 0.6 }
        PropertyAction { target: revealShift; property: "x"; value: 4 }

        // Shader distortion ramp up
        ParallelAnimation {
            NumberAnimation {
                target: glitchShader; property: "iTime"
                from: 0; to: 8; duration: 200
                easing.type: Easing.InCubic
            }
            SequentialAnimation {
                PropertyAction { target: root; property: "_borderColor"; value: CP.yellow }
                PropertyAction { target: revealShift; property: "x"; value: -4 }
                PauseAnimation { duration: 55 }
                PropertyAction { target: root; property: "opacity"; value: 0 }
                PropertyAction { target: root; property: "_borderColor"; value: CP.cyan }
                PropertyAction { target: revealShift; property: "x"; value: 3 }
                PauseAnimation { duration: 55 }
                PropertyAction { target: root; property: "opacity"; value: 0.8 }
                PropertyAction { target: revealShift; property: "x"; value: -2 }
                PauseAnimation { duration: 55 }
                PropertyAction { target: root; property: "opacity"; value: 0.5 }
            }
        }

        // Shader distortion ramp down + settle
        ParallelAnimation {
            NumberAnimation {
                target: glitchShader; property: "iTime"
                from: 8; to: 0; duration: 200
                easing.type: Easing.OutCubic
            }
            SequentialAnimation {
                PropertyAction { target: root; property: "_borderColor"; value: CP.magenta }
                PropertyAction { target: root; property: "opacity"; value: 0.9 }
                PropertyAction { target: revealShift; property: "x"; value: 1 }
                PauseAnimation { duration: 55 }
                PropertyAction { target: root; property: "opacity"; value: 1.0 }
                PropertyAction { target: revealShift; property: "x"; value: 0 }
                PauseAnimation { duration: 100 }
            }
        }

        // Glitch OFF
        PropertyAction { target: root; property: "_glitching"; value: false }
        PropertyAction { target: root; property: "_borderColor"; value: CP.cyan }
        PropertyAction { target: glitchShader; property: "iTime"; value: 0 }
    }

    // ── Skew transform ──────────────────────────────────────────
    readonly property real skewAngle: -10
    readonly property real skewFactor: Math.tan(skewAngle * Math.PI / 180)

    transform: Matrix4x4 {
        matrix: Qt.matrix4x4(
            1, root.skewFactor, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1
        )
    }

    // ── Centered wrapper ────────────────────────────────────────
    Item {
        id: cardWrapper
        width: root.cardWidth
        height: root.cardHeight
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        transform: Translate { id: revealShift }

        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: cardMask
            maskThresholdMin: 0.5
        }

        // ── Content + shader, all clipped by cardWrapper mask ────
        Item {
            id: content
            anchors.fill: parent

            layer.enabled: root.isCurrent && !root._glitching
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: CP.cyan
                shadowBlur: 0.6
                shadowOpacity: 0.45
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }

            Rectangle {
                anchors.fill: parent
                color: "#0a060e"
            }

            Image {
                anchors.fill: parent
                source: root.searchPreviewThumb
                        ? "file://" + root.searchPreviewThumb
                        : (root.thumb ? "file://" + root.thumb : "")
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: root.videoPlaying ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }
            }

            AnimatedImage {
                anchors.fill: parent
                source: root.videoPlaying && root.type === "gif"
                        ? "file://" + root.videoFile : ""
                fillMode: Image.PreserveAspectCrop
                playing: root.videoPlaying
                visible: root.type === "gif"
                opacity: root.videoPlaying ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }
            }

            Item {
                anchors.fill: parent
                visible: root.type === "video"
                opacity: root.videoPlaying ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }

                MediaPlayer {
                    id: videoPlayer
                    source: root.videoPlaying && root.type === "video" && root.videoFile !== ""
                            ? "file://" + root.videoFile : ""
                    videoOutput: videoOutput
                    audioOutput: AudioOutput {
                        volume: root.videoVolume
                    }
                    loops: MediaPlayer.Infinite
                    onSourceChanged: {
                        if (source !== "") {
                            play()
                            volumeFixTimer.restart()
                        }
                    }
                }

                VideoOutput {
                    id: videoOutput
                    anchors.fill: parent
                    fillMode: VideoOutput.PreserveAspectCrop
                }
            }

            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: root.isCurrent ? 0 : 0.5
                Behavior on opacity { NumberAnimation { duration: 400 } }
            }

            Item {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 48
                visible: root.isCurrent

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.4; color: Qt.rgba(0, 0, 0, 0.7) }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.85) }
                    }
                }

                Text {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    text: root.resolution !== ""
                        ? root.resolution.replace("x", "\u00d7")
                        : root.title.toUpperCase()
                    font.family: "Oxanium"
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    color: Colours.textPrimary
                    elide: Text.ElideRight

                    transform: Matrix4x4 {
                        matrix: Qt.matrix4x4(
                            1, -root.skewFactor, 0, 0,
                            0, 1, 0, 0,
                            0, 0, 1, 0,
                            0, 0, 0, 1
                        )
                    }
                }
            }

            CutShape {
                anchors.fill: parent
                fillColor: "transparent"
                strokeColor: root._glitching
                            ? root._borderColor
                            : (root.isCurrent
                                ? Colours.neonBorder(0.8)
                                : CP.alpha(CP.cyan, 0.25))
                strokeWidth: root.isCurrent ? 2 : 1
                inset: root.isCurrent ? 1 : 0.5
                cutTopLeft: 32
                cutBottomRight: 32
            }
        }

        CutShape {
            id: cardMask
            anchors.fill: parent
            layer.enabled: true
            visible: false
            fillColor: "white"
            cutTopLeft: 32
            cutBottomRight: 32
        }

        // ── Shader system (sibling to content) ──────────────────
        ShaderEffectSource {
            id: cardShaderSource
            sourceItem: content
            live: root._glitching
            hideSource: root._glitching
        }

        ShaderEffect {
            id: glitchShader
            anchors.fill: parent
            visible: root._glitching
            z: 10
            property var source: cardShaderSource
            property real iTime: 0
            fragmentShader: "../../shaders/glitch.frag.qsb"
        }
    }
}
