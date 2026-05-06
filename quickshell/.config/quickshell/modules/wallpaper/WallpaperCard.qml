import "../../common/Colors.js" as CP
import "../../common"
import QtQuick.Effects
import QtQuick
import QtMultimedia
import Quickshell.Io
import WpePreview 1.0

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
    property bool   isFavorite:         false
    property bool   isCurrent:          false
    property bool   isVisible:          true
    property real   videoVolume:        0.5
    property int    viewCurrentIndex:   0

    function startVideo() {
        videoPlaying = true
    }

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
    property real cardWidth:        0
    property real cardHeight:       0
    property bool carouselFastMode: false
    property bool anmimEnabled:     false
    property bool isPreload:        false

    Behavior on x          { enabled: root.animEnabled && !root.carouselFastMode; NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
    Behavior on cardWidth  { enabled: root.animEnabled && !root.carouselFastMode; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on cardHeight { enabled: root.animEnabled && !root.carouselFastMode; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    opacity: isVisible ? 1.0 : 0
    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }

    z: isCurrent ? 100 : (50 - distFromCurrent)
    clip: false
    visible: isVisible && cardWidth > 0 && distFromCurrent <= Math.floor(viewTotalVisible / 2) + 1
    property int viewTotalVisible: 0

    width: cardWidth
    height: 460

    // ── Start/Stop video/gif preview ────────────────────────────────
    onIsCurrentChanged: {
        if (isCurrent && opacity < 0.5) opacity = 1
        if (isCurrent && (videoFile !== "" || type === "scene")) {
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
            maskThresholdMin: 0.3
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
                    source: root.videoPlaying && root.videoFile !== ""
                            && root.type === "video"
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

            WpePreviewItem {
                anchors.fill: parent
                visible: root.isCurrent && root.type === "scene"
                scenePath: root.isCurrent && root.type === "scene" && root.videoPlaying
                        ? root.path : ""
                fps: 15
                opacity: ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }
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
                        GradientStop { position: 0.7; color: Qt.rgba(0, 0, 0, 0.7) }
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

    // Favorite badge
    Item {
        id: favBadge
        anchors.top: cardWrapper.top
        anchors.right: cardWrapper.right
        anchors.topMargin: 1
        anchors.rightMargin: 1
        width: 24 * _scale
        height: 24 *_scale
        visible: _favVisible
        z: 200

        property real _scale:       cardWrapper.height > 0 ? cardWrapper.height / 450 : 1
        property bool _favVisible:  false

        Component.onCompleted: {
            if (root.isFavorite) {
                _favVisible = true
                opacity = 1
            }
        }

        Connections {
            target: root
            function onIsFavoriteChanged() {
                if (root.isFavorite) {
                    favBadge._favVisible = true
                    favExitAnim.stop()
                    favEntryAnim.restart()
                } else {
                    favEntryAnim.stop()
                    favExitAnim.restart()
                }
            }
        }

        // Background
        CutShape {
            anchors.fill: parent
            fillColor: CP.alpha("#000000", 0.75)
            strokeColor: CP.alpha(CP.red, 0.8)
            strokeWidth: 1
            inset: 0.5
            cutBottomLeft: playlistBadge.visible ? 0 : 8
            showTop: false
            showRight: false
        }

        // Icon with glow
        Text {
            anchors.centerIn: parent
            text: "\uf004"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11 * parent._scale
            color: CP.red

            // Counter-skew to keep icon straight
            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(
                    1, -root.skewFactor, 0, 0,
                    0, 1, 0, 0,
                    0, 0, 1, 0,
                    0, 0, 0, 1
                )
            }

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: CP.red
                shadowBlur: 0.8
                shadowOpacity: 0.6
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }
        }

        // Entry animation
        SequentialAnimation {
            id: favEntryAnim
            NumberAnimation { target: favBadge; property: "opacity"; to: 0;   duration: 0 }
            PauseAnimation  { duration: 100 }
            NumberAnimation { target: favBadge; property: "opacity"; to: 1.2; duration: 80 }
            NumberAnimation { target: favBadge; property: "opacity"; to: 0.6; duration: 60 }
            NumberAnimation { target: favBadge; property: "opacity"; to: 1.0; duration: 100 }
        }

        // Exit animation
        SequentialAnimation {
            id: favExitAnim
            NumberAnimation { target: favBadge; property: "opacity"; to: 0.3; duration: 60 }
            NumberAnimation { target: favBadge; property: "opacity"; to: 1.0; duration: 40 }
            PauseAnimation  { duration: 20 }
            NumberAnimation { target: favBadge; property: "opacity"; to: 0.2; duration: 30 }
            NumberAnimation { target: favBadge; property: "opacity"; to: 1.0; duration: 30 }
            NumberAnimation { target: favBadge; property: "opacity"; to: 0;   duration: 80 }
            ScriptAction    { script: favBadge._favVisible = false }
        }
    }

    // Playlist position badge
    Item {
        id: playlistBadge
        anchors.top: cardWrapper.top
        anchors.topMargin: 1
        x: favBadge.x - _offset
        width: Math.max(24 * _plScale, _plTxt.implicitWidth + 10)
        height: 24 * _plScale
        visible: root.path !== "" && root.searchPreviewThumb === "" && _plPos > 0
        opacity: _hovered ? 1.0 : 0.45
        z: 200

        property real _plScale: cardWrapper.height > 0 ? cardWrapper.height / 450 : 1
        property real _offset:  favBadge._favVisible ? width : (width - favBadge.width)
        property bool _hovered: false
        property int  _plPos:   {
            if (PlaylistState.activeName === "") {
                return PlaylistState.countInAll(root.path)
            } else {
                var arr = PlaylistState.entries
                for (var i = 0; i < arr.length; i++)
                    if (arr[i].path === root.path) return i + 1
                return 0
            }
        }

        Behavior on _offset { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 120 } }

        CutShape {
            anchors.fill: parent
            fillColor: CP.alpha(CP.cyan, 0.6)
            strokeColor: parent._hovered
                        ? CP.alpha(CP.yellow, 0.9)
                        : CP.alpha(CP.yellow, 0.6)
            strokeWidth: 1; inset: 0.5
            cutBottomLeft: 8
            showTop: false
            showRight: false
        }

        Text {
            id: _plTxt
            anchors.centerIn: parent
            text: parent._plPos.toString()
            font.family: "Oxanium"
            font.pixelSize: 16 * parent._plScale
            color: CP.yellow

            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(
                    1, -root.skewFactor, 0, 0,
                    0, 1, 0, 0,
                    0, 0, 1, 0,
                    0, 0, 0, 1
                )
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: playlistBadge._hovered = true
            onExited:  playlistBadge._hovered = false
            onClicked: {
                if (PlaylistState.activeName === "")
                    PlaylistState.setHighlightFilter(root.path)
                else if (playlistBadge._plPos > 0)
                    PlaylistState.highlightEntry(root.path)
            }
        }
    }
}
