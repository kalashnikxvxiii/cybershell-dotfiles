import "../../common/Colors.js" as CP
import "../../common/effects"
import "../../common"
import QtQuick
import QtQuick.Effects
import Qt.labs.folderlistmodel
import CyberWallpaper

Item {
    id: root

    FolderListModel {
        id: samples
        folder: "file:///home/kalashnikxv/Pictures/wallpapers"
        nameFilters: ["*.jpg", "*.jpeg", "*.png"]
        showDirs: false
        sortField: FolderListModel.Name
    }

    property string sample1: ""
    property string sample2: ""

    Connections {
        target: samples
        function onCountChanged() {
            if (samples.count > 0) root.sample1 = samples.get(0, "filePath")
            if (samples.count > 1) root.sample2 = samples.get(1, "filePath")
            else root.sample2 = root.sample1
        }
    }

    property string _currentSource: _showFirst ? sample1 : sample2
    property bool   _showFirst:     true
    property bool   _paused:        false

    function shuffleSamples() {
        if (samples.count < 2) return
        var i1 = Math.floor(Math.random() * samples.count)
        var i2 = Math.floor(Math.random() * samples.count)
        while (i2 === i1) i2 = Math.floor(Math.random() * samples.count)
        sample1 = samples.get(i1, "filePath")
        sample2 = samples.get(i2, "filePath")
        _showFirst = true
        cycleTimer.restart()
    }

    Connections {
        target: TransitionConfig
        function onPreviewReplayRequested() {
            if (root.sample1 !== "" && root.sample2 !== "") {
                root._showFirst = !root._showFirst
                cycleTimer.restart()
            }
        }
    }

    Timer {
        id: cycleTimer
        interval: Math.max(2000, (TransitionConfig.transitionDuration * 1000) + 1500)
        running: root.visible && root.sample1 !== "" && root.sample2 !== "" && root.sample1 !== root.sample2 && !root._paused
        repeat: true
        onTriggered: root._showFirst = !root._showFirst
    }

    Column {
        anchors.fill: parent
        spacing: 10

        // Header
        Row {
            spacing: 6
            Text { text: "▸"; color: Colours.accentOk; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "PREVIEW"; font.family: "Oxanium"; font.pixelSize: 11; font.letterSpacing: 3; font.bold: true; color: Colours.accentOk; anchors.verticalCenter: parent.verticalCenter }
        }

        // Wallpaper preview (16:9, full width)
        Item {
            id: previewWrap
            width: parent.width
            height: width * 9 / 16

            CutShape {
                id: previewMask
                anchors.fill: parent
                fillColor: "white"
                cutTopLeft: 12
                cutBottomRight: 12
                visible: false
                layer.enabled: true
            }

            CutShape {
                anchors.fill: parent
                fillColor: CP.alpha(CP.void2, 0.7)
                strokeColor: CP.alpha(CP.neon, 0.55)
                strokeWidth: 1
                inset: 0.5
                cutTopLeft: 12
                cutBottomRight: 12
            }

            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: previewMask
                    maskThresholdMin: 0.5
                }

                WallpaperLayer {
                    anchors.fill: parent
                    anchors.margins: 2
                    source: root._currentSource
                    backdropBlur: true
                    backdropDarken: 0.15
                    backdropSaturation: -0.2
                    blurRadius: 30

                    transitionType:     TransitionConfig.transitionType
                    transitionDuration: TransitionConfig.transitionDuration
                    transitionFps:      TransitionConfig.transitionFps
                    transitionStep:     TransitionConfig.transitionStep
                    transitionAngle:    TransitionConfig.transitionAngle
                    transitionPos:      TransitionConfig.transitionPos
                    transitionBezier:   TransitionConfig.transitionBezier
                    transitionWave:     TransitionConfig.transitionWave
                    invertY:            TransitionConfig.invertY
                }

                // VHS effects bundle - scanlines + random micro-glitches
                Item {
                    id: vhsLayer
                    anchors.fill: parent
                    anchors.margins: 2
                    clip: true

                    // ── 1. Slowly scrolling scanlines (always visible) ────
                    Canvas {
                        id: scanCanvas
                        anchors.fill: parent
                        opacity: 0.11
                        readonly property int spacing: 3
                        property real offset: 0

                        onOffsetChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.strokeStyle = "#000000"
                            ctx.lineWidth = 1
                            var s = spacing
                            var startY = -s + (offset % s)
                            for (var y = startY; y < height + s; y += s) {
                                ctx.beginPath()
                                ctx.moveTo(0, y + 0.5)
                                ctx.lineTo(width, y + 0.5)
                                ctx.stroke()
                            }
                        }
                        NumberAnimation on offset {
                            from: 0
                            to: scanCanvas.spacing          // == spacing -> seamless loop
                            duration: 2400                  // slow, ~2.4s per cycle
                            loops: Animation.Infinite
                            running: scanCanvas.visible
                        }
                    }

                    // ── 2. Tracking flash (occasional bright horizontal line) ────
                    Rectangle {
                        id: trackBurst
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        y: 0
                        opacity: 0
                        color: "white"
                    }
                    SequentialAnimation {
                        id: trackBurstAnim
                        NumberAnimation { target: trackBurst; property: "opacity"; from: 0; to: 0.55; duration: 25 }
                        NumberAnimation { target: trackBurst; property: "opacity"; from: 0.55; to: 0; duration: 80 }
                    }
                    Timer {
                        id: trackBurstTimer
                        interval: 3500
                        running: vhsLayer.visible
                        repeat: true
                        onTriggered: {
                            trackBurst.y = Math.floor(Math.random() * (vhsLayer.height - 4)) + 2
                            trackBurst.height = 1 + Math.floor(Math.random() * 2)
                            trackBurstAnim.restart()
                            interval = 2200 + Math.floor(Math.random() * 4800)      // 2.2s - 7s
                        }
                    }

                    // ── 3. Chromatic color-bleed band ─────────────────────────────
                    Rectangle {
                        id: glitchBand
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 6
                        y: 0
                        opacity: 0
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.25; color: CP.alpha(CP.magenta, 0.35) }
                            GradientStop { position: 0.5; color: CP.alpha(CP.magenta, 0.55) }
                            GradientStop { position: 0.51; color: CP.alpha(CP.cyan, 0.55) }
                            GradientStop { position: 0.75; color: CP.alpha(CP.cyan, 0.35) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }
                    SequentialAnimation {
                        id: glitchAnim
                        NumberAnimation { target: glitchBand; property: "opacity"; from: 0; to: 1; duration: 20 }
                        PauseAnimation { duration: 50 }
                        NumberAnimation { target: glitchBand; property: "opacity"; from: 1; to: 0; duration: 35 }
                    }
                    Timer {
                        id: glitchTimer
                        interval: 4500
                        running: vhsLayer.visible
                        repeat: true
                        onTriggered: {
                            glitchBand.height = 4 + Math.floor(Math.random() * 10)      // 4-14px
                            glitchBand.y = Math.floor(Math.random() * (vhsLayer.height - glitchBand.height - 4)) + 2
                            glitchAnim.restart()
                            interval = 3000 + Math.floor(Math.random() * 6000)          // 3s - 9s
                        }
                    }

                    // ── 4. Subtle continuous overlay tint (vignetting effect) ─────────────
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0.0; color: CP.alpha("black", 0.08) }
                            GradientStop { position: 0.15; color: "transparent" }
                            GradientStop { position: 0.85; color: "transparent" }
                            GradientStop { position: 1.0; color: CP.alpha("black", 0.10) }
                        }
                    }
                }
            }

            // LIVE badge
            Row {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 5
                spacing: 4
                Rectangle {
                    width: 6; height: 6
                    color: CP.neon
                    anchors.verticalCenter: parent.verticalCenter
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: cycleTimer.running
                        NumberAnimation { from: 1; to: 0.3; duration: 600 }
                        NumberAnimation { from: 0.3; to: 1; duration: 600 }
                    }
                }
                Text {
                    text: "LIVE"
                    font.family: "Oxanium"
                    font.pixelSize: 7
                    font.letterSpacing: 1.5
                    font.bold: true
                    color: Colours.accentOk
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Empty state
            Text {
                anchors.centerIn: parent
                visible: root.sample1 === ""
                text: "NO\nSAMPLES"
                horizontalAlignment: Text.AlignHCenter
                font.family: "Oxanium"
                font.pixelSize: 9
                font.letterSpacing: 1.5
                color: Colours.textMuted
            }
        }

        // Info
        Column {
            width: parent.width
            spacing: 4

            Text {
                text: root._paused
                    ? "⏸ PAUSED"
                    : "Auto-cycle " + ((TransitionConfig.transitionDuration + 1.5).toFixed(1)) + "s"
                font.family: "Oxanium"
                font.pixelSize: 8
                font.letterSpacing: 1
                color: root._paused ? Colours.accentWarn : Colours.textMuted
            }
            Row {
                spacing: 4
                Text { text: "FRAME"; font.family: "Oxanium"; font.pixelSize: 7; font.letterSpacing: 1.5; color: Colours.textMuted; anchors.verticalCenter: parent.verticalCenter }
                Text { text: root._showFirst ? "1/2" : "2/2"; font.family: "Oxanium"; font.pixelSize: 8; font.letterSpacing: 1; color: Colours.accentOk; anchors.verticalCenter: parent.verticalCenter }
            }
            Text {
                width: parent.width
                text: {
                    var p = root._currentSource
                    if (p === "") return ""
                    return p.split("/").pop()
                }
                elide: Text.ElideMiddle
                font.family: "Oxanium"
                font.pixelSize: 7
                font.letterSpacing: 0.5
                color: CP.alpha(CP.neon, 0.5)
            }
        }

        // Replay button
        Row {
            width: parent.width
            spacing: 6

            // REPLAY
            Item {
                width: (parent.width - parent.spacing * 2) / 3
                height: 28

                CutShape {
                    anchors.fill: parent
                    fillColor: replayMa.containsMouse
                        ? CP.alpha(CP.neon, 0.25)
                        : CP.alpha(CP.neon, 0.10)
                    strokeColor: CP.alpha(CP.neon, 0.6)
                    strokeWidth: 1
                    inset: 0.5
                    cutTopLeft: 3
                    cutBottomRight: 3
                    Behavior on fillColor { ColorAnimation { duration: 120 } }
                }
                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "↻"; font.pixelSize: 11; color: Colours.accentOk; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: "REPLAY"
                        font.family: "Oxanium"
                        font.pixelSize: 8
                        font.letterSpacing: 1.2
                        font.bold: true
                        color: Colours.accentOk
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    id: replayMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.sample1 !== "" && root.sample2 !== "") {
                            root._showFirst = !root._showFirst
                            cycleTimer.restart()
                        }
                    }
                }
            }

            // PAUSE / PLAY toggle
            Item {
                width: (parent.width - parent.spacing * 2) / 3
                height: 28

                CutShape {
                    anchors.fill: parent
                    fillColor: pauseMa.containsMouse
                            ? CP.alpha(root._paused ? CP.amber : CP.cyan, 0.25)
                            : CP.alpha(root._paused ? CP.amber : CP.cyan, 0.10)
                            strokeColor: CP.alpha(root._paused ? CP.amber : CP.cyan, 0.6)
                            strokeWidth: 1; inset: 0.5; cutTopLeft: 3; cutBottomRight: 3
                            Behavior on fillColor { ColorAnimation { duration: 120 } }
                            Behavior on strokeColor { ColorAnimation { duration: 120 } }
                }
                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: root._paused ? "▶" : "⏸"
                        font.pixelSize: 11
                        color: root._paused ? Colours.accentWarn : Colours.accentSecondary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    id: pauseMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root._paused = !root._paused
                }
            }

            // SHUFFLE
            Item {
                width: (parent.width - parent.spacing * 2) / 3
                height: 28

                CutShape {
                    anchors.fill: parent
                    fillColor: shuffleMa.containsMouse
                            ? CP.alpha(CP.magenta, 0.25)
                            : CP.alpha(CP.magenta, 0.10)
                    strokeColor: CP.alpha(CP.magenta, 0.6)
                    strokeWidth: 1; inset: 0.5; cutTopLeft: 3; cutBottomRight: 3
                    Behavior on fillColor { ColorAnimation { duration: 120 } }
                }
                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    Text { text: "⤨"; font.pixelSize: 11; color: Colours.accentMem; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "SHUFFLE"; font.family: "Oxanium"; font.pixelSize: 8; font.letterSpacing: 1.2; font.bold: true; color: Colours.accentMem; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea {
                    id: shuffleMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.shuffleSamples()
                }
            }
        }
    }
}
