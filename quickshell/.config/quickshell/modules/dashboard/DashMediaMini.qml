// Vertical mini RADIOPORT for the Dashboard tab (layout of DashMediaTab,
// stacked for a narrow cell). Keeps the circular cover with the circular cava
// wave, the progress arc (click/drag to seek), the cover-tinted accent, the
// hover controls and the wheel volume. The radioport's player list replaces
// the orbital switcher; the cover still spins when the player changes.

import CyberAudio.Services
import CyberGraphics
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "../../common/Colors.js" as CP
import "../../common"
import "../../common/effects"

Item {
    id: root

    readonly property MprisPlayer activePlayer: Players.active
    readonly property real fontSize: Math.min(width * 0.12, height * 0.12)
    readonly property real buttonSize: Math.min(width * 0.12, height * 0.12)
    property bool coverHovered: false
    property real playerProgress: 0

    readonly property int   rowHeight: 26
    readonly property color accent1: CP.cyan
    readonly property color accent2: CP.alpha(CP.red, 0.5)
    readonly property real  h1: 13
    readonly property real  h2: 10

    // Accent taken from the current cover art. Only this player follows it:
    // the rest of the shell stays on the wallust palette.
    property color coverAccent: CP.neonize(coverAnalyser.dominantColour, CP.yellow)
    Behavior on coverAccent { CAnim { duration: 320 } }

    layer.enabled: true
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: shapeMask
    }

    function volume(p) { return p && p.volumeSupported ? p.volume : null }
    function changeVolume(p, delta) {
        const v = volume(p)
        if (v !== null && p.canControl) p.volume = Math.max(0, Math.min(1, v + delta))
    }

    // Row click: the active one toggles, another one takes over (old paused,
    // new played) while the old cover spins out.
    function switchTo(p) {
        if (!p) return
        if (p === root.activePlayer) { p.togglePlaying(); return }
        const old = root.activePlayer
        coverImgOld.source = coverImg.source
        coverImgOld.spin = 0
        coverImgOld.visible = true
        coverImgOld.opacity = 1
        coverOutAnim.restart()
        coverInAnim.restart()
        Players.select(p)
        if (old?.isPlaying && old.canPause) old.pause()
        if (p.canPlay) p.play()
    }

    component MiniVolButton: Item {
        id: btn
        property string label
        property real step: 0.01

        implicitWidth: 18
        implicitHeight: 18

        Rectangle {
            anchors.fill: parent
            color: hit.pressed ? CP.alpha(root.accent1, 0.3) : "transparent"
            border.width: 1
            border.color: root.accent1
        }
        Text {
            anchors.centerIn: parent
            text: btn.label
            color: root.accent1
            font.family: "Oxanium"
            font.pixelSize: root.h1 - 1
        }
        MouseArea {
            id: hit
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.changeVolume(root.activePlayer, btn.step)
        }
    }

    // The cover is analysed by grabbing the live Image, not by pointing source
    // at its URL: MPRIS art is often a remote URL, which QImage cannot open.
    ImageAnalyser {
        id: coverAnalyser
        sourceItem: coverImg
        rescaleSize: 48
    }

    // Grabbing on Image.Ready would catch the crossfade mid-flight and read the
    // still-transparent pixels as empty. Waiting out the 500ms fade also
    // debounces bursts of track changes.
    Timer {
        id: coverAnalyseDelay
        interval: 600
        onTriggered: coverAnalyser.requestUpdate()
    }

    Process {
        id: focusProc
        command: ["hyprctl", "dispatch", "focuswindow",
                "class:" + (root.activePlayer?.desktopEntry ?? "")]
        running: false
    }

    // Position pulse: MPRIS doesn't push position. Tick at ~5Hz and recompute
    // ratio directly (same pattern as MprisModule). No Behavior needed —
    // the arc moves a few pixels a second.
    Ticker {
        id: progressTimer
        every: 6    // ~5Hz: the arc moves about 3px a second
        running: root.visible
                 && root.activePlayer
                 && root.activePlayer.positionSupported
                 && root.activePlayer.playbackState === MprisPlaybackState.Playing
        triggeredOnStart: true
        onTicked: {
            const p = root.activePlayer
            if (!p || !p.lengthSupported || p.length <= 0) {
                root.playerProgress = 0
                return
            }
            root.playerProgress = Math.max(0, Math.min(1, p.position / p.length))
        }
    }

    // Snap to 0 when player stops/changes (so arc doesn't stay stale)
    Connections {
        target: root.activePlayer
        function onTrackTitleChanged() { root.playerProgress = 0 }
    }
    onActivePlayerChanged: playerProgress = 0

    CutShape {
        anchors.fill: parent
        fillColor: "transparent"
        cutTopRight: 26; cutBottomLeft: 26
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        anchors.topMargin: 8
        spacing: 6

        Text {
            Layout.fillWidth: true
            text: "Tkla:__;v.0.02"
            color: root.accent2
            font.family: "Oxanium"
            font.pixelSize: root.h2
        }

        // RADIOPORT tag + active player badge (click = focus its window)
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            CutShape {
                anchors.fill: parent
                cutBottomLeft: 6; cutBottomRight: 6
                strokeWidth: 2; inset: 1
                strokeColor: root.accent2
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 10
                text: "RADIOPORT"
                color: root.accent1
                font.family: "Oxanium"
                font.pixelSize: root.h1
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 10
                visible: !!root.activePlayer
                text: Players.isSpotifyActive ? "" : ""
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
                color: badgeArea.containsMouse ? CP.neon : root.accent1
                MouseArea {
                    id: badgeArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: focusProc.running = true
                }
            }
        }

        // Cover + cava wave + progress arc: the square takes what the cell
        // leaves, with room around it for the wave
        Item {
            id: coverBox
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 90

            Item {
                id: coverSq
                anchors.centerIn: parent
                width: Math.min(coverBox.width, coverBox.height) / 1.36
                height: width

                HoverHandler {
                    onHoveredChanged: root.coverHovered = hovered
                }

                // FFT capture only while the card is on screen and something plays:
                // nobody reads it otherwise. Released at pause, not at hide: joining
                // an idle capture thread blocks the GUI thread for up to 500 ms (see
                // CavaModule), which showed as the closing dashboard hanging at the end
                ServiceRef { service: root.visible && (root.activePlayer?.isPlaying ?? false) ? Audio.cava : null }

                // Circular audio wave
                Canvas {
                    id: audioWave
                    anchors.centerIn: parent
                    readonly property real maxDisp: parent.width * 0.18
                    width: parent.width + maxDisp * 2
                    height: parent.height + maxDisp * 2
                    enabled: false
                    z: -10

                    property var cavaValues: []
                    onVisibleChanged: if (visible) requestPaint()

                    // Snapshot at 30Hz instead of following the FFT's ~90 emissions a
                    // second: each one re-ran the whole path in JS. An unchanged
                    // frame (paused, decayed to zero) is not repainted at all
                    property real _sig: -1
                    Ticker {
                        running: audioWave.visible
                        triggeredOnStart: true
                        onTicked: {
                            // The provider is released at pause and keeps its last frame:
                            // decay what is on screen back to the resting circle instead
                            const v = (root.activePlayer?.isPlaying ?? false)
                                ? Audio.cava.values
                                : (audioWave.cavaValues.length ? audioWave.cavaValues : Audio.cava.values)
                                    .map(x => x < 0.01 ? 0 : x * 0.75)
                            let sig = 0
                            for (let i = 0; i < v.length; i++) sig += v[i] * (i + 1)
                            if (sig === audioWave._sig) return
                            audioWave._sig = sig
                            audioWave.cavaValues = v
                            audioWave.requestPaint()
                        }
                    }

                    property color accent: root.coverAccent
                    onAccentChanged: requestPaint()

                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()

                        const cx = width / 2
                        const cy = height / 2
                        const baseR = (parent.width - 10) / 2
                        const bars = Audio.cava.bars
                        const vals = cavaValues
                        if (!vals || vals.length === 0) return

                        // Points along the circular wave
                        const pts = []
                        for (let i = 0; i < bars; i++) {
                            const angle = (i / bars) * 2 * Math.PI - Math.PI / 2
                            const val = vals[i] ?? 0
                            const r = baseR + val * maxDisp
                            pts.push({ x: cx + r * Math.cos(angle),
                                    y: cy + r * Math.sin(angle) })
                        }

                        // Smooth closed curve (midpoint quadratic bezier)
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

                        // Glow layer (thick, semi-transparent)
                        ctx.strokeStyle = CP.alpha(accent, 0.25)
                        ctx.lineWidth   = 10
                        ctx.stroke()

                        // Main line
                        ctx.strokeStyle = accent
                        ctx.lineWidth   = 1.5
                        ctx.stroke()
                    }
                }

                // Circular cover art
                ClippingRectangle {
                    id: coverRect
                    anchors.fill: parent
                    anchors.margins: 6
                    radius: width / 2
                    color: Colours.moduleBgAlt

                    Text {
                        anchors.centerIn: parent
                        text: "NO SIGNAL"
                        font.family: "Oxanium"
                        font.pixelSize: root.h1
                        color: root.accent2
                        visible: coverImg.status !== Image.Ready || !root.activePlayer
                    }

                    // Outgoing image (captures the cover before switching)
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
                        onStatusChanged: if (status === Image.Ready) coverAnalyseDelay.restart()

                        property real spin: 0
                        rotation: spin
                    }

                    // Spin-out of the old cover
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

                    // Spin-in of the new cover
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

                // Overlaid progress arc
                Canvas {
                    id: progressArc
                    anchors.fill: parent
                    visible: !!root.activePlayer

                    readonly property real prog: root.playerProgress
                    onProgChanged: requestPaint()

                    property color accent: root.coverAccent
                    onAccentChanged: requestPaint()
                    onVisibleChanged: if (visible) requestPaint()
                    onWidthChanged: requestPaint()
                    Component.onCompleted: requestPaint()

                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const cx = width / 2
                        const cy = height / 2
                        const r  = (Math.min(width, height) - 6) / 2
                        // Background track
                        ctx.beginPath()
                        ctx.arc(cx, cy, r, -Math.PI / 2, 3 * Math.PI / 2)
                        ctx.strokeStyle = CP.red
                        ctx.lineWidth = 3
                        ctx.stroke()
                        // Progress
                        if (prog > 0) {
                            ctx.beginPath()
                            ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + prog * 2 * Math.PI)
                            ctx.strokeStyle = accent
                            ctx.lineWidth = 3
                            ctx.lineCap = "round"
                            ctx.stroke()
                        }
                    }
                }

                // Click + drag on the arc to seek
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    preventStealing: true
                    acceptedButtons: Qt.LeftButton

                    function _seekFromMouse(mx, my) {
                        const p = root.activePlayer
                        if (!p) return
                        const cx = width / 2
                        const cy = height / 2
                        // Angle from center (0 = top, clockwise)
                        const angle = Math.atan2(mx - cx, -(my - cy))
                        // Normalize from -PI..PI to 0..1
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
                    onWheel: event => root.changeVolume(root.activePlayer, (event.angleDelta.y / 120) * 0.04)
                }

                // Controls (extracted to MediaMiniControls.qml)
                MediaMiniControls {
                    z: 10
                    anchors.centerIn: parent
                    activePlayer: root.activePlayer
                    accent: root.coverAccent
                    buttonSize: root.buttonSize
                    fontSize: root.fontSize
                    coverHovered: root.coverHovered
                }
            }
        }

        Text {
            text: "now playing"
            color: root.accent2
            font.family: "Oxanium"
            font.pixelSize: root.h2
        }
        Rectangle { // separator
            Layout.fillWidth: true
            Layout.preferredHeight: 2
            color: CP.alpha(root.accent2, 0.5)
        }

        Text { // artist - title
            Layout.fillWidth: true
            text: root.activePlayer
                  ? (root.activePlayer.trackArtist || "Unknown Artist") + " - "
                    + (root.activePlayer.trackTitle || root.activePlayer.identity || "Unknown Title")
                  : "Nessun player"
            color: CP.red
            font.family: "Oxanium"
            font.pixelSize: root.h1
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            MouseArea {
                anchors.fill: parent
                cursorShape: root.activePlayer ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: if (root.activePlayer) focusProc.running = true
            }
        }

        RowLayout { // volume
            id: volRow
            Layout.fillWidth: true
            spacing: 6

            readonly property var raw: root.volume(root.activePlayer)

            Text {
                text: "volume"
                color: CP.red
                font.family: "Oxanium"
                font.pixelSize: root.h1
            }
            Item { Layout.fillWidth: true } // spacer

            MiniVolButton { label: "A"; step: -0.01 }
            Text {
                Layout.preferredWidth: 36 // fixed width so the buttons don't jitter
                horizontalAlignment: Text.AlignHCenter
                text: volRow.raw !== null && volRow.raw !== undefined ? Math.round(volRow.raw * 100) + "%" : "N/A"
                color: root.accent1
                font.family: "Oxanium"
                font.pixelSize: root.h1
            }
            MiniVolButton { label: "D"; step: 0.01 }
        }

        Rectangle { // separator
            Layout.fillWidth: true
            Layout.preferredHeight: 2
            color: root.accent2
        }

        // Players: click to switch, click the active one to play/pause
        ListView {
            id: mediaList
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(1, Math.min(count, 3)) * root.rowHeight
            interactive: count > 3
            clip: true

            model: Mpris.players

            delegate: Item {
                id: playerItem
                required property var modelData // MprisPlayer
                readonly property bool isActive: modelData === root.activePlayer

                width: mediaList.width
                height: root.rowHeight
                CutShape {
                    anchors.fill: parent
                    cutBottomLeft: 6; cutBottomRight: 6
                    strokeWidth: 2; inset: 1
                    fillColor: playerItem.isActive ? CP.alpha(root.accent1, 0.3) : "transparent"
                    strokeColor: playerItem.isActive ? CP.alpha(root.accent1, 0.6) : "transparent"
                }
                Text {
                    width: playerItem.width - 15
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    text: playerItem.modelData.trackTitle || playerItem.modelData.identity || "Unknown Player"
                    elide: Text.ElideRight
                    color: root.accent1
                    font.family: "Oxanium"
                    font.pixelSize: root.h1
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchTo(playerItem.modelData)
                }
            }
        }

        Rectangle { // separator
            Layout.fillWidth: true
            Layout.preferredHeight: 2
            color: root.accent2
        }
        Text {
            Layout.fillWidth: true
            text: "cyberdeckNutz"
            color: root.accent2
            font.family: "Oxanium"
            font.pixelSize: root.h2
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
