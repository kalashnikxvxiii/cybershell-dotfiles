// Vertical mini media player for the Dashboard tab
// Circular cover + progress arc + title/artist + controls

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

        // Cover + progress arc
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: width

            HoverHandler {
                onHoveredChanged: root.coverHovered = hovered
            }

            ServiceRef { service: Audio.cava }

            // Circular audio wave
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
                    ctx.strokeStyle = CP.alpha(CP.cyanBright, 0.25)
                    ctx.lineWidth   = 10
                    ctx.stroke()

                    // Main line
                    ctx.strokeStyle = CP.cyan2
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
                    text: "♪"
                    font.pixelSize: root.fontSize * 4
                    color: Colours.textSecondary
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

                // Spin-out of the old cover
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
                onVisibleChanged: if (visible) requestPaint()
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
                        ctx.strokeStyle = CP.yellow
                        ctx.lineWidth = 3
                        ctx.lineCap = "round"
                        ctx.stroke()
                    }
                }
            }

            // Click + drag on the arc to seek
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
                onWheel: function(event) {
                    const player = Players.active
                    if (!player) return
                    player.volume = Math.max(0.0, Math.min(1.0, player.volume + (event.angleDelta.y / 120) * 0.04))
                }
            }

            // === Player Switcher with circular orbit ===
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
                    coverImgOld.spin = 0
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
                        // Check if spotify is already at bottom (cos equals +1)
                        const spotifyAtBottom = Math.round(Math.cos(switcherOrbit.rotAngle * Math.PI / 180)) === 1
                        // If state doesn't match position, rotate
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

            // Controls (extracted to MediaMiniControls.qml)
            MediaMiniControls {
                z: 10
                anchors.centerIn: parent
                activePlayer: root.activePlayer
                buttonSize: root.buttonSize
                fontSize: root.fontSize
                coverHovered: root.coverHovered
            }
        }

        // Track title
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

        // Artist
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
