// WorkspacePreview.qml — miniatura del workspace sotto il cursore.
// Ogni finestra e' collocata secondo la geometria reale riportata da Hyprland
// e riempita con uno ScreencopyView live, con l'icona della classe sovrapposta
// per identificarla anche quando la cattura e' scura o vuota.
//
// Struttura e geometria sono tenute separate di proposito: `wins` e' il model
// del Repeater e cambia solo quando una finestra appare, sparisce o cambia
// workspace; `geom` porta le coordinate ed e' riassegnata a ogni sondaggio.
// Se le coordinate stessero dentro `wins`, ogni aggiornamento ricostruirebbe i
// delegate e farebbe ripartire da zero tutte le catture.
import "../../common/Colors.js" as CP
import "../../common"
import "../../common/effects"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
    id: root

    property var workspace: null
    property bool active: true
    readonly property var monitor: workspace ? workspace.monitor : null

    property int previewWidth: 420

    readonly property real srcW: monitor && monitor.width  > 0 ? monitor.width  : 1920
    readonly property real srcH: monitor && monitor.height > 0 ? monitor.height : 1080

    readonly property int pad: 4
    readonly property real stageW: previewWidth - pad * 2
    readonly property real k: stageW / srcW

    property real scrollX: 0

    // Model del Repeater: solo cio' che identifica la finestra, mai le coordinate
    property var wins: []
    // Coordinate correnti, indicizzate per address
    property var geom: ({})

    readonly property var _bounds: {
        var mn = 0, mx = srcW
        var ox = monitor ? monitor.x : 0
        for (var i = 0; i < wins.length; i++) {
            var g = geom[wins[i].address]
            if (!g) continue
            var l = g.wx - ox
            var r = l + g.ww
            if (l < mn) mn = l
            if (r > mx) mx = r
        }
        return { min: mn, max: mx }
    }

    readonly property real minScroll: _bounds.min * k
    readonly property real maxScroll: Math.max(0, _bounds.max * k - stageW)

    implicitWidth:  previewWidth
    implicitHeight: pad + wsLabel.implicitHeight + pad + Math.round(srcH * k) + pad

    function _sameStructure(a, b) {
        if (a.length !== b.length) return false
        for (var i = 0; i < a.length; i++)
            if (a[i].address !== b[i].address) return false
        return true
    }

    // Map pid -> ppid. It's needed because the audio stream spawn often by a
    // children process of the window: Discord opens the window with pid 3498
    // but the WebRTC stream comes from 3973
    property var ppid: ({})

    property var _psProc: Process {
        id: psProc
        command: ["ps", "-eo", "pid=,ppid="]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var m = ({})
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].trim().split(" ")
                    var v = []
                    for (var j = 0; j < parts.length; j++)
                        if (parts[j].length > 0) v.push(parts[j])
                    if (v.length >= 2) m[v[0]] = v[1]
                }
                root.ppid = m
            }
        }
    }

    // Node id -> pid, resolved through the PipeWire Client objects
    property var nodePid: ({})

    property var _pwProc: Process {
        id: pwProc
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/pw-node-pids.py"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var m = ({})
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].trim().split(" ")
                    var v = []
                    for (var j = 0; j < parts.length; j++)
                        if (parts[j].length > 0) v.push(parts[j])
                    if (v.length >= 2) m[v[0]] = v[1]
                }
                root.nodePid = m
            }
        }
    }

    // MPRIS bus name -> pid. busctl lists both the well-known name and the
    // unique one, and both are indexed because dbusName may return either
    property var mprisPid: ({})

    property var _busProc: Process {
        id: busProc
        command: ["busctl", "--user", "list", "--no-pager"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var m = ({})
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].trim().split(" ")
                    var v = []
                    for (var j = 0; j < parts.length; j++)
                        if (parts[j].length > 0) v.push(parts[j])
                    if (v.length >= 2 && v[0].indexOf("org.mpris.MediaPlayer2.") === 0
                        && v[1] !== "-") {
                            m[v[0]] = v[1]
                            if (v.length >= 5) m[v[4]] = v[1]
                    }
                }
                root.mprisPid = m
            }
        }
    }

    // Restart a Process with running=false while a writing is running make
    // emit streamFinished with truncate text. The maps would partially exit
    // silently, and on clientsProc the truncate goes up to JSON.parse("")
    function _runOnce(p) {
        if (!p.running) p.running = true
    }

    function _reloadAudioMap() {
        _runOnce(psProc)
        _runOnce(pwProc)
        _runOnce(busProc)
    }

    // Goes through the processes chain from all the streams to the window
    function _streamsFor(winPid) {
        var res = []
        if (!winPid) return res
        var nodes = AudioControlState.streamNodes
        var want = String(winPid)
        for (var i = 0; i < nodes.length; i++) {
            var n = nodes[i]
            if (!n || !n.ready || !n.audio) continue
            // The pid lives on the PipeWire Client object, not on the Node:
            // some nodes carry it (Discord), others don't (Spotify), so the
            // helper resolves node -> client.id -> application.process.id.
            var p = root.nodePid[String(n.id)]
            if (!p) continue
            var cur = String(p)
            for (var hop = 0; hop < 8 && cur && cur !== "1"; hop++) {
                if (cur === want) { res.push(n); break }
                cur = root.ppid[cur]
            }
        }
        return res
    }

    // Ties an MPRIS player to the window that owns it, walking the process
    // chain exactly like _streamsFor does
    function _playerFor(winPid) {
        if (!winPid) return null
        var want = String(winPid)
        var l = Players.list
        for (var i = 0; i < l.length; i++) {
            var p = l[i]
            if (!p) continue
            var dn = String(p.dbusName || "")
            var pid = root.mprisPid[dn]
            if (!pid && dn) pid = root.mprisPid["org.mpris.MediaPlayer2." + dn]
            if (!pid) continue
            var cur = String(pid)
            for (var hop = 0; hop < 8 && cur && cur !== "1"; hop++) {
                if (cur === want) return p
                cur = root.ppid[cur]
            }
        }
        return null
    }

    readonly property var wsStreams: {
        var res = []
        for (var i = 0; i < wins.length; i++) {
            var s = _streamsFor(wins[i].pid)
            for (var j = 0; j < s.length; j++) res.push(s[j])
        }
        return res
    }

    readonly property bool wsMuted: {
        if (wsStreams.length === 0) return false
        for (var i = 0; i < wsStreams.length; i++)
            if (!wsStreams[i].audio.muted) return false
        return true
    }

    // A brand new stream can come from a process spawned after the last ps
    property var _streamsConn: Connections {
        target: AudioControlState
        function onStreamNodesChanged() {
            if (root.active && root.workspace) root._reloadAudioMap()
        }
    }

    function _reload(clear) {
        if (clear) { wins = []; geom = ({}); scrollX = 0 }
        if (!workspace || !active) return
        if (clear) _reloadAudioMap()
        _runOnce(clientsProc)
    }

    onWorkspaceChanged: _reload(true)
    // active arrives after workspace: without this the audio maps are never built
    onActiveChanged: if (active) _reload(true)

    // Copre apertura, chiusura e spostamento fra workspace
    property var _toplevelsConn: Connections {
        target: root.workspace ? root.workspace.toplevels : null
        function onValuesChanged() { root._reload(false) }
    }

    // Hyprland non emette alcun evento per spostamenti o ridimensionamenti
    // dentro lo stesso workspace — `movewindow` significa cambio di workspace
    // e `resizewindow` non esiste — quindi la geometria va sondata.
    property var _geomPoll: Timer {
        interval: 500
        repeat: true
        running: root.active && root.workspace !== null
        onTriggered: root._reload(false)
    }

    property var _clientsProc: Process {
        id: clientsProc
        command: ["hyprctl", "clients", "-j"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.workspace) return
                var out = []
                var g = ({})
                try {
                    if (!text || text.trim().length === 0) return
                    var all = JSON.parse(text)
                    for (var i = 0; i < all.length; i++) {
                        var c = all[i]
                        if (!c.workspace || c.workspace.id !== root.workspace.id) continue
                        if (!c.at || !c.size) continue
                        var addr = (c.address || "").replace("0x", "")
                        out.push({ cls: c["class"] || "?", address: addr, pid: c.pid || 0 })
                        g[addr] = { wx: c.at[0], wy: c.at[1], ww: c.size[0], wh: c.size[1] }
                    }
                } catch (e) {
                    console.warn("[wspreview] parse failed:", e)
                    return
                }
                // Prima le coordinate: se la struttura cambia, i delegate nuovi
                // le trovano gia' pronte e non compaiono a dimensione zero.
                root.geom = g
                if (!root._sameStructure(root.wins, out)) root.wins = out
            }
        }
    }

    // Handle wayland corrispondente, per la cattura live dove e' possibile
    function _waylandFor(addr) {
        if (!root.workspace) return null
        var tls = root.workspace.toplevels.values
        for (var i = 0; i < tls.length; i++) {
            var a = (tls[i].address || "").replace("0x", "")
            if (a === addr) return tls[i].wayland
        }
        return null
    }

    // -- Sfondo -----------------------------------
    CutShape {
        anchors.fill: parent
        fillColor: CP.alpha(CP.void2, 0.92)
        strokeColor: CP.alpha(Colours.accentSecondary, 0.55)
        strokeWidth: 1
        inset: 0.5
        cutTopRight: 16
    }

    // -- Etichetta -----------------------------------------
    Text {
        id: wsLabel
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.topMargin: 4
        text: workspace ? ("◢ WS " + workspace.name + " · "
                        + root.wins.length + " WIN") : ""
        font.family: "Oxanium"
        font.pixelSize: 10
        font.letterSpacing: 2
        font.bold: true
        color: Colours.accentSecondary
    }

    Rectangle {
        visible: root.wsStreams.length > 0
        anchors.left: wsLabel.right
        anchors.leftMargin: 8
        anchors.verticalCenter: wsLabel.verticalCenter
        width: wsMuteLabel.implicitWidth + 10
        height: 14
        color: root.wsMuted
            ? CP.alpha(CP.red, wsMuteMa.containsMouse ? 1.0 : 0.8)
            : CP.alpha(Colours.accentSecondary, wsMuteMa.containsMouse ? 0.35 : 0.18)
        Behavior on color { CAnim {} }

        Text {
            id: wsMuteLabel
            anchors.centerIn: parent
            text: root.wsMuted ? "UNMUTE ALL" : "MUTE ALL"
            font.family: "Oxanium"
            font.pixelSize: 8
            font.letterSpacing: 1
            font.bold: true
            color: root.wsMuted ? "white" : CP.alpha(Colours.accentSecondary, 0.9)
        }

        MouseArea {
            id: wsMuteMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                var t = !root.wsMuted
                for (var i = 0; i < root.wsStreams.length; i++)
                    root.wsStreams[i].audio.muted = t
            }
        }
    }

    // -- Superficie del monitor in scala ------------------------
    Item {
        id: stage
        anchors.top: wsLabel.bottom
        anchors.left: parent.left
        anchors.topMargin: root.pad
        anchors.leftMargin: root.pad
        width:  root.stageW
        height: Math.round(root.srcH * root.k)
        clip: true

        Repeater {
            model: root.wins

            delegate: Item {
                id: winItem
                property bool closing: false
                required property var modelData

                readonly property var g: root.geom[modelData.address] || null
                readonly property var streams: root._streamsFor(modelData.pid)
                readonly property bool hasAudio: streams.length > 0
                readonly property bool muted: {
                    if (streams.length === 0) return false
                    for (var i = 0; i < streams.length; i++)
                        if (!streams[i].audio.muted) return false
                    return true
                }
                // Mean over the window's streams: a browser can hold several,
                // and they are moved together as one.
                readonly property real volume: {
                    if (streams.length === 0) return 0
                    var sum = 0
                    for (var i = 0; i < streams.length; i++) sum += streams[i].audio.volume
                    return sum / streams.length
                }

                // Same 5% step as the wheel on the bar's volume module, clamped
                // by AudioControlState.setVolume. Raising a muted window unmutes
                // it, as mixers do; lowering leaves the mute alone.
                function stepVolume(steps) {
                    if (streams.length === 0 || steps === 0) return
                    var next = volume + steps * 0.05
                    for (var i = 0; i < streams.length; i++) {
                        AudioControlState.setVolume(streams[i], next)
                        if (steps > 0 && streams[i].audio.muted)
                            streams[i].audio.muted = false
                    }
                    volFlash.restart()
                }

                visible: g !== null
                x:      g ? (g.wx - (root.monitor ? root.monitor.x : 0)) * root.k - root.scrollX : 0
                y:      g ? (g.wy - (root.monitor ? root.monitor.y : 0)) * root.k : 0
                width:  g ? g.ww * root.k : 0
                height: g ? g.wh * root.k : 0

                Loader {
                    anchors.fill: parent
                    active: !winItem.closing
                    sourceComponent: ScreencopyView {
                        captureSource: root._waylandFor(winItem.modelData.address)
                        live: true
                    }
                }

                // Velo appena percettibile + icona identificativa, sopra la cattura
                Rectangle {
                    anchors.fill: parent
                    color: CP.alpha(CP.void_, 0.10)
                    border.color: CP.alpha(Colours.accentSecondary, 0.4)
                    border.width: 1

                    Image {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 3
                        source: Quickshell.iconPath(winItem.modelData.cls.toLowerCase(),
                                                    "application-x-executable")
                        width:  Math.min(parent.width, parent.height) * 0.18
                        height: width
                        mipmap: true
                        opacity: 0.9
                    }
                }

                HoverHandler { id: winHover }
                
                readonly property var player: root._playerFor(modelData.pid)

                Row {
                    id: mediaRow
                    anchors.centerIn: parent
                    // Scala col riquadro della finestra, con un tetto perche' su
                    // una finestra a schermo intero non diventino sproporzionati
                    readonly property real btn: Math.max(16, Math.min(48,
                        Math.min(winItem.width, winItem.height) * 0.30))
                    spacing: btn * 0.30
                    visible: winItem.player && winHover.hovered
                            && Math.min(winItem.width, winItem.height) > 52

                    Repeater {
                        model: [
                            { key: "prev", glyph: 0xF04AE },
                            { key: "play", glyph: 0 },
                            { key: "next", glyph: 0xF04AD }
                        ]

                        delegate: Item {
                            id: mediaBtn
                            required property var modelData

                            readonly property bool enabled: {
                                var p = winItem.player
                                if (!p) return false
                                if (modelData.key === "prev") return p.canGoPrevious
                                if (modelData.key === "next") return p.canGoNext
                                return p.canTogglePlaying
                            }

                            readonly property string glyph: String.fromCodePoint(
                                modelData.glyph !== 0
                                ? modelData.glyph
                                : (winItem.player && winItem.player.isPlaying
                                    ? 0xF03E4 : 0xF040A))

                            readonly property real base: mediaRow.btn * 0.9

                            width: mediaRow.btn
                            height: mediaRow.btn
                            opacity: enabled ? 1 : 0.3
                            Behavior on opacity { NumberAnimation { duration: 120 } }

                            // Stessa sequenza a scatti di MediaMiniControls
                            property real glowOp: 0.0
                            SequentialAnimation {
                                running: mediaMa.containsMouse && mediaBtn.enabled
                                loops: Animation.Infinite
                                onStopped: mediaBtn.glowOp = 0
                                NumberAnimation { target: mediaBtn; property: "glowOp"; to: 1.0;  duration: 40 }
                                PauseAnimation  { duration: 620 }
                                NumberAnimation { target: mediaBtn; property: "glowOp"; to: 0.15; duration: 25 }
                                PauseAnimation  { duration: 50 }
                                NumberAnimation { target: mediaBtn; property: "glowOp"; to: 1.0;  duration: 35 }
                                PauseAnimation  { duration: 360 }
                                NumberAnimation { target: mediaBtn; property: "glowOp"; to: 0.0;  duration: 20 }
                                PauseAnimation  { duration: 40 }
                                NumberAnimation { target: mediaBtn; property: "glowOp"; to: 0.8;  duration: 20 }
                                PauseAnimation  { duration: 30 }
                                NumberAnimation { target: mediaBtn; property: "glowOp"; to: 0.0;  duration: 20 }
                                PauseAnimation  { duration: 65 }
                                NumberAnimation { target: mediaBtn; property: "glowOp"; to: 1.0;  duration: 80; easing.type: Easing.OutQuad }
                                PauseAnimation  { duration: 510 }
                            }

                            // Alone giallo a cinque strati. Le dimensioni sono
                            // multipli di base invece che offset fissi, perche'
                            // qui il pulsante scala col riquadro della finestra.
                            Text { anchors.centerIn: parent; text: mediaBtn.glyph; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: mediaBtn.base * 1.95; color: Qt.rgba(0.97, 0.94, 0.01, 0.06 * mediaBtn.glowOp) }
                            Text { anchors.centerIn: parent; text: mediaBtn.glyph; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: mediaBtn.base * 1.65; color: Qt.rgba(0.97, 0.94, 0.01, 0.12 * mediaBtn.glowOp) }
                            Text { anchors.centerIn: parent; text: mediaBtn.glyph; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: mediaBtn.base * 1.45; color: Qt.rgba(0.97, 0.94, 0.01, 0.25 * mediaBtn.glowOp) }
                            Text { anchors.centerIn: parent; text: mediaBtn.glyph; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: mediaBtn.base * 1.25; color: Qt.rgba(0.97, 0.94, 0.01, 0.45 * mediaBtn.glowOp) }
                            Text { anchors.centerIn: parent; text: mediaBtn.glyph; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: mediaBtn.base * 1.10; color: Qt.rgba(1, 1, 0.4, 0.70 * mediaBtn.glowOp) }

                            // Ombra e glifo dentro lo stesso wrapper, cosi' lo
                            // scarto della GlitchAnim le sposta insieme
                            Item {
                                anchors.fill: parent
                                transform: Translate { id: labelShift; x: 0 }

                                Text {
                                    anchors.centerIn: parent
                                    anchors.horizontalCenterOffset: 1
                                    anchors.verticalCenterOffset: 1
                                    text: mediaBtn.glyph
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: mediaBtn.base
                                    color: CP.alpha(CP.void_, 0.75)
                                }

                                Text {
                                    id: mediaLabel
                                    anchors.centerIn: parent
                                    text: mediaBtn.glyph
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: mediaBtn.base
                                    color: CP.cyan
                                }
                            }

                            GlitchAnim {
                                id: mediaGlitch
                                labelTarget: mediaLabel
                                shiftTarget: labelShift
                                baseColor: CP.cyan
                                onFinished: if (mediaHover.hovered) pauseGlitchTimer.start()
                            }

                            Timer {
                                id: pauseGlitchTimer
                                interval: 600
                                repeat: false
                                onTriggered: if (mediaHover.hovered) mediaGlitch.restart()
                            }

                            HoverHandler {
                                id: mediaHover
                                onHoveredChanged: {
                                    if (hovered) mediaGlitch.restart()
                                    else { mediaGlitch.reset(); pauseGlitchTimer.stop() }
                                }
                            }

                            MouseArea {
                                id: mediaMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var p = winItem.player
                                    if (!p || !mediaBtn.enabled) return
                                    if (mediaBtn.modelData.key === "prev")      p.previous()
                                    else if (mediaBtn.modelData.key === "next") p.next()
                                    else                                        p.togglePlaying()
                                }
                            }
                        }
                    }
                }

                CutShape {
                    id: volBtn
                    visible: winItem.hasAudio && (winHover.hovered || winItem.muted)
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.margins: 2
                    width: 24
                    height: 24
                    fillColor: winItem.muted
                        ? (muteMa.containsMouse ? CP.red : CP.alpha(CP.red, 0.85))
                        : CP.alpha(CP.void_, muteMa.containsMouse ? 0.9 : 0.7)
                    strokeColor: winItem.muted
                        ? CP.red
                        : CP.alpha(Colours.accentSecondary, muteMa.containsMouse ? 1.0 : 0.6)
                    strokeWidth: 1
                    inset: 0.5
                    cutTopRight: 8
                    showLeft: false
                    showBottom: false
                    Behavior on fillColor   { CAnim {} }
                    Behavior on strokeColor { CAnim {} }

                    Text {
                        anchors.centerIn: parent
                        // nf-md-volume_off / nf-md-volume_high — coppia Material
                        // Design, stesse metriche nei due stati. Codepoint fuori
                        // dal BMP: "\uXXXX" ne leggerebbe solo quattro cifre.
                        text: winItem.muted ? String.fromCodePoint(0xF0581)
                                            : String.fromCodePoint(0xF057E)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: winItem.muted ? "white" : Colours.accentSecondary
                        Behavior on color { CAnim {} }
                    }

                    MouseArea {
                        id: muteMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var t = !winItem.muted
                            for (var i = 0; i < winItem.streams.length; i++)
                                winItem.streams[i].audio.muted = t
                        }

                        // Only this icon turns the wheel into volume; over the
                        // rest of the tile and over empty space it keeps
                        // scrolling the view. Accepting the event is what keeps
                        // the stage's WheelHandler from scrolling as well --
                        // checked with synthetic wheel events in qmltestrunner.
                        //
                        // Deltas accumulate to a whole notch (120), so a
                        // high-resolution touchpad does not jump several steps
                        // per gesture.
                        property real _acc: 0
                        onWheel: wheel => {
                            wheel.accepted = true
                            var d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y
                                                             : wheel.angleDelta.x
                            _acc += d
                            var steps = 0
                            while (_acc >= 120)  { steps++; _acc -= 120 }
                            while (_acc <= -120) { steps--; _acc += 120 }
                            winItem.stepVolume(steps)
                        }
                    }
                }

                // Readout while the wheel is turning, gone a moment after.
                Timer {
                    id: volFlash
                    interval: 900
                }

                CutShape {
                    anchors.left: volBtn.right
                    anchors.leftMargin: 2
                    anchors.verticalCenter: volBtn.verticalCenter
                    width: volText.implicitWidth + 12
                    height: 18
                    visible: opacity > 0
                    opacity: volFlash.running && volBtn.visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                    fillColor: CP.alpha(CP.void_, 0.85)
                    strokeColor: winItem.muted ? CP.red
                                               : CP.alpha(Colours.accentSecondary, 0.8)
                    strokeWidth: 1
                    inset: 0.5
                    cutBottomRight: 5

                    Text {
                        id: volText
                        anchors.centerIn: parent
                        text: Math.round(winItem.volume * 100) + "%"
                        font.family: "Oxanium"
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1
                        color: winItem.muted ? CP.red : Colours.accentSecondary
                    }
                }

                CutShape {
                    id: closeBtn
                    visible: winHover.hovered
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 2
                    width: 24
                    height: 24
                    fillColor: closeMa.containsMouse ? CP.alpha(CP.red, 0.6) : CP.alpha(CP.red, 0.3)
                    strokeColor: CP.alpha(CP.red, closeMa.containsMouse ? 1.0 : 0.6)
                    strokeWidth: 1
                    inset: 0.5
                    cutBottomLeft: 8
                    showTop: false
                    showRight: false
                    Behavior on fillColor { CAnim {} }
                    Behavior on strokeColor { CAnim {} }

                    Text {
                        anchors.centerIn: parent
                        // nf-md-close
                        text: String.fromCodePoint(0xF0156)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: closeMa.containsMouse ? "white" : CP.red
                    }

                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var tl = root._waylandFor(winItem.modelData.address)
                            if (!tl) return
                            winItem.closing = true
                            Qt.callLater(() => tl.close())
                            _refreshAfterClose.restart()
                        }
                    }
                }
            }
        }

        // Workspace vuoto
        Text {
            anchors.centerIn: parent
            visible: root.workspace && root.wins.length === 0
            text: "— EMPTY —"
            font.family: "Oxanium"
            font.pixelSize: 11
            font.letterSpacing: 3
            color: CP.alpha(Colours.textMuted, 0.5)
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                var d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                root.scrollX = Math.max(root.minScroll,
                            Math.min(root.maxScroll, root.scrollX - d / 120 * 80))
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 24
            opacity: root.scrollX > root.minScroll + 0.5 ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: CP.alpha(CP.void_, 0.9) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 24
            opacity: root.scrollX < root.maxScroll - 0.5 ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: CP.alpha(CP.void_, 0.9) }
            }
        }
    }

    // Hyprland impiega un attimo a rimuovere la finestra: ricarica dopo
    property var _refreshAfterClose: Timer {
        interval: 250
        onTriggered: root._runOnce(clientsProc)
    }

    HoverHandler {
        onHoveredChanged: BarState.previewPopupHovered = hovered
    }

    ScanlineOverlay { anchors.fill: parent; opacity: 0.06 }
}
