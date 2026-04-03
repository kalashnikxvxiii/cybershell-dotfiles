// Mini media player verticale per la Dashboard tab
// Copertina circolare + progress arc + titolo/artista + controlli

import CyberAudio.Services
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "../../common/Colors.js" as CP
import "../../common"

Item {
    id: root

    readonly property MprisPlayer activePlayer: Players.active
    readonly property real fontSize: Math.min(width * 0.12, height * 0.12)
    readonly property real buttonSize: Math.min(width * 0.12, height * 0.12)
    property bool coverHovered: false
    property real playerProgress: {
        const p = activePlayer
        return (p && p.length > 0) ? p.position / p.length : 0
    }

    layer.enabled: true
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: shapeMask
    }

    Behavior on playerProgress {
        Anim { duration: 400 }
    }

    Process {
        id: focusProc
        command: ["hyprctl", "dispatch", "focuswindow",
                "class:" + (root.activePlayer?.desktopEntry ?? "")]
        running: false
    }

    CutShape {
        anchors.fill: parent
        fillColor: "transparent"
        cutTopRight: 26; cutBottomLeft: 26
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 4

        // Copertina + progress arc
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: width

            HoverHandler {
                onHoveredChanged: root.coverHovered = hovered
            }

            ServiceRef { service: Audio.cava }

            // Audio wave circolare
            Canvas {
                id: audioWave
                anchors.centerIn: parent
                readonly property real maxDisp: parent.width * 0.18
                width: parent.width + maxDisp * 2
                height: parent.height + maxDisp * 2
                enabled: false
                z: -10

                property var cavaValues: Audio.cava.values
                onCavaValuesChanged: requestPaint()

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()

                    const cx = width / 2
                    const cy = height / 2
                    const baseR = (parent.width - 10) / 2
                    const bars = Audio.cava.bars
                    const vals = cavaValues
                    if (!vals || vals.length === 0) return

                    // Punti sulla wave circolare
                    const pts = []
                    for (let i = 0; i < bars; i++) {
                        const angle = (i / bars) * 2 * Math.PI - Math.PI / 2
                        const val = vals[i] ?? 0
                        const r = baseR + val * maxDisp
                        pts.push({ x: cx + r * Math.cos(angle),
                                y: cy + r * Math.sin(angle) })
                    }

                    // Curva chiusa liscia (midpoint quadratic bezier)
                    ctx.beginPath()
                    ctx.moveTo((pts[0].x + pts[bars - 1].x) / 2,
                                (pts[0].y + pts[bars - 1].y) / 2)
                    for (let i = 0; i < bars; i++) {
                        const p = pts[i]
                        const n = pts[(i + 1) % bars]
                        ctx.quadraticCurveTo(p.x, p.y,
                                            (p.x + n.x) /2, (p.y + n.y) / 2)
                    }
                    ctx.closePath()

                    // Glow layer (spesso, semitrasparente)
                    ctx.strokeStyle = CP.alpha(CP.cyanBright, 0.25)
                    ctx.lineWidth   = 10
                    ctx.stroke()

                    // Linea principale
                    ctx.strokeStyle = CP.cyan2
                    ctx.lineWidth   = 1.5
                    ctx.stroke()
                }
            }

            // Copertina circolare
            ClippingRectangle {
                id: coverRect
                anchors.fill: parent
                anchors.margins: 6
                radius: width / 2
                color: Colours.moduleBgAlt

                Text {
                    anchors.centerIn: parent
                    text: "♪"
                    font.pixelSize: root.fontSize * 4
                    color: Colours.textSecondary
                    visible: coverImg.status !== Image.Ready || !root.activePlayer
                }

                // Immagine uscente (cattura la cover prima dello switch)
                Image {
                    id: coverImgOld
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                    property real spin: 0
                    rotation: spin
                    opacity: 0
                }

                Image {
                    id: coverImg
                    anchors.fill: parent
                    source: root.activePlayer?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true

                    property real spin: 0
                    rotation: spin
                }

                ParallelAnimation {
                    id: coverOutAnim
                    NumberAnimation {
                        target: coverImgOld; property: "spin"
                        from: 0; to: 1080
                        duration: 450; easing.type: Easing.InCubic
                    }
                    NumberAnimation {
                        target: coverImgOld; property: "opacity"
                        to: 0; duration: 450
                    }
                    onFinished: coverImgOld.visible = false
                }

                // Spin-out della vecchia copertina
                ParallelAnimation {
                    id: coverInAnim
                    NumberAnimation {
                        target: coverImg; property: "spin"
                        from: 0; to: 1080
                        duration: 500; easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: coverImg; property: "opacity"
                        from: 0; to: 1; duration: 500
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: coverRect.width / 2
                    color: CP.alpha(CP.black, 0.75)
                    opacity: root.coverHovered ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                }
            }

            // Arc di progresso sovrapposto
            Canvas {
                id: progressArc
                anchors.fill: parent
                visible: !!root.activePlayer

                readonly property real prog: root.playerProgress
                onProgChanged: requestPaint()
                onVisibleChanged: if (visible) requestPaint()
                Component.onCompleted: requestPaint()

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const cx = width / 2
                    const cy = height / 2
                    const r  = (Math.min(width, height) - 6) / 2
                    // Track di sfondo
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, -Math.PI / 2, 3 * Math.PI / 2)
                    ctx.strokeStyle = CP.red
                    ctx.lineWidth = 3
                    ctx.stroke()
                    // Progresso
                    if (prog > 0) {
                        ctx.beginPath()
                        ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + prog * 2 * Math.PI)
                        ctx.strokeStyle = CP.yellow
                        ctx.lineWidth = 3
                        ctx.lineCap = "round"
                        ctx.stroke()
                    }
                }
            }

            // Click + drag sull'arco per seek
            MouseArea {
                id: arcSeekArea
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                acceptedButtons: Qt.LeftButton

                function _seekFromMouse(mx, my) {
                    const p = root.activePlayer
                    if (!p) return
                    const cx = width / 2
                    const cy = height / 2
                    // Angolo del centro (0 = top, orario)
                    const angle = Math.atan2(mx - cx, -(my - cy))
                    // Normalizza da -PI..PI a 0..1
                    let progress = angle / (2 * Math.PI)
                    if (progress < 0) progress += 1
                    p.position = Math.max(0, Math.min(1, progress)) * p.length
                }

                onPressed: function(mouse) {
                    let cx = width / 2, cy = height / 2
                    let dx = mouse.x - cx, dy = mouse.y - cy
                    let dist = Math.sqrt(dx * dx + dy * dy)
                    let r = (Math.min(width, height) - 6) / 2
                    if (Math.abs(dist - r) <= 5) _seekFromMouse(mouse.x, mouse.y)
                    else mouse.accepted = false
                }
                onPositionChanged: function(mouse) { if (pressed) _seekFromMouse(mouse.x, mouse.y) }
                onWheel: function(event) {
                    const player = Players.active
                    if (!player) return
                    player.volume = Math.max(0.0, Math.min(1.0, player.volume + (event.angleDelta.y / 120) * 0.04))
                }
            }

            // === Player Switcher con orbita circolare ===
            Item {
                id: switcherOrbit
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                z: 5
                visible: true
                opacity:  1
                Behavior on opacity { NumberAnimation { duration: 150 } }

                property real rotAngle: 0
                readonly property real orbitR: parent.width / 2 - 18

                Component.onCompleted: if (!Players.isSpotifyActive) rotAngle = 180

                function doToggle() {
                    coverImgOld.source = coverImg.source
                    coverImgOld.visible = true
                    coverImgOld.opacity = 1
                    coverOutAnim.restart()
                    coverInAnim.restart()

                    rotAngle += 180
                    Players.togglePlayer()
                }

                Behavior on rotAngle {
                    NumberAnimation { duration: 420; easing.type: Easing.InOutCubic }
                }

                Connections {
                    target: Players
                    function onIsSpotifyActiveChanged() {
                        // Controlla se spotify e' gia' al bottom (cos pari a +1)
                        const spotifyAtBottom = Math.round(Math.cos(switcherOrbit.rotAngle * Math.PI / 180)) === 1
                        // Se lo stato non corrisponde alla posizione, ruota
                        if (Players.isSpotifyActive !== spotifyAtBottom) {
                            switcherOrbit.rotAngle += 180
                        }
                    }
                }

                // Spotify
                Rectangle {
                    width: 28; height: 16
                    opacity: Players.isSpotifyActive ? 1 : (Players.canSwitch && root.coverHovered ? 1 : 0)
                    x: switcherOrbit.width / 2 - width / 2 - switcherOrbit.orbitR * Math.sin(switcherOrbit.rotAngle * Math.PI / 180)
                    y: switcherOrbit.height / 2 - height / 2 + switcherOrbit.orbitR * Math.cos(switcherOrbit.rotAngle * Math.PI / 180)
                    color: "transparent"
                    Behavior on opacity { NumberAnimation { duration: 150 } } 
                    Text {
                        anchors.centerIn: parent
                        text: "\uf1bc"
                        font.family: "Oxanium"
                        font.pixelSize: 21
                        font.weight: Font.Bold
                        color: Players.isSpotifyActive ? CP.neon : CP.alpha(CP.white, 0.5)
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (!Players.isSpotifyActive) switcherOrbit.doToggle()
                                    else focusProc.running = true
                    }
                }

                // Browser
                Rectangle {
                    width: 28; height: 16
                    opacity: !Players.isSpotifyActive ? 1 : (Players.canSwitch && root.coverHovered ? 1 : 0)
                    x: switcherOrbit.width / 2 - width / 2 - switcherOrbit.orbitR * Math.sin((switcherOrbit.rotAngle + 180) * Math.PI / 180)
                    y: switcherOrbit.height / 2 - height / 2 + switcherOrbit.orbitR * Math.cos((switcherOrbit.rotAngle + 180) * Math.PI / 180)
                    color: "transparent"
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    Text {
                        anchors.centerIn: parent
                        text: "\ueb01"
                        font.family: "Oxanium"
                        font.pixelSize: 21
                        font.weight: Font.Bold
                        color: !Players.isSpotifyActive ? CP.neon : CP.alpha(CP.white, 0.5)
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (Players.isSpotifyActive) switcherOrbit.doToggle()
                                    else focusProc.running = true
                    }
                }
            }

            // Controlli
            RowLayout {     
                z: 10           
                spacing: 6
                anchors.centerIn: parent
                opacity: root.coverHovered ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 180 } }

                
                // Precedente
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

                // Successivo
                // Successivo
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
        }

        // Titolo traccia
        Text {
            Layout.fillWidth: true
            text: root.activePlayer?.trackTitle || "No media"
            font.family: "Oxanium"
            font.pixelSize: 20
            font.weight: Font.Bold
            color: root.activePlayer ? CP.cyan : Colours.textSecondary
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            MouseArea { 
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.activePlayer) focusProc.running = true
            }
        }

        // Artista
        Text {
            Layout.fillWidth: true
            visible: !!root.activePlayer
            text: root.activePlayer?.trackArtist || ""
            font.family: "Oxanium"
            font.pixelSize: 18
            color: Colours.accentPrimary
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            MouseArea { 
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.activePlayer) focusProc.running = true
            }
        }
    }

    CutShape {
        id: shapeMask
        layer.enabled: true
        visible: false
        anchors.fill: parent
        fillColor: "white"
        cutBottomLeft: 26; cutTopRight: 26
    }
}
