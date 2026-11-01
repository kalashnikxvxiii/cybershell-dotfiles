// Radioport.qml -- the standalone RADIOPORT, laid out like the game's: header strip, cover
// beside the track, stations below, key hints at the bottom. Same functions as the
// dashboard's DashMediaTab, which stays as it is.
//
// Keys: Up/Down source, Space/Enter play, Left/Right track, A/D volume -/+1%.
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Effects
import "../../common/Colors.js" as CP
import "../../common"
import "../dashboard"

FocusScope {
    id: root

    // A hidden window's content stays `visible`: this is what gates whatever runs
    property bool active: false

    readonly property MprisPlayer player: Players.active
    readonly property var players: Mpris.players.values
    readonly property real progress: player && player.length > 0 ? player.position / player.length : 0
    readonly property color danger: CP.red
    readonly property color tech: CP.cyan
    readonly property string font: "Oxanium"
    property bool isLiked: Players.isLiked

    readonly property string _trackId: {
        const url = String(root.player?.metadata?.["xesam:url"] ?? "")
        if (url.startsWith("spotify:track:")) return url.split(":")[2]
        const m = url.match(/\/track\/([A-Za-z0-9]+)/)
        return m ? m[1] : ""
    }

    implicitWidth: 460
    // Room for four stations, so it lines up with the equalizer
    implicitHeight: 380 + Math.max(4, players.length) * 42 + 80

    // Every player gets a frequency of its own, the same one each time
    function stationName(p) {
        if (!p)
            return "NO STATION"
        const name = p.identity || "Unknown"
        let h = 0
        for (let i = 0; i < name.length; i++)
            h = (h * 31 + name.charCodeAt(i)) % 100000
        return (87.5 + (h % 205) / 10).toFixed(1) + " " + name.toUpperCase() + (h % 2 ? " FM" : " RADIO")
    }

    function changeVolume(delta) {
        const p = root.player
        if (p && p.volumeSupported && p.canControl) p.volume = Math.max(0, Math.min(1, p.volume + delta))
    }

    // The active row toggles, another one takes over: old paused, new played
    function switchTo(p) {
        if (!p) return
        if (p === root.player) { p.togglePlaying(); return }
        const old = root.player
        coverOld.source = cover.source
        Players.select(p)
        if (old?.isPlaying && old.canPause) old.pause()
        if (p.canPlay) p.play()
        tear.restart()
    }

    // From the keyboard only moves the selection: browsing must not start anything
    function stepSource(delta) {
        const n = root.players.length
        if (n < 2) return
        coverOld.source = cover.source
        Players.select(root.players[(root.players.indexOf(root.player) + delta + n) % n])
        tear.restart()
    }

    function formatTime(secs) {
        if (!secs || secs < 0) return "-:--"
        return Math.floor(secs / 60) + ":" + Math.floor(secs % 60).toString().padStart(2, "0")
    }

    onActiveChanged: if (active) forceActiveFocus()

    Keys.onPressed: e => {
        const p = root.player
        if (e.key === Qt.Key_Up) root.stepSource(-1)
        else if (e.key === Qt.Key_Down) root.stepSource(1)
        else if (e.key === Qt.Key_Left) p?.previous()
        else if (e.key === Qt.Key_Right) p?.next()
        else if (e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) p?.togglePlaying()
        else if (e.key === Qt.Key_A) root.changeVolume(-0.01)
        else if (e.key === Qt.Key_D) root.changeVolume(0.01)
        else return
        e.accepted = true
    }

    // MPRIS doesn't push position: poke it while playing and on screen
    Timer {
        running: root.active && (root.player?.isPlaying ?? false)
        interval: 500
        repeat: true
        triggeredOnStart: true
        onTriggered: root.player?.positionChanged()
    }

    Process { id: likeProc }
    Process {
        id: focusProc
        command: ["hyprctl", "dispatch", "focuswindow", "class:" + (root.player?.desktopEntry ?? "")]
    }

    // ---------- header ----------
    RadioportHeader {
        id: header
        width: root.width
        code: "Tkla:__;v.0.02"
        title: "RADIOPORT"
        tint: tagGlitch.tint

        // Active player badge: click brings its window forward
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            visible: !!root.player
            text: Players.isSpotifyActive ? "\uf1bc" : "\uf269"
            color: badgeArea.containsMouse ? CP.neon : root.tech
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
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

    // ---------- cover ----------
    CutShape {
        y: 66
        width: 8
        height: 200
        cutTopLeft: 2
        cutBottomLeft: 2
        fillColor: CP.alpha(root.danger, 0.3)
    }
    Item {
        x: 10
        y: 66
        width: 200
        height: 200

        // Follows the frame's cut: the image must not stick out of it
        CutShape {
            id: coverMask
            anchors.fill: coverArea
            visible: false
            cutBottomRight: 10
            fillColor: "white"
        }
        Item {
            id: coverArea
            anchors.fill: parent
            anchors.margins: 3
            clip: true
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: coverMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }

            Image {
                id: coverOld
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                visible: false
            }
            Image {
                id: cover
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(width * 2, height * 2)
            }

            // Screen tear: strips flip from the old cover to the new one
            Item {
                id: tearStrips
                anchors.fill: parent
                visible: false
                clip: true

                readonly property int sliceCount: 14
                property real progress: 0
                property real displacement: 0

                Repeater {
                    model: tearStrips.sliceCount
                    Item {
                        required property int index
                        clip: true
                        width: tearStrips.width
                        height: tearStrips.height / tearStrips.sliceCount
                        y: index * height

                        readonly property bool showNew: tearStrips.progress > (Math.sin(index * 4.7 + 0.5) + 1) / 2
                        readonly property real dx: Math.sin(index * 3.1 + tearStrips.displacement * 0.1) * tearStrips.displacement

                        Image {
                            source: parent.showNew ? cover.source : coverOld.source
                            width: tearStrips.width
                            height: tearStrips.height
                            x: parent.dx
                            y: -parent.y
                            fillMode: Image.PreserveAspectCrop
                        }
                    }
                }
            }
            ShaderEffectSource {
                id: tearSource
                sourceItem: tearStrips
                live: tearStrips.visible
                hideSource: true
            }
            ShaderEffect {
                id: tearShader
                anchors.fill: parent
                visible: tearStrips.visible
                property var source: tearSource
                property real iTime: 0
                fragmentShader: "../../shaders/glitch.frag.qsb"
            }

            // The targeting grid and the readout printed over the image
            Grid {
                anchors.centerIn: parent
                columns: 5
                rowSpacing: 30
                columnSpacing: 30
                Repeater {
                    model: 25
                    Rectangle {
                        width: 3
                        height: 2
                        color: CP.alpha(root.danger, 0.3)
                    }
                }
            }
            Column {
                x: 8
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                visible: !!root.player
                Repeater {
                    model: [
                        "IMAGE NAME: " + (root.player?.trackTitle ?? ""),
                        "IMAGE SOURCE: " + (root.player?.trackAlbum ?? ""),
                        "[STREAM CARRIER: " + (root.player?.identity ?? "") + "]"
                    ]
                    Text {
                        required property string modelData
                        width: 178
                        elide: Text.ElideRight
                        text: modelData.toUpperCase()
                        color: root.danger
                        style: Text.Raised
                        styleColor: CP.alpha("#000000", 0.7)
                        font { family: root.font; pixelSize: 8 }
                    }
                }
            }
        }
        CutShape {
            anchors.fill: parent
            cutBottomRight: 12
            strokeColor: CP.alpha(root.danger, 0.8)
            inset: 0.5
        }
        Text {
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready && !tearStrips.visible
            text: "NO SIGNAL"
            color: CP.alpha(root.danger, 0.6)
            font { family: root.font; pixelSize: 14 }
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: e => root.changeVolume((e.angleDelta.y / 120) * 0.04)
        }
    }

    // ---------- track ----------
    Item {
        x: 222
        y: 62
        width: root.width - x
        height: 204

        Text {
            text: root.player?.isPlaying ? "NOW PLAYING" : "PAUSED"
            color: CP.alpha(root.danger, 0.9)
            font { family: root.font; pixelSize: 10; letterSpacing: 1 }
        }
        Rectangle {
            y: 14
            width: parent.width
            height: 1
            color: CP.alpha(root.danger, 0.7)
        }
        Column {
            y: 22
            width: parent.width
            spacing: 2
            opacity: flicker.k

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: (root.player?.identity ?? "NO SOURCE").toUpperCase()
                color: root.danger
                font { family: root.font; pixelSize: 20; bold: true }
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: root.player
                    ? (root.player.trackArtist || "Unknown Artist") + " - " + (root.player.trackTitle || "Unknown Title")
                    : "NOT PLAYING ANY AUDIO"
                color: CP.lighten(CP.red, 0.25)
                font { family: root.font; pixelSize: 14 }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: root.player ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (root.player) focusProc.running = true
                }
            }
            Text {
                width: parent.width
                visible: text !== ""
                elide: Text.ElideRight
                text: root.player?.trackAlbum ?? ""
                color: CP.alpha(CP.lighten(CP.red, 0.25), 0.7)
                font { family: root.font; pixelSize: 11 }
            }
        }

        Text {
            y: 88
            height: 20
            verticalAlignment: Text.AlignVCenter
            text: "VOLUME"
            color: root.danger
            font { family: root.font; pixelSize: 15 }
        }
        Row {
            anchors.right: parent.right
            y: 88
            spacing: 10
            VolButton { label: "A"; step: -0.01 }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                horizontalAlignment: Text.AlignHCenter
                text: root.player?.volumeSupported ? Math.round(root.player.volume * 100) + "%" : "N/A"
                color: root.tech
                font { family: root.font; pixelSize: 15; bold: true }
            }
            VolButton { label: "D"; step: 0.01 }
        }

        // Seek
        Item {
            id: seekBar
            y: 116
            width: parent.width
            height: seekArea.containsMouse || seekArea.pressed ? 6 : 3
            visible: !!root.player

            Rectangle {
                anchors.fill: parent
                color: CP.alpha(root.tech, 0.22)
            }
            Rectangle {
                height: parent.height
                width: (seekArea.pressed ? seekArea.seekProgress : root.progress) * parent.width
                color: root.tech
            }
            MouseArea {
                id: seekArea
                anchors.fill: parent
                anchors.topMargin: -8
                anchors.bottomMargin: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                property real seekProgress: 0

                function seekTo(mx) {
                    const p = root.player
                    if (!p || !p.canSeek) return
                    seekProgress = Math.max(0, Math.min(1, mx / seekBar.width))
                    p.position = seekProgress * p.length
                }

                onPressed: e => seekTo(e.x)
                onPositionChanged: e => { if (pressed) seekTo(e.x) }
            }
        }
        Text {
            y: 123
            visible: !!root.player
            text: root.formatTime(root.player?.position ?? 0)
            color: root.tech
            font { family: root.font; pixelSize: 10 }
        }
        Text {
            anchors.right: parent.right
            y: 123
            visible: !!root.player
            text: root.formatTime(root.player?.length ?? 0)
            color: root.tech
            font { family: root.font; pixelSize: 10 }
        }

        // Closes the column level with the cover's bottom
        Rectangle {
            y: parent.height - 1
            width: parent.width
            height: 1
            color: CP.alpha(root.danger, 0.7)
        }

        // Transport
        Item {
            y: 142
            width: parent.width
            height: 56

            // Like (Spotify only)
            Item {
                id: likeBtn
                width: 32
                height: 32
                anchors.verticalCenter: parent.verticalCenter
                opacity: root._trackId ? 1 : 0.2
                visible: !!root.player && Players.isSpotifyActive
                transform: Translate { id: likeShift }

                Image {
                    id: likeIcon
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    sourceSize: Qt.size(24, 24)
                    fillMode: Image.PreserveAspectFit
                    source: {
                        if (root.isLiked && likeHover.hovered)
                            return "../../assets/SVG/heart-broken-svgrepo-com.svg"
                        if (root.isLiked || likeHover.hovered)
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
                    }
                }
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

            Row {
                anchors.centerIn: parent
                spacing: 44
                DashMediaTab.GlowButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "⏮"
                    size: 20
                    enabled: root.player?.canGoPrevious ?? false
                    onActivated: root.player?.previous()
                }
                DashMediaTab.GlowButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: (root.player?.isPlaying ?? false) ? "⏸" : "▶"
                    size: 30
                    enabled: root.player?.canTogglePlaying ?? false
                    onActivated: root.player?.togglePlaying()
                }
                DashMediaTab.GlowButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "⏭"
                    size: 20
                    enabled: root.player?.canGoNext ?? false
                    onActivated: root.player?.next()
                }
            }
        }
    }

    // ---------- stations ----------
    Rectangle {
        x: root.width - 4
        y: 280
        width: 3
        height: root.implicitHeight - 372
        color: root.danger
    }
    Column {
        id: sources
        x: 8
        y: 280
        spacing: 8

        Repeater {
            model: root.players

            Item {
                id: row
                required property var modelData
                readonly property bool isActive: modelData === root.player

                width: root.width - 24
                height: 34

                // Only the tuned station is framed
                CutShape {
                    anchors.fill: parent
                    visible: row.isActive
                    cutBottomRight: 10
                    fillColor: CP.alpha(root.tech, 0.16)
                    strokeColor: root.tech
                    strokeWidth: 1.5
                    inset: 0.75
                }
                // Equalizer bars while playing, the pause sign when tuned and stopped, else a data block
                Row {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    visible: row.modelData.isPlaying
                    Repeater {
                        model: [6, 13, 9, 14, 4]
                        Rectangle {
                            required property int modelData
                            anchors.bottom: parent.bottom
                            width: 2
                            height: modelData
                            color: root.tech
                        }
                    }
                }
                Text {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.isActive && !row.modelData.isPlaying
                    text: "\uf04c"
                    color: root.tech
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                }
                Column {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    visible: !row.isActive && !row.modelData.isPlaying
                    Repeater {
                        model: [16, 14, 16, 11]
                        Rectangle {
                            required property int modelData
                            width: modelData
                            height: 1
                            color: CP.alpha(root.tech, 0.5)
                        }
                    }
                }
                Text {
                    x: 40
                    width: row.width - 50
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: root.stationName(row.modelData)
                    color: root.tech
                    opacity: row.isActive ? 1 : 0.75
                    font { family: root.font; pixelSize: 16 }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchTo(row.modelData)
                }
            }
        }
    }

    // ---------- key hints ----------
    Rectangle {
        y: root.implicitHeight - 80
        width: root.width
        height: 1
        color: CP.alpha(root.danger, 0.6)
    }
    Text {
        y: root.implicitHeight - 68
        text: "cyberdeckNutz"
        color: CP.alpha(root.danger, 0.6)
        font { family: root.font; pixelSize: 10 }
    }
    Flow {
        x: 100
        y: root.implicitHeight - 70
        width: root.width - x
        spacing: 6
        layoutDirection: Qt.RightToLeft

        KeyCap { key: "ESC"; label: "CLOSE RADIOPORT" }
        KeyCap { key: "SPACE"; label: "PLAY/STOP" }
        KeyCap { key: "↓"; label: "NEXT SOURCE" }
        KeyCap { key: "↑"; label: "PREVIOUS SOURCE" }
        KeyCap { key: "→"; label: "NEXT TRACK" }
        KeyCap { key: "←"; label: "PREVIOUS TRACK" }
    }

    // ---------- inline components ----------
    component KeyCap: Row {
        property string key
        property string label
        spacing: 6
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(18, capText.implicitWidth + 8)
            height: 18
            color: "transparent"
            border.color: root.tech
            Text {
                id: capText
                anchors.centerIn: parent
                text: parent.parent.key
                color: root.tech
                font { family: root.font; pixelSize: 10; bold: true }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.label
            color: CP.alpha(root.danger, 0.9)
            font { family: root.font; pixelSize: 10; bold: true; letterSpacing: 1 }
        }
    }

    component VolButton: Item {
        id: btn
        property string label
        property real step: 0.01
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        height: 22
        Rectangle {
            anchors.fill: parent
            color: hit.pressed ? CP.alpha(root.tech, 0.3) : "transparent"
            border.color: root.tech
        }
        Text {
            anchors.centerIn: parent
            text: btn.label
            color: root.tech
            font { family: root.font; pixelSize: 13 }
        }
        MouseArea {
            id: hit
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.changeVolume(btn.step)
        }
    }

    // ---------- player switch: tear ----------
    SequentialAnimation {
        id: tear
        ScriptAction {
            script: {
                tearStrips.progress = 0
                tearStrips.displacement = 0
                tearStrips.visible = true
                cover.visible = false
            }
        }
        ParallelAnimation {
            NumberAnimation { target: tearStrips; property: "progress"; from: 0; to: 1; duration: 500 }
            SequentialAnimation {
                NumberAnimation { target: tearStrips; property: "displacement"; from: 0; to: 40; duration: 250; easing.type: Easing.InCubic }
                NumberAnimation { target: tearStrips; property: "displacement"; from: 40; to: 0; duration: 250; easing.type: Easing.OutCubic }
            }
            SequentialAnimation {
                NumberAnimation { target: tearShader; property: "iTime"; from: 0; to: 8; duration: 250; easing.type: Easing.InCubic }
                NumberAnimation { target: tearShader; property: "iTime"; from: 8; to: 0; duration: 250; easing.type: Easing.OutCubic }
            }
        }
        ScriptAction {
            script: {
                tearShader.iTime = 0
                tearStrips.visible = false
                cover.visible = true
            }
        }
    }

    // ---------- track change: stepped flicker ----------
    readonly property string trackInfoId: (player?.trackTitle ?? "") + "|" + (player?.trackArtist ?? "")
    onTrackInfoIdChanged: if (player && trackInfoId !== "|" && active) flickerAnim.restart()

    QtObject { id: flicker; property real k: 1 }
    SequentialAnimation {
        id: flickerAnim
        PropertyAction { target: flicker; property: "k"; value: 0 }
        PauseAnimation { duration: 25 }
        PropertyAction { target: flicker; property: "k"; value: 1 }
        PauseAnimation { duration: 30 }
        PropertyAction { target: flicker; property: "k"; value: 0 }
        PauseAnimation { duration: 35 }
        PropertyAction { target: flicker; property: "k"; value: 0.6 }
        PauseAnimation { duration: 20 }
        PropertyAction { target: flicker; property: "k"; value: 0 }
        PauseAnimation { duration: 15 }
        PropertyAction { target: flicker; property: "k"; value: 1 }
    }

    // ---------- periodic glitch on the header ----------
    QtObject { id: tagGlitch; property color tint: "transparent" }
    SequentialAnimation {
        running: root.active
        loops: Animation.Infinite
        onStopped: { tagGlitch.tint = "transparent"; header.titleShift.x = 0 }

        PauseAnimation { duration: 1600 }
        PropertyAction { target: tagGlitch; property: "tint"; value: CP.magenta }
        PropertyAction { target: header.titleShift; property: "x"; value: 3 }
        PauseAnimation { duration: 55 }
        PropertyAction { target: tagGlitch; property: "tint"; value: CP.yellow }
        PropertyAction { target: header.titleShift; property: "x"; value: -3 }
        PauseAnimation { duration: 55 }
        PropertyAction { target: tagGlitch; property: "tint"; value: CP.cyan }
        PropertyAction { target: header.titleShift; property: "x"; value: 2 }
        PauseAnimation { duration: 55 }
        PropertyAction { target: tagGlitch; property: "tint"; value: "transparent" }
        PropertyAction { target: header.titleShift; property: "x"; value: 0 }
        PauseAnimation { duration: 530 }
    }
}
