// DashMediaTab.qml — RADIOPORT. Layout ported from AndreaNec/Cyberpunk-quickshell
// (mediaplayer/MediaPanel.qml), on the CP palette. On top of the original:
// active-player badge (click = focus its window), album line, like (Spotify),
// prev/play/next with glow + glitch, seek bar with times, wheel volume on the
// cover, tear transition when switching player, flicker on track change.
// Also hosted standalone by modules/media/MediaPanel.qml (menu → Media).
//
// Keys (once the tab has focus): A / D volume -/+1%, Enter play/pause.

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "../../common/Colors.js" as CP
import "../../common"

FocusScope {
    id: root
    implicitWidth: col.width + 24
    implicitHeight: col.implicitHeight + 24

    readonly property int    shapeHeight: 35
    readonly property color  accent1: CP.cyan
    readonly property color  accent2: CP.alpha(CP.red, 0.5)
    readonly property real   h1: 14
    readonly property real   h2: 10

    readonly property MprisPlayer activePlayer: Players.active
    readonly property real playerProgress: {
        const p = activePlayer
        return (p && p.length > 0) ? p.position / p.length : 0
    }
    property bool isLiked: Players.isLiked

    readonly property string _trackId: {
        const url = String(root.activePlayer?.metadata?.["xesam:url"] ?? "")
        if (url.startsWith("spotify:track:")) return url.split(":")[2]
        const m = url.match(/\/track\/([A-Za-z0-9]+)/)
        return m ? m[1] : ""
    }

    // ---------- volume (MPRIS player volume, as in the original) ----------
    function volume(p) { return p && p.volumeSupported ? p.volume : null }
    function changeVolume(p, delta) {
        const v = volume(p)
        if (v !== null && p.canControl) p.volume = Math.max(0, Math.min(1, v + delta))
    }

    // Row click: the active one toggles, another one takes over (old paused,
    // new played) behind the tear transition.
    function switchTo(p) {
        if (!p) return
        if (p === root.activePlayer) { p.togglePlaying(); return }
        const old = root.activePlayer
        coverImgOld.source = coverImg.source
        Players.select(p)
        if (old?.isPlaying && old.canPause) old.pause()
        if (p.canPlay) p.play()
        switchGlitchAnim.restart()
    }

    onVisibleChanged: if (visible) forceActiveFocus()
    Keys.onPressed: e => {
        if (e.key === Qt.Key_A) {
            root.changeVolume(root.activePlayer, -0.01)
            e.accepted = true
        } else if (e.key === Qt.Key_D) {
            root.changeVolume(root.activePlayer, 0.01)
            e.accepted = true
        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            root.activePlayer?.togglePlaying()
            e.accepted = true
        }
    }

    // MPRIS doesn't push position: poke it while playing and on screen
    Timer {
        running: root.visible && (root.activePlayer?.isPlaying ?? false)
        interval: 500
        repeat: true
        triggeredOnStart: true
        onTriggered: root.activePlayer?.positionChanged()
    }

    Process { id: likeProc }

    Process {
        id: focusProc
        command: ["hyprctl", "dispatch", "focuswindow",
                "class:" + (root.activePlayer?.desktopEntry ?? "")]
        running: false
    }

    ColumnLayout {
        id: col
        x: 12; y: 12
        width: 460
        spacing: 12

        Text {
            Layout.fillWidth: true
            text: "Tkla:__;v.0.02"
            color: root.accent2
            font.family: "Oxanium"
            font.pixelSize: root.h2
        }

        // ---------- RADIOPORT tag ----------
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.shapeHeight
            CutShape {
                anchors.fill: parent
                cutBottomLeft: 6; cutBottomRight: 6
                strokeWidth: 2; inset: 1
                strokeColor: tagGlitch.tint.a > 0 ? tagGlitch.tint : root.accent2
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 12
                text: "RADIOPORT"
                color: root.accent1
                font.family: "Oxanium"
                font.pixelSize: root.h1
                transform: Translate { id: tagShift }
            }
            // Active player badge: click brings its window forward
            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 12
                visible: !!root.activePlayer
                text: Players.isSpotifyActive ? "" : ""
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 18
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

        // ---------- album cover and info ----------
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 200
            spacing: 12

            Item {
                Layout.fillHeight: true
                Layout.preferredWidth: 200 // square

                CutShape {
                    anchors.fill: parent
                    cutBottomLeft: 6; cutBottomRight: 6
                    strokeWidth: 2; inset: 1
                    strokeColor: root.accent2
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: 4
                    clip: true

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
                        sourceSize: Qt.size(width * 2, height * 2)
                    }

                    // Screen tear: strips flip from the old cover to the new one
                    Item {
                        id: tearTransition
                        anchors.fill: parent
                        visible: false
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

                                readonly property bool showNew:
                                    tearTransition.progress > (Math.sin(index * 4.7 + 0.5) + 1) / 2
                                readonly property real dx:
                                    Math.sin(index * 3.1 + tearTransition.displacement * 0.1) * tearTransition.displacement

                                Image {
                                    source: parent.showNew ? coverImg.source : coverImgOld.source
                                    width: tearTransition.width
                                    height: tearTransition.height
                                    x: parent.dx
                                    y: -parent.y
                                    fillMode: Image.PreserveAspectCrop
                                }
                            }
                        }
                    }
                    ShaderEffectSource {
                        id: tearSource
                        sourceItem: tearTransition
                        live: tearTransition.visible
                        hideSource: true
                    }
                    ShaderEffect {
                        id: tearShader
                        anchors.fill: parent
                        visible: tearTransition.visible
                        property var source: tearSource
                        property real iTime: 0
                        fragmentShader: "../../shaders/glitch.frag.qsb"
                    }
                }

                Text { // placeholder when there is no art
                    anchors.centerIn: parent
                    visible: coverImg.status !== Image.Ready && !tearTransition.visible
                    text: "NO SIGNAL"
                    color: root.accent2
                    font.family: "Oxanium"
                    font.pixelSize: root.h1
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: event => root.changeVolume(root.activePlayer, (event.angleDelta.y / 120) * 0.04)
                }
            }

            ColumnLayout { // name and volume
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                spacing: 8

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

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true // pushes the volume row to the bottom
                    spacing: 4
                    opacity: infoFlicker.k

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
                        maximumLineCount: 4
                        elide: Text.ElideRight
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: root.activePlayer ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: if (root.activePlayer) focusProc.running = true
                        }
                    }
                    Text { // album
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: root.activePlayer?.trackAlbum ?? ""
                        color: Colours.textSecondary
                        font.family: "Oxanium"
                        font.pixelSize: root.h2 + 1
                        elide: Text.ElideRight
                    }
                    Item { Layout.fillHeight: true }
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

                    VolButton { label: "A"; step: -0.01 }
                    Text {
                        Layout.preferredWidth: 40 // fixed width so the buttons don't jitter
                        horizontalAlignment: Text.AlignHCenter
                        text: volRow.raw !== null && volRow.raw !== undefined ? Math.round(volRow.raw * 100) + "%" : "N/A"
                        color: root.accent1
                        font.family: "Oxanium"
                        font.pixelSize: root.h1
                    }
                    VolButton { label: "D"; step: 0.01 }
                }

                Rectangle { // separator
                    Layout.fillWidth: true
                    Layout.preferredHeight: 2
                    color: root.accent2
                }
            }
        }

        // ---------- transport ----------
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 44

            // Like (Spotify only)
            Item {
                id: likeBtn
                width: 32; height: 32
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                opacity: root._trackId ? 1 : 0.2
                visible: !!root.activePlayer && Players.isSpotifyActive

                Image {
                    id: likeIcon
                    anchors.centerIn: parent
                    width: 24; height: 24
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

            RowLayout {
                anchors.centerIn: parent
                spacing: 54

                GlowButton {
                    icon: "⏮"
                    size: 28
                    enabled: root.activePlayer?.canGoPrevious ?? false
                    onActivated: root.activePlayer?.previous()
                }
                GlowButton {
                    icon: (root.activePlayer?.isPlaying ?? false) ? "⏸" : "▶"
                    size: 40
                    enabled: root.activePlayer?.canTogglePlaying ?? false
                    onActivated: root.activePlayer?.togglePlaying()
                }
                GlowButton {
                    icon: "⏭"
                    size: 28
                    enabled: root.activePlayer?.canGoNext ?? false
                    onActivated: root.activePlayer?.next()
                }
            }
        }

        // ---------- seek ----------
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: !!root.activePlayer

            Text {
                text: root.formatTime(root.activePlayer?.position ?? 0)
                font.family: "Oxanium"; font.pixelSize: root.h2
                color: Colours.textSecondary
            }
            Item {
                id: progressBar
                Layout.fillWidth: true
                implicitHeight: seekArea.containsMouse || seekArea.pressed ? 8 : 4

                Rectangle { anchors.fill: parent; color: CP.alpha(root.accent1, 0.18) }
                Rectangle {
                    anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                    width: (seekArea.pressed ? seekArea._seekProgress : root.playerProgress) * parent.width
                    color: root.accent1
                }

                MouseArea {
                    id: seekArea
                    anchors.fill: parent
                    anchors.topMargin: -8   // wider touch area
                    anchors.bottomMargin: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true

                    property real _seekProgress: 0

                    function _seekTo(mx) {
                        const p = root.activePlayer
                        if (!p || !p.canSeek) return
                        _seekProgress = Math.max(0, Math.min(1, mx / progressBar.width))
                        p.position = _seekProgress * p.length
                    }

                    onPressed: mouse => _seekTo(mouse.x)
                    onPositionChanged: mouse => { if (pressed) _seekTo(mouse.x) }
                }
            }
            Text {
                text: root.formatTime(root.activePlayer?.length ?? 0)
                font.family: "Oxanium"; font.pixelSize: root.h2
                color: Colours.textSecondary
            }
        }

        // ---------- players ----------
        ListView {
            id: mediaList
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(1, count) * root.shapeHeight
            interactive: false
            clip: true

            model: Mpris.players

            delegate: Item {
                id: playerItem
                required property var modelData // MprisPlayer
                readonly property bool isActive: modelData === root.activePlayer

                width: mediaList.width
                height: root.shapeHeight
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
                    anchors.leftMargin: 12
                    // fallback to identity if no track is playing
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

    // ---------- inline components ----------
    component VolButton: Item {
        id: btn
        property string label
        property real step: 0.01

        implicitWidth: 20
        implicitHeight: 20

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
            font.pixelSize: root.h1
        }
        MouseArea {
            id: hit
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.changeVolume(root.activePlayer, btn.step)
        }
    }

    // Transport glyph: stacked yellow glow on hover + stepped glitch
    component GlowButton: Item {
        id: gb
        property string icon
        property real size: 28
        signal activated()

        implicitWidth: size; implicitHeight: size
        opacity: enabled ? 1 : 0.35

        property real glowOp: 0.0

        SequentialAnimation {
            running: gbArea.containsMouse
            loops: Animation.Infinite
            onStopped: gb.glowOp = 0
            NumberAnimation { target: gb; property: "glowOp"; to: 1.0; duration: 40 }
            PauseAnimation { duration: 620 }
            NumberAnimation { target: gb; property: "glowOp"; to: 0.15; duration: 25 }
            PauseAnimation { duration: 50 }
            NumberAnimation { target: gb; property: "glowOp"; to: 1.0; duration: 35 }
            PauseAnimation { duration: 360 }
            NumberAnimation { target: gb; property: "glowOp"; to: 0.0; duration: 20 }
            PauseAnimation { duration: 40 }
            NumberAnimation { target: gb; property: "glowOp"; to: 0.8; duration: 20 }
            PauseAnimation { duration: 30 }
            NumberAnimation { target: gb; property: "glowOp"; to: 0.0; duration: 20 }
            PauseAnimation { duration: 65 }
            NumberAnimation { target: gb; property: "glowOp"; to: 1.0; duration: 80; easing.type: Easing.OutQuad }
            PauseAnimation { duration: 510 }
        }

        Text { anchors.centerIn: parent; text: gb.icon; font.pixelSize: gb.size * 2.0;  font.family: "JetBrains Mono"; color: CP.alpha(CP.yellow, 0.06 * gb.glowOp) }
        Text { anchors.centerIn: parent; text: gb.icon; font.pixelSize: gb.size * 1.67; font.family: "JetBrains Mono"; color: CP.alpha(CP.yellow, 0.12 * gb.glowOp) }
        Text { anchors.centerIn: parent; text: gb.icon; font.pixelSize: gb.size * 1.39; font.family: "JetBrains Mono"; color: CP.alpha(CP.yellow, 0.25 * gb.glowOp) }
        Text { anchors.centerIn: parent; text: gb.icon; font.pixelSize: gb.size * 1.17; font.family: "JetBrains Mono"; color: CP.alpha(CP.yellow, 0.45 * gb.glowOp) }
        Text { anchors.centerIn: parent; text: gb.icon; font.pixelSize: gb.size;        font.family: "JetBrains Mono"; color: Qt.rgba(1, 1, 0.4, 0.70 * gb.glowOp) }
        Text {
            id: gbLabel
            anchors.centerIn: parent
            text: gb.icon
            font.pixelSize: gb.size
            font.family: "JetBrains Mono"
            color: CP.yellow
            transform: Translate { id: gbShift; x: 0 }
        }
        MouseArea {
            id: gbArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: gb.activated()
        }
        GlitchAnim {
            id: gbGlitch
            labelTarget: gbLabel
            shiftTarget: gbShift
            baseColor: CP.yellow
            onFinished: if (gbHover.hovered) gbPause.start()
        }
        Timer {
            id: gbPause
            interval: 600
            onTriggered: if (gbHover.hovered) gbGlitch.restart()
        }
        HoverHandler {
            id: gbHover
            onHoveredChanged: {
                if (hovered) gbGlitch.restart()
                else { gbGlitch.reset(); gbPause.stop() }
            }
        }
    }

    // ---------- player switch: tear ----------
    SequentialAnimation {
        id: switchGlitchAnim

        ScriptAction {
            script: {
                tearTransition.progress = 0
                tearTransition.displacement = 0
                tearTransition.visible = true
                coverImg.visible = false
            }
        }
        ParallelAnimation {
            NumberAnimation { target: tearTransition; property: "progress"; from: 0; to: 1; duration: 500 }
            SequentialAnimation {
                NumberAnimation { target: tearTransition; property: "displacement"; from: 0; to: 40; duration: 250; easing.type: Easing.InCubic }
                NumberAnimation { target: tearTransition; property: "displacement"; from: 40; to: 0; duration: 250; easing.type: Easing.OutCubic }
            }
            SequentialAnimation {
                NumberAnimation { target: tearShader; property: "iTime"; from: 0; to: 8; duration: 250; easing.type: Easing.InCubic }
                NumberAnimation { target: tearShader; property: "iTime"; from: 8; to: 0; duration: 250; easing.type: Easing.OutCubic }
            }
        }
        ScriptAction {
            script: {
                tearShader.iTime = 0
                tearTransition.visible = false
                coverImg.visible = true
            }
        }
    }

    // ---------- track change: stepped flicker of the now-playing text ----------
    readonly property string trackInfoId:
        (activePlayer?.trackTitle ?? "") + "|" + (activePlayer?.trackArtist ?? "")
    onTrackInfoIdChanged: if (activePlayer && trackInfoId !== "|") infoFlickerAnim.restart()

    QtObject { id: infoFlicker; property real k: 1 }
    SequentialAnimation {
        id: infoFlickerAnim
        PropertyAction { target: infoFlicker; property: "k"; value: 0.8 }
        PauseAnimation { duration: 18 }
        PropertyAction { target: infoFlicker; property: "k"; value: 0 }
        PauseAnimation { duration: 25 }
        PropertyAction { target: infoFlicker; property: "k"; value: 1.0 }
        PauseAnimation { duration: 30 }
        PropertyAction { target: infoFlicker; property: "k"; value: 0 }
        PauseAnimation { duration: 12 }
        PropertyAction { target: infoFlicker; property: "k"; value: 0.6 }
        PauseAnimation { duration: 20 }
        PropertyAction { target: infoFlicker; property: "k"; value: 0 }
        PauseAnimation { duration: 35 }
        PropertyAction { target: infoFlicker; property: "k"; value: 1.0 }
        PauseAnimation { duration: 22 }
        PropertyAction { target: infoFlicker; property: "k"; value: 0.4 }
        PauseAnimation { duration: 15 }
        PropertyAction { target: infoFlicker; property: "k"; value: 0 }
        PauseAnimation { duration: 8 }
        PropertyAction { target: infoFlicker; property: "k"; value: 1.0 }
    }

    // ---------- periodic glitch on the RADIOPORT tag (only while on screen) ----------
    QtObject { id: tagGlitch; property color tint: "transparent" }
    SequentialAnimation {
        running: root.visible
        loops: Animation.Infinite
        onStopped: { tagGlitch.tint = "transparent"; tagShift.x = 0 }

        PropertyAction { target: tagGlitch; property: "tint"; value: "transparent" }
        PropertyAction { target: tagShift; property: "x"; value: 0 }
        PauseAnimation { duration: 1600 }

        PropertyAction { target: tagGlitch; property: "tint"; value: CP.magenta }
        PropertyAction { target: tagShift; property: "x"; value: 3 }
        PauseAnimation { duration: 55 }
        PropertyAction { target: tagGlitch; property: "tint"; value: CP.yellow }
        PropertyAction { target: tagShift; property: "x"; value: -3 }
        PauseAnimation { duration: 55 }
        PropertyAction { target: tagGlitch; property: "tint"; value: CP.cyan }
        PropertyAction { target: tagShift; property: "x"; value: 2 }
        PauseAnimation { duration: 55 }
        PropertyAction { target: tagGlitch; property: "tint"; value: "transparent" }
        PropertyAction { target: tagShift; property: "x"; value: 0 }
        PauseAnimation { duration: 130 }

        PropertyAction { target: tagGlitch; property: "tint"; value: CP.magenta }
        PropertyAction { target: tagShift; property: "x"; value: -2 }
        PauseAnimation { duration: 35 }
        PropertyAction { target: tagGlitch; property: "tint"; value: "transparent" }
        PropertyAction { target: tagShift; property: "x"; value: 0 }
        PauseAnimation { duration: 400 }
    }

    function formatTime(secs) {
        if (!secs || secs < 0) return "-:--"
        const m = Math.floor(secs / 60)
        const s = Math.floor(secs % 60).toString().padStart(2, "0")
        return `${m}:${s}`
    }
}
