import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import "../../common/Colors.js" as CP
import "../../common"
import "."

// Media Tab: cover art + track info + MPRIS controls
// Adapted from Caelestia modules/dashboard/Media.qml + dash/Media.qml
// QuickShell Mpris API: Mpris (singleton), Mpris.players.values (list)

Item {
    id: root
    implicitWidth: mediaW
    implicitHeight: 600

    readonly property real          mediaW:             400
    readonly property real          fontSize:           Math.min(mediaW * 0.12, height * 0.12)
    readonly property MprisPlayer   activePlayer:       Players.active
    readonly property real          playerProgress: {
        const p = activePlayer
        return (p && p.length > 0) ? p.position / p.length : 0
    }
    property bool                   _showStaticInfo:    false
    property color                  _borderColor:       CP.cyan
    property bool                   _glitchingInfo:     false
    property real                   _staticInfoOpacity: 0
    // Like State
    property bool                   isLiked:            Players.isLiked
    
    readonly property string        _trackId: {
        const url = String(root.activePlayer?.metadata?.["xesam:url"] ?? "")
        if (url.startsWith("spotify:track:")) return url.split(":")[2]
        const m = url.match(/\/track\/([A-Za-z0-9]+)/)
        return m ? m[1] : ""
    }

    // Update position every 500ms while playing
    Timer {
        running: Players.active?.isPlaying ?? false
        interval: 500
        repeat: true
        triggeredOnStart: true
        onTriggered: Players.active?.positionChanged()
    }

    // Read the like state from the lyrics JSON (updated by the extension)
    Process {
        id: likeProc
        //onExited: console.warn("[LIKE] curl exited, code:", exitCode)
    }

    Process {
        id: focusProc
        command: ["hyprctl", "dispatch", "focuswindow",
                "class:" + (root.activePlayer?.desktopEntry ?? "")]
        running: false
    }

    Item {
        id: mediaWrapper
        x: root.lyricsOpen ? x : 0
        width: root.mediaW
        height: parent.height

        // Layer 1: cover art as full-area background
        Item {
            anchors.fill: parent

            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: shapeMask
            }

            // Background
            CutShape {
                anchors.fill: parent
                fillColor: "transparent"
                cutBottomLeft: 32
            }

            Text {
                anchors.centerIn: parent
                text: "♪"
                font.pixelSize: 60
                color: Colours.textSecondary
                visible: coverImg.status !== Image.Ready
            }

            // Outgoing cover capture
            Image {
                id: coverImgOld
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                visible: false
            }

            Image {
                id: coverImg
                anchors.fill: parent
                source: root.activePlayer?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: function(event) {
                    const player = Players.active
                    if (!player) return
                    player.volume = Math.max(0.0, Math.min(1.0, player.volume + (event.angleDelta.y / 120) * 0.04))
                }
            }

            // Mask (same polygon filled white, invisible)
            CutShape {
                id: shapeMask
                layer.enabled: true
                visible: false
                width: parent.width
                height: parent.height
                fillColor: "white"
                cutBottomLeft: 32
            }

            // Screen Tear Transition
            Item {
                id: tearTransition
                anchors.fill: parent
                visible: false
                z: 5
                clip: true

                readonly property int sliceCount: 14
                property real progress: 0
                property real displacement: 0

                Repeater {
                    model: tearTransition.sliceCount

                    Item {
                        required property int index
                        clip: true
                        width: tearTransition.width
                        height: tearTransition.height / tearTransition.sliceCount
                        y: index * height

                        readonly property bool showNew: {
                            const t = tearTransition.progress
                            const threshold = (Math.sin(index * 4.7 + 0.5) + 1) / 2
                            return t > threshold
                        }

                        readonly property real dx: {
                            const d = tearTransition.displacement
                            return Math.sin(index * 3.1 + d * 0.1) * d
                        }

                        Image {
                            source: parent.showNew ? coverImg.source : coverImgOld.source
                            width: tearTransition.width
                            height: tearTransition.height
                            y: -parent.y
                            z: parent.dx
                            fillMode: Image.PreserveAspectCrop
                        }
                    }
                }
            }
            ShaderEffectSource {
                id: tearSource
                sourceItem: tearTransition
                live: true
                hideSource: true        // hides the raw strips, only visible through the shader
            }

            ShaderEffect {
                id: tearShader
                anchors.fill: parent
                visible: tearTransition.visible
                z: 6
                property var source: tearSource
                property real iTime: 0
                fragmentShader: "../../shaders/glitch.frag.qsb"
            }
        }

        // Layer 2: dark gradient (transparent at top, opaque at bottom)
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.45; color: CP.alpha(CP.black, 0.35) }
                GradientStop { position: 1.0; color: CP.alpha(CP.black, 0.88) }
            }
        }

        Rectangle {
            width: 24
            height: width
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 8
            anchors.rightMargin: 8
            radius: width / 2
            color: CP.alpha(CP.black, 0.23)
            visible: !!Players.active
            z: 10

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: focusProc.running = true
            }

            // Active icon player (top-right)
            Text {
                id: activePlayerIcon
                anchors.centerIn: parent
                text: Players.isSpotifyActive ? "\uf1bc" : "\ueb01"
                font.family: "Oxanium"
                font.pixelSize: 20
                color: CP.neon
                visible: !!Players.active
            }
        }

        Rectangle {
            width: 24
            height: width
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            radius: width / 2
            color: switchHover.hovered ? CP.alpha(CP.black, 0.64) : CP.alpha(CP.black, 0.32)
            opacity: switchHover.hovered ? 1 : 0.8
            visible: Players.canSwitch
            z: 10

            // Switchable icon player (right center) - inactive only
            Text {
                id: switchableIcon
                anchors.centerIn: parent
                z: 10
                text: Players.isSpotifyActive ? "\ueb01" : "\uf1bc"
                font.family: "Oxanium"
                font.pixelSize: 20
                color: switchHover.hovered ? CP.white : CP.alpha(CP.white, 0.5)
                visible: Players.canSwitch
                opacity: switchHover.hovered ? 0.9 : 0.6

                HoverHandler {
                    id: switchHover
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: switchGlitchAnim.restart()
                    
                }
            }
        }

        SequentialAnimation {
            id: switchGlitchAnim

            // Setup: capture old cover, toggle player, show strips
            ScriptAction {
                script: {
                    coverImgOld.source = coverImg.source
                    coverImgOld.visible = true
                    Players.togglePlayer()
                    tearTransition.progress = 0
                    tearTransition.displacement = 0
                    tearTransition.visible = true
                    coverImg.visible = false
                }
            }

            // Animation: strips transition from old to new with displacement
            ParallelAnimation {
                // Progress: strips flip from old to new
                NumberAnimation {
                    target: tearTransition; property: "progress"
                    from: 0; to: 1; duration: 500
                }

                // Displacement: grows then shrinks (peaks at midpoint)
                SequentialAnimation {
                    NumberAnimation {
                        target: tearTransition; property: "displacement"
                        from: 0; to: 40; duration: 250
                        easing.type: Easing.InCubic
                    }
                    NumberAnimation {
                        target: tearTransition; property: "displacement"
                        from: 40; to: 0; duration: 250
                        easing.type: Easing.OutCubic
                    }
                }

                // Shader: distortion ramps up then back down
                SequentialAnimation {
                    NumberAnimation {
                        target: tearShader; property: "iTime"
                        from: 0; to: 8; duration: 250
                        easing.type: Easing.InCubic
                    }
                    NumberAnimation {
                        target: tearShader; property: "iTime"
                        from: 8; to: 0; duration: 250
                        easing.type: Easing.OutCubic
                    }
                }

                // Icon flicker
                SequentialAnimation {
                    PropertyAction { target: activePlayerIcon; property: "opacity"; value: 0.8 }
                    PropertyAction { target: switchableIcon; property: "opacity"; value: 0.6 }
                    PauseAnimation { duration: 60 }
                    PropertyAction { target: activePlayerIcon; property: "opacity"; value: 0 }
                    PropertyAction { target: switchableIcon; property: "opacity"; value: 0 }
                    PauseAnimation { duration: 80 }
                    PropertyAction { target: activePlayerIcon; property: "opacity"; value: 0.5 }
                    PropertyAction { target: switchableIcon; property: "opacity"; value: 0.6 }
                    PauseAnimation { duration: 45 }
                    PropertyAction { target: activePlayerIcon; property: "opacity"; value: 0 }
                    PauseAnimation { duration: 70 }
                    PropertyAction { target: switchableIcon; property: "opacity"; value: 0.6 }
                    PropertyAction { target: switchableIcon; property: "opacity"; value: 0 }
                    PauseAnimation { duration: 60 }
                    PropertyAction { target: switchableIcon; property: "opacity"; value: 0.4 }
                    PauseAnimation { duration: 50 }
                    PropertyAction { target: activePlayerIcon; property: "opacity"; value: 0.3 }
                    PropertyAction { target: switchableIcon; property: "opacity"; value: 0.6 }
                    PauseAnimation { duration: 60 }
                    PropertyAction { target: activePlayerIcon; property: "opacity"; value: 0 }
                    PropertyAction { target: switchableIcon; property: "opacity"; value: 0 }
                    PauseAnimation { duration: 50 }
                    PropertyAction { target: activePlayerIcon; property: "opacity"; value: 0.6 }
                    PropertyAction { target: switchableIcon; property: "opacity"; value: 0.4 }
                    PauseAnimation { duration: 70 }
                    PropertyAction { target: activePlayerIcon; property: "opacity"; value: 0 }
                    PropertyAction { target: switchableIcon; property: "opacity"; value: 0 }
                    PauseAnimation { duration: 40 }
                    PropertyAction { target: activePlayerIcon; property: "opacity"; value: 1.0 }
                    PropertyAction { target: switchableIcon; property: "opacity"; value: 1.0 }
                }
            }

            // Cleanup
            ScriptAction {
                script: {
                    tearShader.iTime = 0
                    tearTransition.visible = false
                    coverImg.visible = true
                    coverImgOld.visible = false
                }
            }
        }

        Item {
            id: infoWrapper

            anchors.left: parent.left
            anchors.leftMargin: 16

            readonly property real fullW: mediaWrapper.width - 32
            property real _w: 2
            width: _w
            clip: true
            transform: [
                Translate { id: infoShift; x: 0 },
                Translate { id: glitchShift; x: 0 }
            ]

            y: -(infoInner.implicitHeight + 12)
            implicitHeight: infoInner.implicitHeight

            Item {
                id: infoInner
                width: infoWrapper.fullW
                height: infoWrapper.implicitHeight
                implicitHeight: infoLayout.implicitHeight + 20

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: shapeMaskInfo
                }

                CutShape {
                    anchors.fill: parent
                    fillColor: root._glitchingInfo ? CP.alpha(root._borderColor, 0.12) : CP.alpha(CP.black, 0.86)
                    cutBottomRight: 24
                }

                ColumnLayout {
                    id: infoLayout
                    anchors {
                        left: parent.left; right: parent.right
                        top: parent.top
                        margins: 12
                    }
                    spacing: 2

                    // Artist
                    Text {
                        id: artistLabel
                        text: root.activePlayer?.trackArtist || "Play some music to show info here"
                        font.family: "Oxanium"
                        font.pixelSize: 18
                        color: root._glitchingInfo ? root._borderColor
                            : (root.activePlayer ? Colours.accentPrimary : Colours.textMuted)
                        elide: Text.ElideRight
                        wrapMode: root.activePlayer ? Text.NoWrap : Text.WordWrap
                    }

                    // Title
                    Text {
                        id: titleLabel
                        Layout.fillWidth: true
                        text: root.activePlayer?.trackTitle || "No media"
                        font.family: "Oxanium"
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        color: root._glitchingInfo ? root._borderColor
                            : (root.activePlayer ? CP.cyan : Colours.textSecondary)
                        elide: Text.ElideRight
                    }

                    // Album
                    Text {
                        id: albumLabel
                        visible: !!root.activePlayer
                        text: root.activePlayer?.trackAlbum || ""
                        font.family: "Oxanium"
                        font.pixelSize: 14
                        color: root._glitchingInfo ? root._borderColor
                            : Colours.textSecondary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Mask (same polygon filled white, invisible)
                CutShape {
                    id: shapeMaskInfo
                    layer.enabled: true
                    visible: false
                    anchors.fill: parent
                    fillColor: "white"
                    cutBottomRight: 24
                }

                Shape {
                    anchors.fill: parent
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: root._borderColor
                        strokeWidth: 12
                        startX: 0; startY: 0
                        PathLine { x: 0; y: parent.height }
                        PathLine { x: parent.width; y: parent.height }
                        PathLine { x: parent.width; y: 0 }
                        PathLine { x: parent.width; y: parent.height }
                        
                    }
                }
            }
        }

        CutShape {
            id: staticInfoShape
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: 8
            anchors.leftMargin: 12
            width: staticInfo.width + 16
            height: staticInfo.implicitHeight + 16
            fillColor: CP.alpha(CP.moduleBg, 0.86)
            strokeColor: Colours.neonBorder(0.63)
            strokeWidth: 3
            cutBottomRight: 24
            visible: !!root.activePlayer && root._showStaticInfo
            opacity: root._staticInfoOpacity
        }

        // Static info text top-left
        ColumnLayout {
            id: staticInfo
            width: Math.min(implicitWidth, (mediaWrapper.width - 24) / 2)
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: 16
            anchors.leftMargin: 16
            spacing: 1
            visible: !!root.activePlayer && root._showStaticInfo
            opacity: root._staticInfoOpacity

            Text {
                Layout.fillWidth: true
                text: root.activePlayer?.trackArtist ?? ""
                font.family: "Oxanium"
                font.pixelSize: 18
                font.weight: Font.Bold
                color: CP.yellowUI
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: root.activePlayer?.trackTitle ?? ""
                font.family: "Oxanium"
                font.pixelSize: 14
                font.weight: Font.Bold
                color: CP.cyan
                //wrapMode: Text.WordWrap
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: root.activePlayer?.trackAlbum ?? ""
                font.family: "Oxanium"
                font.pixelSize: 12
                color: Colours.textSecondary
                elide: Text.ElideRight
                visible: !!(root.activePlayer?.trackAlbum)
            }
        }

        // Layer 3: info + controls at the bottom
        ColumnLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 16
            anchors.bottomMargin: 12
            spacing: 12

            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                Layout.bottomMargin: 24
                implicitWidth: controlsRow.implicitWidth
                implicitHeight: controlsRow.implicitHeight

                // Like button
                Item {
                    id: likeBtn
                    width: 32; height: 32
                    anchors.right: controlsRow.left
                    anchors.rightMargin: 16
                    anchors.leftMargin: 12
                    anchors.verticalCenter: controlsRow.verticalCenter
                    opacity: root._trackId ? 1 : 0.2
                    visible: Players.isSpotifyActive    // only for spotify

                    Image {
                        id: likeIcon
                        anchors.centerIn: parent
                        width: 24; height: 24
                        sourceSize: Qt.size(24, 24)
                        fillMode: Image.PreserveAspectFit
                        source: {
                            if (root.isLiked && likeHover.hovered)
                                return "../../assets/SVG/heart-broken-svgrepo-com.svg"
                            if (root.isLiked)
                                return "../../assets/SVG/heart-electrocardiogram-2-svgrepo-com.svg"
                            if (likeHover.hovered)
                                return "../../assets/SVG/heart-electrocardiogram-2-svgrepo-com.svg"
                            return "../../assets/SVG/heart-electrocardiogram-1-svgrepo-com.svg"
                        }
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            colorization: 1.0
                            colorizationColor: {
                                if (root.isLiked && likeHover.hovered) return CP.red
                                if (root.isLiked) return CP.magenta
                                if (likeHover.hovered) return CP.cyan
                                return CP.alpha(CP.white, 0.6)
                            }
                            Behavior on colorizationColor { ColorAnimation { duration: 150 } }
                        }
                    }

                    transform: Translate { id: likeShift; x: 0 }
                    Text { id: likeDummy; visible: false }

                    GlitchAnim {
                        id: likeGlitch
                        shiftTarget: likeShift
                        labelTarget: likeDummy
                        shortMode: true
                        intensity: 0.8
                    }

                    SequentialAnimation {
                        id: likeBounce
                        NumberAnimation { target: likeIcon; property: "scale"; to: 1.3; duration: 80; easing.type: Easing.OutCubic }
                        NumberAnimation { target: likeIcon; property: "scale"; to: 1.0; duration: 120; easing.type: Easing.InOutCubic }
                    }

                    HoverHandler {
                        id: likeHover
                        onHoveredChanged: if (hovered && !likeGlitch.running) likeGlitch.restart()
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!root._trackId) return
                            root.isLiked = !root.isLiked
                            likeGlitch.restart()
                            likeBounce.restart()
                            likeProc.running = false
                            likeProc.command = ["/bin/sh", "-c",
                                "echo '{\"action\":\"toggleLike\",\"trackId\":\"" + root._trackId + "\"}' > /tmp/qs-lyrics-cmd.json"]
                            likeProc.running = true
                        }
                    }
                }

                // Controls
                RowLayout {
                    id: controlsRow
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 4
                    Layout.bottomMargin: 24
                    spacing: 54

                    // Previous
                    Item {
                        id: prevBtn
                        implicitWidth: 32; implicitHeight: 32
                        opacity: root.activePlayer?.canGoPrevious ?? false ? 1 : 0.35

                        property real glowOp: 0.0

                        SequentialAnimation {
                            running: prevArea.containsMouse
                            loops: Animation.Infinite
                            onStopped: prevBtn.glowOp = 0
                            NumberAnimation { target: prevBtn; property: "glowOp"; to: 1.0; duration: 40 }
                            PauseAnimation { duration: 620 }
                            NumberAnimation { target: prevBtn; property: "glowOp"; to: 0.15; duration: 25 }
                            PauseAnimation { duration: 50 }
                            NumberAnimation { target: prevBtn; property: "glowOp"; to: 1.0; duration: 35 }
                            PauseAnimation { duration: 360 }
                            NumberAnimation { target: prevBtn; property: "glowOp"; to: 0.0; duration: 20 }
                            PauseAnimation { duration: 40 }
                            NumberAnimation { target: prevBtn; property: "glowOp"; to: 0.8; duration: 20 }
                            PauseAnimation { duration: 30 }
                            NumberAnimation { target: prevBtn; property: "glowOp"; to: 0.0; duration: 20 }
                            PauseAnimation { duration: 65 }
                            NumberAnimation { target: prevBtn; property: "glowOp"; to: 1.0; duration: 80; easing.type: Easing.OutQuad }
                            PauseAnimation { duration: 510 }
                        }

                        Text { anchors.centerIn: parent; text: "⏮"; font.pixelSize: 72; font.family: "JetBrains Mono"; color: Qt.rgba(0.97, 0.94, 0.01, 0.06 * prevBtn.glowOp) }
                        Text { anchors.centerIn: parent; text: "⏮"; font.pixelSize: 60; font.family: "JetBrains Mono"; color: Qt.rgba(0.97, 0.94, 0.01, 0.12 * prevBtn.glowOp) }
                        Text { anchors.centerIn: parent; text: "⏮"; font.pixelSize: 50; font.family: "JetBrains Mono"; color: Qt.rgba(0.97, 0.94, 0.01, 0.25 * prevBtn.glowOp) }
                        Text { anchors.centerIn: parent; text: "⏮"; font.pixelSize: 42; font.family: "JetBrains Mono"; color: Qt.rgba(0.97, 0.94, 0.01, 0.45 * prevBtn.glowOp) }
                        Text { anchors.centerIn: parent; text: "⏮"; font.pixelSize: 36; font.family: "JetBrains Mono"; color: Qt.rgba(1, 1, 0.4, 0.70 * prevBtn.glowOp) }
                        Text {
                            id: prevLabel
                            anchors.centerIn: parent
                            text: "⏮"
                            font.pixelSize: 36
                            font.family: "JetBrains Mono"
                            color: CP.yellow
                            transform: Translate { id: labelShift; x: 0 }
                        }
                        MouseArea {
                            id: prevArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activePlayer?.previous()
                        }
                        GlitchAnim {
                            id: prevGlitch
                            labelTarget: prevLabel
                            shiftTarget: labelShift
                            baseColor: CP.yellow
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
                        id: playBtn
                        implicitWidth: 40; implicitHeight: 40
                        opacity: root.activePlayer?.canTogglePlaying ?? false ? 1 : 0.35

                        property real glowOp: 0.0
                        readonly property string icon: (root.activePlayer?.isPlaying ?? false) ? "⏸" : "▶"

                        SequentialAnimation {
                            running: playArea.containsMouse
                            loops: Animation.Infinite
                            onStopped: playBtn.glowOp = 0
                            NumberAnimation { target: playBtn; property: "glowOp"; to: 1.0; duration: 40 }
                            PauseAnimation { duration: 500 }
                            NumberAnimation { target: playBtn; property: "glowOp"; to: 0.0; duration: 18 }
                            PauseAnimation { duration: 45 }
                            NumberAnimation { target: playBtn; property: "glowOp"; to: 1.0; duration: 30 }
                            PauseAnimation { duration: 300 }
                            NumberAnimation { target: playBtn; property: "glowOp"; to: 0.2; duration: 25 }
                            PauseAnimation { duration: 35 }
                            NumberAnimation { target: playBtn; property: "glowOp"; to: 0.9; duration: 20 }
                            PauseAnimation { duration: 25 }
                            NumberAnimation { target: playBtn; property: "glowOp"; to: 0.0; duration: 18 }
                            PauseAnimation { duration: 75 }
                            NumberAnimation { target: playBtn; property: "glowOp"; to: 1.0; duration: 100; easing.type: Easing.OutQuad }
                            PauseAnimation { duration: 470 }
                        }

                        Text { anchors.centerIn: parent; text: playBtn.icon; font.pixelSize: 144; font.family: "JetBrains Mono";color: Qt.rgba(0.97, 0.94, 0.01, 0.06 * playBtn.glowOp) }
                        Text { anchors.centerIn: parent; text: playBtn.icon; font.pixelSize: 120; font.family: "JetBrains Mono"; color: Qt.rgba(0.97, 0.94, 0.01, 0.12 * playBtn.glowOp) }
                        Text { anchors.centerIn: parent; text: playBtn.icon; font.pixelSize: 100; font.family: "JetBrains Mono"; color: Qt.rgba(0.97, 0.94, 0.01, 0.25 * playBtn.glowOp) }
                        Text { anchors.centerIn: parent; text: playBtn.icon; font.pixelSize: 84; font.family: "JetBrains Mono"; color: Qt.rgba(0.97, 0.94, 0.01, 0.45 * playBtn.glowOp) }
                        Text { anchors.centerIn: parent; text: playBtn.icon; font.pixelSize: 72; font.family: "JetBrains Mono"; color: Qt.rgba(1, 1, 0.4, 0.70 * playBtn.glowOp) }
                        Text {
                            id: playLabel
                            anchors.centerIn: parent
                            text: playBtn.icon
                            font.pixelSize: 72
                            font.family: "JetBrains Mono"
                            color: CP.yellow
                            transform: Translate { id: labelShift3; x: 0 }
                        }
                        MouseArea {
                            id: playArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activePlayer?.togglePlaying()
                        }
                        GlitchAnim {
                            id: playGlitch
                            labelTarget: playLabel
                            shiftTarget: labelShift3
                            baseColor: CP.yellow
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
                        id: nextBtn
                        implicitWidth: 32; implicitHeight: 32
                        opacity: root.activePlayer?.canGoNext ?? false ? 1 : 0.35

                        property real glowOp: 0.0

                        SequentialAnimation {
                            running: nextArea.containsMouse
                            loops: Animation.Infinite
                            onStopped: nextBtn.glowOp = 0
                            NumberAnimation { target: nextBtn; property: "glowOp"; to: 1.0; duration: 40 }
                            PauseAnimation { duration: 700 }
                            NumberAnimation { target: nextBtn; property: "glowOp"; to: 0.1; duration: 20 }
                            PauseAnimation { duration: 30 }
                            NumberAnimation { target: nextBtn; property: "glowOp"; to: 1.0; duration: 30 }
                            PauseAnimation { duration: 420 }
                            NumberAnimation { target: nextBtn; property: "glowOp"; to: 0.0; duration: 20 }
                            PauseAnimation { duration: 55 }
                            NumberAnimation { target: nextBtn; property: "glowOp"; to: 0.7; duration: 25 }
                            PauseAnimation { duration: 35 }
                            NumberAnimation { target: nextBtn; property: "glowOp"; to: 0.0; duration: 15 }
                            PauseAnimation { duration: 80 }
                            NumberAnimation { target: nextBtn; property: "glowOp"; to: 1.0; duration: 90; easing.type: Easing.OutQuad }
                            PauseAnimation { duration: 540 }
                        }

                        Text { anchors.centerIn: parent; text: "⏭"; font.pixelSize: 72; font.family: "JetBrains Mono"; color: Qt.rgba(0.97, 0.94, 0.01, 0.06 * nextBtn.glowOp) }
                        Text { anchors.centerIn: parent; text: "⏭"; font.pixelSize: 60; font.family: "JetBrains Mono"; color: Qt.rgba(0.97, 0.94, 0.01, 0.12 * nextBtn.glowOp) }
                        Text { anchors.centerIn: parent; text: "⏭"; font.pixelSize: 50; font.family: "JetBrains Mono"; color: Qt.rgba(0.97, 0.94, 0.01, 0.25 * nextBtn.glowOp) }
                        Text { anchors.centerIn: parent; text: "⏭"; font.pixelSize: 42; font.family: "JetBrains Mono"; color: Qt.rgba(0.97, 0.94, 0.01, 0.45 * nextBtn.glowOp) }
                        Text { anchors.centerIn: parent; text: "⏭"; font.pixelSize: 36; font.family: "JetBrains Mono"; color: Qt.rgba(1, 1, 0.4, 0.70 * nextBtn.glowOp) }
                        Text {
                            id: nextLabel
                            anchors.centerIn: parent
                            text: "⏭"
                            font.pixelSize: 36
                            font.family: "JetBrains Mono"
                            color: CP.yellow
                            transform: Translate { id: labelShift2; x: 0 }
                        }
                        MouseArea {
                            id: nextArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activePlayer?.next()
                        }
                        GlitchAnim {
                            id: nextGlitch
                            labelTarget: nextLabel
                            shiftTarget: labelShift2
                            baseColor: CP.yellow
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
            }

            // Progress bar (click + drag to seek)
            Item {
                id: progressBar
                Layout.fillWidth: true
                implicitHeight: seekArea.containsMouse || seekArea.pressed ? 8 : 4
                Behavior on implicitHeight { NumberAnimation { duration: 120 } }

                Rectangle { anchors.fill: parent; radius: 2; color: CP.alpha(CP.cyan, 0.18) }
                Rectangle {
                    anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                    width: (seekArea.pressed ? seekArea._seekProgress : root.playerProgress) * parent.width
                    radius: 2; color: CP.cyan
                    Behavior on width { enabled: !seekArea.pressed; Anim { duration: 400; easing.type: Easing.Linear } }
                }

                MouseArea {
                    id: seekArea
                    anchors.fill: parent
                    anchors.topMargin: -8   // wider touch area
                    anchors.bottomMargin: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointHandCursor
                    preventStealing: true

                    property real _seekProgress: 0

                    function _seekTo(mx) {
                        const p = root.activePlayer
                        if (!p) return
                        _seekProgress = Math.max(0, Math.min(1, mx / progressBar.width))
                        p.position = _seekProgress * p.length
                    }

                    onPressed: function(mouse) { _seekTo(mouse.x) }
                    onPositionChanged: function(mouse) { if (pressed) _seekTo(mouse.x) }
                }
            }

            // Position / duration
            Item {
                Layout.fillWidth: true
                implicitHeight: posText.implicitHeight
                visible: !!root.activePlayer
                Text { id: posText; anchors.left: parent.left; text: formatTime(root.activePlayer?.position ?? 0); font.family: "Oxanium"; font.pixelSize: 9; color: Colours.textSecondary }
                Text { anchors.right: parent.right; text: formatTime(root.activePlayer?.length ?? 0); font.family: "Oxanium"; font.pixelSize: 9; color: Colours.textSecondary }
            }
        }
    }

    readonly property string trackInfoId:
        (activePlayer?.trackTitle ?? "") + "|" +
        (activePlayer?.trackArtist ?? "")
    
    onTrackInfoIdChanged: {
        if (activePlayer && trackInfoId !== "|") trackInfoAnim.restart()
    }

    SequentialAnimation {
        id: trackInfoAnim

        PropertyAction { target: root; property: "_showStaticInfo"; value: false }

        // Reset: hidden above, closed
        PropertyAction { target: infoWrapper; property: "y"; value: -(infoInner.implicitHeight + 12) }
        PropertyAction { target: infoWrapper; property: "_w"; value: 6 }

        // Drops down (closed - only left border visible)
        NumberAnimation {
            target: infoWrapper; property: "y"; to: 12
            duration: 700; easing.type: Easing.OutCubic
        }

        PauseAnimation { duration: 500 }

        // Opens to the right
        NumberAnimation {
            target: infoWrapper; property: "_w"; to: infoWrapper.fullW
            duration: 800; easing.type: Easing.OutQuart
        }

        ParallelAnimation {
            SequentialAnimation {
                loops: 3
                NumberAnimation { target: infoWrapper; property: "opacity"; to: 1.0; duration: 130 }
                NumberAnimation { target: infoWrapper; property: "opacity"; to: 0.6; duration: 100 }
                NumberAnimation { target: infoWrapper; property: "opacity"; to: 0.9; duration: 80 }
                NumberAnimation { target: infoWrapper; property: "opacity"; to: 0.4; duration: 120 }
                NumberAnimation { target: infoWrapper; property: "opacity"; to: 0.7; duration: 50 }
                NumberAnimation { target: infoWrapper; property: "opacity"; to: 1.0; duration: 130 }
                PauseAnimation { duration: 300 }
                NumberAnimation { target: infoWrapper; property: "opacity"; to: 1.0; duration: 80 }
                NumberAnimation { target: infoWrapper; property: "opacity"; to: 0.6; duration: 50 }
                NumberAnimation { target: infoWrapper; property: "opacity"; to: 0.9; duration: 80 }
                NumberAnimation { target: infoWrapper; property: "opacity"; to: 0.4; duration: 40 }
                NumberAnimation { target: infoWrapper; property: "opacity"; to: 1.0; duration: 80 }
            }
            PauseAnimation { duration: 5000 }

            // Intermittent jitter during the hold
            SequentialAnimation {
                // Burst 1 ~ 0.8s
                PauseAnimation { duration: 800 }
                PropertyAction { target: infoShift; property: "x"; value: 4 }
                PauseAnimation { duration: 35 }
                PropertyAction { target: infoShift; property: "x"; value: -3 }
                PropertyAction { target: infoWrapper; property: "_w"; value: infoWrapper.fullW - 14 }
                PauseAnimation { duration: 28 }
                PropertyAction { target: infoShift; property: "x"; value: 6 }
                PropertyAction { target: infoWrapper; property: "_w"; value: infoWrapper.fullW + 6 }
                PauseAnimation { duration: 20 }
                PropertyAction { target: infoShift; property: "x"; value: -2 }
                PropertyAction { target: infoWrapper; property: "_w"; value: infoWrapper.fullW }
                PauseAnimation { duration: 30 }
                PropertyAction { target: infoShift; property: "x"; value: 0 }

                // Burst 2 ~ 2.4s
                PauseAnimation { duration: 1400 }
                PropertyAction { target: infoShift; property: "x"; value: -5 }
                PauseAnimation { duration: 40 }
                PropertyAction { target: infoShift; property: "x"; value: 8 }
                PropertyAction { target: infoWrapper; property: "_w"; value: infoWrapper.fullW - 20 }
                PauseAnimation { duration: 30 }
                PropertyAction { target: infoShift; property: "x"; value: -2 }
                PropertyAction { target: infoWrapper; property: "_w"; value: infoWrapper.fullW }
                PauseAnimation { duration: 25 }
                PropertyAction { target: infoShift; property: "x"; value: 0 }

                // Burst 3 ~ 4.2s
                PauseAnimation { duration: 1800 }
                PropertyAction { target: infoShift; property: "x"; value: 3 }
                PropertyAction { target: infoWrapper; property: "_w"; value: infoWrapper.fullW - 10 }
                PauseAnimation { duration: 30 }
                PropertyAction { target: infoShift; property: "x"; value: -7 }
                PropertyAction { target: infoWrapper; property: "_w"; value: infoWrapper.fullW + 8 }
                PauseAnimation { duration: 25 }
                PropertyAction { target: infoShift; property: "x"; value: 2 }
                PropertyAction { target: infoWrapper; property: "_w"; value: infoWrapper.fullW }
                PauseAnimation { duration: 20 }
                PropertyAction { target: infoShift; property: "x"; value: 0 }
            }
        }

        // Closes back up
        NumberAnimation {
            target: infoWrapper; property: "_w"; to: 6
            duration: 300; easing.type: Easing.InQuart
        }

        PauseAnimation { duration: 500 }

        // Slides back up
        NumberAnimation {
            target: infoWrapper; property: "y"; to: -(infoInner.implicitHeight + 12)
            duration: 280; easing.type: Easing.InCubic
        }

        PauseAnimation { duration: 1000 }

        ScriptAction { script: { root._showStaticInfo = true; root._staticInfoOpacity = 0; staticInfoAnim.restart() } }
    }

    // Stepped glitch on border + shift (same approach as DashUser)
    SequentialAnimation {
        running: true
        loops: Animation.Infinite

        PropertyAction { target: root; property: "_borderColor"; value: CP.cyan }
        PropertyAction { target: root; property: "_glitchingInfo"; value: false }
        PropertyAction { target: glitchShift; property: "x"; value: 0 }
        PauseAnimation { duration: 1600 }

        // Burst 1
        PropertyAction { target: root; property: "_glitchingInfo"; value: true }
        PropertyAction { target: root; property: "_borderColor"; value: CP.magenta }
        PropertyAction { target: glitchShift; property: "x"; value: 3 }
        PauseAnimation { duration: 55 }

        PropertyAction { target: root; property: "_borderColor"; value: CP.yellow }
        PropertyAction { target: glitchShift; property: "x"; value: -3 }
        PauseAnimation { duration: 55 }

        PropertyAction { target: root; property: "_borderColor"; value: CP.cyan }
        PropertyAction { target: glitchShift; property: "x"; value: 2 }
        PauseAnimation { duration: 55 }

        PropertyAction { target: root; property: "_borderColor"; value: CP.cyan }
        PropertyAction { target: glitchShift; property: "x"; value: 0 }
        PauseAnimation { duration: 130 }

        // Micro burst
        PropertyAction { target: root; property: "_glitchingInfo"; value: true }
        PropertyAction { target: root; property: "_borderColor"; value: CP.magenta }
        PropertyAction { target: glitchShift; property: "x"; value: -2 }
        PauseAnimation { duration: 35 }

        PropertyAction { target: root; property: "_glitchingInfo"; value: false }
        PropertyAction { target: root; property: "_borderColor"; value: CP.cyan }
        PropertyAction { target: glitchShift; property: "x"; value: 0 }
        PauseAnimation { duration: 400 }

    }

    SequentialAnimation {
        id: staticInfoAnim

        PropertyAction { target: root; property: "_staticInfoOpacity"; value: 0.8 }
        PauseAnimation { duration: 18 }
        PropertyAction { target: root; property: "_staticInfoOpacity"; value: 0 }
        PauseAnimation { duration: 25 }
        PropertyAction { target: root; property: "_staticInfoOpacity"; value: 1.0 }
        PauseAnimation { duration: 30 }
        PropertyAction { target: root; property: "_staticInfoOpacity"; value: 0 }
        PauseAnimation { duration: 12 }
        PropertyAction { target: root; property: "_staticInfoOpacity"; value: 0.6 }
        PauseAnimation { duration: 20 }
        PropertyAction { target: root; property: "_staticInfoOpacity"; value: 0 }
        PauseAnimation { duration: 35 }
        PropertyAction { target: root; property: "_staticInfoOpacity"; value: 1.0 }
        PauseAnimation { duration: 22 }
        PropertyAction { target: root; property: "_staticInfoOpacity"; value: 0.4 }
        PauseAnimation { duration: 15 }
        PropertyAction { target: root; property: "_staticInfoOpacity"; value: 0 }
        PauseAnimation { duration: 8 }
        PropertyAction { target: root; property: "_staticInfoOpacity"; value: 1.0 }
        PauseAnimation { duration: 20 }
        PropertyAction { target: root; property: "_staticInfoOpacity"; value: 0.9 }
        PauseAnimation { duration: 25 }
        PropertyAction { target: root; property: "_staticInfoOpacity"; value: 1.0 }
    }

    function formatTime(secs) {
        if (!secs || secs < 0) return "-:--"
        const m = Math.floor(secs / 60)
        const s = Math.floor(secs % 60).toString().padStart(2, "0")
        return `${m}:${s}`
    }
}
