import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import "../../common/Colors.js" as CP
import "../../common"

Item {
    id: root

    required property MprisPlayer player
    required property real fontSize
    property real topFraction: 0.25
    property real bottomMarginPx: 160

    // Font adattivo: riduce se currRow ha troppe righe
    readonly property real effectiveFontSize: {
        var base = root.fontSize
        if (!lyricsArea || lyricsArea.height <= 0) return base
        // Stima righe curr abbastanza su lunghezza testo
        var charW = base * 0.8 * 0.52
        var availW = lyricsArea.width - 32
        if (availW <= 0) return base
        var lineLen = Math.floor(availW / charW)
        if (lineLen <= 0) return base
        var lines = Math.ceil((_currLyricsTxt || "x"). length / lineLen)
        // Se currRow supera il 40% di lyricsArea, riduci
        var currH = lines * base * 0.8 * 1.2
        var maxH = lyricsArea.height * 0.4
        if (currH > maxH) return Math.max(base * 0.6, base * (maxH / currH))
        return base
    }

    // ── Lyrics State ──────────────────────────────────────────────────────
    property var    lyricsLines:            []
    property string lyricsBuffer:           ""
    property int    currentLyricsIdx:       -1
    property bool   lyricsReady:            false
    property var    lyricsCmd:              []
    property string _prevLyricsTxt:         ""
    property string _prevPrevLyricsTxt:     ""
    property string _currLyricsTxt:         ""
    property string _nextLyricsTxt:         ""
    property bool   hasWordSync:            false
    property bool   _spicyLoaded:           false
    property int    currentWordIdx:         -1
    property string _spicyJsonBuf:          ""
    property real   _sweepProgress:         0
    property real   _sweepDuration:         3000
    property real   _nextSlide:             0
    property real   _currentPosSecs:        0
    property string _pendingJson:           ""
    property var    interlude:              ["", "", ""]
    property bool   isLiked:                false
    property bool   active:                 true

    readonly property bool _prevIsInterlude: lyricsLines[currentLyricsIdx - 1]?.isInterlude ?? false
    readonly property bool _nextIsInterlude: lyricsLines[currentLyricsIdx + 1]?.isInterlude ?? false

    // Raggruppa le sillabe dello stesso vocabolo in un unico item
    readonly property var _wordGroups: {
        const words = root.lyricsLines[root.currentLyricsIdx]?.words ?? null
        if (!words || words.length === 0) return []
        const groups = []
        for (let i = 0; i < words.length; i++) {
            if (i === 0 || words[i].isWordStart !== false)
                groups.push({ syllables: [words[i]], startIdx: i })
            else
                groups[groups.length - 1].syllables.push(words[i])
        }
        return groups
    }

    readonly property string spotifyTrackId: {
        const url = player?.metadata?.["xesam:url"] ?? ""
        if (url.startsWith("spotify:track:")) return url.split(":")[2]
        const m = url.match(/\/track\/([A-Za-z0-9]+)/)
        return m ? m[1] : ""
    }

    readonly property real _playerProgress: {
        const p = player
        return (p && p.length > 0) ? p.position / p.length : 0
    }

    // ── Handlers ────────────────────────────────────────────────────────
    onCurrentLyricsIdxChanged: {
        _prevPrevLyricsTxt  = _prevLyricsTxt
        _prevLyricsTxt      = _currLyricsTxt
        _currLyricsTxt      = lyricsLines[currentLyricsIdx]?.text ?? ""
        _nextLyricsTxt      = lyricsLines[currentLyricsIdx + 1]?.text ?? ""
        currentWordIdx      = -1
        
        lyricsContainer.scrollOffset = prevRow.height + lyricsArea.spacing + 8
        root._nextSlide = root.width + 16
        nextSlideAnim.restart()
        scrollAnim.restart()
        lyricsTransition.restart()

        const hasWords = lyricsLines[currentLyricsIdx]?.words ?? null
        if (!hasWordSync || !hasWords) {
            sweepAnim.stop()
            root._sweepProgress = 0
            const cur = lyricsLines[currentLyricsIdx]
            const nxt = lyricsLines[currentLyricsIdx + 1]
            if (cur && nxt) {
                root._sweepDuration = Math.max(300, (nxt.time - cur.time) * 1000 - 500)
                sweepAnim.start()
            }
        } else {
            sweepAnim.stop()
            root._sweepProgress = 0
        }
    }

    onSpotifyTrackIdChanged: {
        if (!root.spotifyTrackId) {
            root._pendingJson = ""
            root._spicyJsonBuf = ""
            root._spicyLoaded = false
            return
        }
        root._spicyLoaded = false
        const pending = root._pendingJson
        root._pendingJson = ""
        if (pending) {
            try {
                const d = JSON.parse(pending)
                if (d?.trackId === root.spotifyTrackId) {
                    root._loadSpicyLyrics(pending)
                    if (root._spicyLoaded) return
                }
                // trackId doesn't match - discard stale pending, don't re-store
            } catch (e) {}
        }
        root._spicyJsonBuf = ""
        spicyCat.running = false
        spicyCat.running = true
    }

    Connections {
        target: root.player
        function onTrackTitleChanged() { root.fetchLyrics() }
    }

    // ── Timer position ────────────────────────────────────────────────────
    Timer {
        running: root.active
        interval: root.hasWordSync ? 50 : 500
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            Players.active?.positionChanged()
            if (!root.lyricsReady || !root.player || root.lyricsLines.length === 0) return

            const lastTime = root.lyricsLines[root.lyricsLines.length - 1].time
            const unit = root.player.length / lastTime > 500000 ? 1000000
                        : root.player.length / lastTime > 500 ? 1000 : 1
            const posSecs = root._playerProgress * (root.player.length / unit)

            let idx = 0
            for (let i = 0; i < root.lyricsLines.length; i++) {
                if (root.lyricsLines[i].time <= posSecs) idx = i
                else break
            }
            root.currentLyricsIdx = idx
            root._currentPosSecs = posSecs

            if (root.hasWordSync) {
                const words = root.lyricsLines[idx]?.words
                if (words && words.length > 0) {
                    let widx = 0
                    for (let w = 0; w < words.length; w++) {
                        if (words[w].time <= posSecs) widx = w
                        else break
                    }
                    root.currentWordIdx = widx
                } else {
                    root.currentWordIdx = -1
                }
            }
        }
    }

    // ── Processes ────────────────────────────────────────────────────────────────
    Process {
        id: lyricsWatcher
        command: ["inotifywait", "-q", "-m", "-e", "close_write", "/tmp/qs-lyrics.json"]
        running: root.active
        stdout: SplitParser {
            onRead: data => {
                //console.warn("[DBG] lyricsWatcher fired")
                root._pendingJson = ""
                root._spicyJsonBuf = ""
                spicyCat.running = false
                spicyCat.running = true
            }
        }
    }

    Process {
        id: spicyCat
        command: ["cat", "/tmp/qs-lyrics.json"]
        running: false
        stdout: SplitParser { onRead: data => root._spicyJsonBuf += data }
        onExited: root._loadSpicyLyrics(root._spicyJsonBuf)
    }

    Process {
        id: lyricsProc
        command: root.lyricsCmd
        running: false
        stdout: SplitParser { onRead: data => root.lyricsBuffer += data + "\n" }
        onExited: function(exitCode) {
            //console.warn("[DBG] lyricsProc exited: code=" + exitCode
            //            + " spicyLoaded=" + root._spicyLoaded
            //            + " bufLen=" + root.lyricsBuffer.length)
            if (!root._spicyLoaded) {
                root.lyricsLines = root.parseLrc(root.lyricsBuffer)
                root.lyricsReady = root.lyricsLines.length > 0
                root.currentLyricsIdx = -1
                root.hasWordSync = root.lyricsLines.some(l => l.words !== null)
            //    console.warn("[DBG] lyricsProc loaded: lines=" + root.lyricsLines.length)
            }
        }
    }

    Component.onCompleted: if (root.active) spicyCat.running = true

    onActiveChanged: {
        if (active) {
            if (!spicyCat.running) spicyCat.running = true
        } else {
            spicyCat.running = false
        }
    }

    SequentialAnimation {
        id: sweepAnim
        PauseAnimation { duration: 500 }
        NumberAnimation {
            target: root; property: "_sweepProgress"
            from: 0; to: 1
            duration: root._sweepDuration
            easing.type: Easing.Linear
        }
    }

    NumberAnimation {
        id: nextSlideAnim
        target: root; property: "_nextSlide"
        to: 0; duration: 400; easing.type: Easing.OutQuart
    }

    // ── Functions ─────────────────────────────────────────────────────────────────
    function parseLrc(text) {
        const lines = text.split("\n")
        const result = []
        const reLine = /\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)/
        const reWord = /<(\d{2}):(\d{2})\.(\d{2,3})>([^<]*)/g
        for (const line of lines) {
            const m = reLine.exec(line)
            if (!m) continue
            const t = parseInt(m[1]) * 60 + parseInt(m[2]) +
                    parseInt(m[3]) / (m[3].length === 3 ? 1000 : 100)
            const content = m[4].trim()
            if (!content) continue
            let words = null
            if (content.includes("<")) {
                words = []
                reWord.lastIndex = 0
                let wm
                while ((wm = reWord.exec(content)) !== null) {
                    const wt = parseInt(wm[1]) * 60 + parseInt(wm[2]) +
                                parseInt(wm[3]) / (wm[3].length === 3 ? 1000 : 100)
                    const wtext = wm[4].trim()
                    if (wtext) words.push({ time: wt, text: wtext })
                }
                if (words.length === 0) words = null
            }
            const plain = content.replace(/<[^>]+>/g, "").replace(/\s+/g, " ").trim()
            if (plain) result.push({ time: t, text: plain, words: words })
        }
        return result.sort((a, b) => a.time - b.time)
    }

    function _loadSpicyLyrics(jsonStr) {
        if (!jsonStr?.trim()) return
        try {
            const data = JSON.parse(jsonStr ?? "")
            if (!data?.trackId || !data?.lyrics) { 
            //    console.warn("[DBG] no trackId/lyrics")
                return 
            }
            if (data.trackId !== root.spotifyTrackId) {
                if (!root.spotifyTrackId) root._pendingJson = jsonStr // Solo se ID non ancora noto
            //    console.warn("[DBG] trackId mismatch: json=" + data.trackId + " qml=" + root.spotifyTrackId)
                return
            }
            const ld = data.lyrics
            const src = data.lyricsSource ?? "spicy"
            const lines = []
            if (src === "spicy") {
                if (ld.Type === "Static" || !ld.Content) { 
                //    console.warn("[DBG] spicyearly exit: type=" + ld.Type);
                    return
                }
                for (const entry of ld.Content) {
                    if (entry.Type === "Instrumental") {
                        if (entry.StartTime !== null)
                            lines.push({ time: entry.StartTime, endTime: entry.EndTime ?? entry.StartTime + 4,
                                        text: root.interlude.join(" "), isInterlude: true, words: null })
                        continue
                    }
                    if (entry.Type !== "Vocal") continue
                    const syllables = entry.Lead?.Syllables ?? []
                    if (!syllables.length) {
                        if (entry.Text)
                            lines.push({ time: entry.StartTime, endTime: entry.EndTime ?? entry.StartTime + 5,
                                        text: entry.Text, words: null })
                            continue
                    }
                    let lineText = ""
                    const words = syllables.map(function(s, i) {
                        const needsSpace = i > 0 && !syllables[i-1].IsPartOfWord
                        if (needsSpace) lineText += " "
                        lineText += s.Text
                        return { time: s.StartTime, endTime: s.EndTime, word: s.Text, isWordStart: needsSpace }
                    })
                    lines.push({ time: syllables[0].StartTime, endTime: syllables[syllables.length-1].EndTime,
                                text: lineText, words: ld.Type === "Syllable" ? words : null })
                }
            } else {
                if (!ld.lines || !ld.lines.length || ld.syncType === "UNSYNCED") {
                //    console.warn("[DBG] spotify early exit");
                    return
                }
                const isWordSync = ld.syncType === "WORD_SYNCED"
                for (let i = 0; i < ld.lines.length; i++) {
                    const line = ld.lines[i]
                    const timeSecs = parseInt(line.startTimeMs) / 1000
                    const nextTime = i+1 < ld.lines.length ? parseInt(ld.lines[i+1].startTimeMs)/1000 : timeSecs+5
                    const endTime = parseInt(line.endTimeMs) > 0 ? parseInt(line.endTimeMs)/1000 : nextTime-0.1
                    if (!line.words || line.words === "♪") {
                        lines.push({ time: timeSecs, endTime: endTime, text: root.interlude.join(" "), isInterlude: true, words: null }); continue
                    }
                    if (isWordSync && line.syllables?.length > 0) {
                        const words = line.syllables.map(s => ({
                            time: parseInt(s.startTimeMs)/1000, endTime: parseInt(s.endTimeMs)/1000, word: s.syllable
                        }))
                        lines.push({ time: timeSecs, endTime: words[words.length-1].endTime, text: line.words, words: words })
                    } else {
                        lines.push({ time: timeSecs, endTime: endTime, text: line.words, words: null })
                    }
                }
            }
            if (lines.length === 0) {
            //    console.warn("[DBG] lines empty");
                return
            }
            const withGaps = []
            for (let i = 0; i < lines.length; i++) {
                if (i === 0 && lines[0].time > 5)
                    withGaps.push({ time: 0, endTime: lines[0].time-0.5, text: root.interlude.join(" "), isInterlude: true, words: null })
                withGaps.push(lines[i])
                if (i+1 < lines.length) {
                    const gap = lines[i+1].time - lines[i].endTime
                    if (gap > 4)
                        withGaps.push({ time: lines[i].endTime+0.5, endTime: lines[i+1].time-0.5,
                                        text: root.interlude.join(" "), isInterlude: true, words: null })
                }
            }
            root.lyricsLines = withGaps
            root.hasWordSync = withGaps.some(l => l.words !== null)
            root.lyricsReady = true
            root.currentLyricsIdx = -1
            root._spicyLoaded = true
            // Leggi stato like se presente
            if (data.isLiked !== undefined) Players.isLiked = data.isLiked
            // Aggiornamento like state separato (senza lyrics)
            if (data.likeState !== undefined) root.isLiked = data.likeState
            //console.warn("[DBG] loaded ok: src=" + src + " wordSync=" + root.hasWordSync + " lines=" + withGaps.length)
        } catch(e) { 
            //console.warn("[DBG] exception:", e) 
        }
    }

    function fetchLyrics() {
        root._spicyLoaded = false
        root._pendingJson = ""
        if (!root.player?.trackTitle) { root.lyricsLines = []; root.lyricsReady = false; return }
        const cmd = ["/home/kalashnikxv/.config/quickshell/scripts/lyrics-fetch.py",
                    "--title", root.player.trackTitle, "--artist", root.player.trackArtist ?? ""]
        const album = root.player.trackAlbum ?? ""
        if (album) cmd.push("--album", album)
        const lenSecs = Math.round((root.player.length ?? 0) / 1e6)
        if (lenSecs > 0) cmd.push("--duration", String(lenSecs))
        if (root.spotifyTrackId) cmd.push("--spotify-id", root.spotifyTrackId)
        root.lyricsBuffer = ""
        root.lyricsLines = []
        root.lyricsReady = false
        root.currentLyricsIdx = -1
        root.lyricsCmd = cmd
        lyricsProc.running = true
    }

    // ── UI ────────────────────────────────────────────────────────────────────────
    Item {
        id: lyricsArea
        anchors {
            left: parent.left; right: parent.right
            top: parent.top; topMargin: Math.round(parent.height * root.topFraction)
            bottom: parent.bottom; bottomMargin: root.bottomMarginPx
        }
        clip: true
        readonly property real centerY: height / 2
        readonly property real spacing: 24

        Text {
            anchors.centerIn: parent
            visible: !root.lyricsReady && !!root.player
            text: root.lyricsBuffer === "" && !root.lyricsReady ? "♪ ..." : "♪ not found"
            color: CP.magenta; font.family: "Oxanium"; font.pixelSize: root.fontSize * 1.5
        }

        Item {
            id: lyricsContainer
            visible: root.lyricsReady
            width: parent.width
            height: parent.height
            y: 0

            transform: Translate { y: lyricsContainer.scrollOffset }
            property real scrollOffset: 0

            NumberAnimation {
                id: scrollAnim
                target: lyricsContainer; property: "scrollOffset"
                to: 0; duration: 480; easing.type: Easing.OutQuart
            }

            SequentialAnimation {
                id: lyricsTransition
                PropertyAction { target: outgoingRow;   property: "opacity";    value: 1.0 }
                PropertyAction { target: outLeftShift;  property: "x";          value: 0 }
                PropertyAction { target: outRightShift; property: "x";          value: 0 }
                ParallelAnimation {
                    SequentialAnimation {
                        PauseAnimation { duration: 80 }
                        NumberAnimation { target: outgoingRow; property: "opacity"; to: 0.0; duration: 300 }
                    }
                    SequentialAnimation {
                        NumberAnimation { target: outLeftShift; property: "x"; to: -4; duration: 60 }
                        NumberAnimation { target: outLeftShift; property: "x"; to: -2; duration: 40 }
                        NumberAnimation { target: outLeftShift; property: "x"; to: -14; duration: 100 }
                        NumberAnimation { target: outLeftShift; property: "x"; to: -10; duration: 60 }
                        NumberAnimation { target: outLeftShift; property: "x"; to: -28; duration: 320 }
                    }
                    SequentialAnimation {
                        NumberAnimation { target: outRightShift; property: "x"; to: 4; duration: 60 }
                        NumberAnimation { target: outRightShift; property: "x"; to: 2; duration: 40 }
                        NumberAnimation { target: outRightShift; property: "x"; to: 14; duration: 100 }
                        NumberAnimation { target: outRightShift; property: "x"; to: 10; duration: 60 }
                        NumberAnimation { target: outRightShift; property: "x"; to: 28; duration: 320 }
                    }
                }
            }

            // Riga uscente (sale e sparisce — vecchia prev)
            Item {
                id: outgoingRow
                width: parent.width; height: outgoingCenter.implicitHeight
                y: prevRow.y - height - 16
                opacity: 0
                Text { width: parent.width; text: root._prevPrevLyricsTxt === "..." ? root.interlude.join(" ") : root._prevPrevLyricsTxt
                        font.family: "Oxanium"; font.pixelSize: root.fontSize * 0.45; font.weight: Font.Medium
                        color: CP.aberrationCyan(0.7); horizontalAlignment: Text.AlignLeft
                        leftPadding: 36; topPadding: 12; wrapMode: Text.WordWrap
                        transform: Translate { id: outLeftShift; x: 0 } }
                Text { width: parent.width; text: root._prevPrevLyricsTxt === "..." ? root.interlude.join(" ") : root._prevPrevLyricsTxt
                        font.family: "Oxanium"; font.pixelSize: root.fontSize * 0.45; font.weight: Font.Medium
                        color: CP.aberrationRed(0.7); horizontalAlignment: Text.AlignLeft
                        leftPadding: 36; topPadding: 12; wrapMode: Text.WordWrap
                        transform: Translate { id: outRightShift; x: 0 } }
                Text { id: outgoingCenter; width: parent.width; text: root._prevPrevLyricsTxt === "..." ? root.interlude.join(" ") : root._prevPrevLyricsTxt
                    font.family: "Oxanium"; font.pixelSize: root.fontSize * 0.45; font.weight: Font.Medium
                    color: CP.alpha(CP.magenta, 0.7); horizontalAlignment: Text.AlignLeft
                    leftPadding: 36; topPadding: 12; wrapMode: Text.WordWrap }
            }

            // Riga precedente
            Item {
                id: prevRow
                width: parent.width
                height: prevTxt.implicitHeight
                y: {
                    var currTop = currRow.y
                    var space = currTop - lyricsArea.spacing
                    return Math.max(0, (space - height) / 2)
                }
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 8
                    blur: 0.28
                }
                Text {
                    id: prevTxt
                    width: parent.width; 
                    text: root._prevLyricsTxt
                    opacity: root._prevIsInterlude ? 0 : 1
                    font.family: "Oxanium"; 
                    font.pixelSize: root.effectiveFontSize * 0.45; font.weight: Font.Medium
                    color: CP.alpha(CP.magenta, 0.38); horizontalAlignment: Text.AlignLeft
                    leftPadding: 36; topPadding: 12; wrapMode: Text.WordWrap
                }
                Row {
                    visible: root._prevIsInterlude
                    anchors.left: parent.left; anchors.leftMargin: 36
                    anchors.top: parent.top; anchors.topMargin: 12
                    spacing: 12
                    Repeater {
                        model: 3
                        delegate: Item {
                            width: root.fontSize * 0.7
                            height: root.fontSize * 0.5
                            required property int index
                            Text {
                                id: iconDot
                                anchors.fill: parent
                                font.pixelSize: root.fontSize * 0.45
                                text: root.interlude[index]
                                color: CP.alpha(CP.magenta, 0.38)
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }
            }

            // Riga corrente (highlight)
            Item {
                id: currRow
                width: parent.width
                height: Math.max(currTxt.implicitHeight, 1)
                y: lyricsArea.centerY - height / 2

                Text {
                    id: currTxt; visible: !(root.lyricsLines[root.currentLyricsIdx]?.isInterlude ?? false)
                    width: parent.width; text: root._currLyricsTxt; font.weight: Font.Bold
                    font.family: "Oxanium"; font.pixelSize: root.effectiveFontSize * 0.8; color: CP.magenta
                    horizontalAlignment: Text.AlignLeft; wrapMode: Text.WordWrap; leftPadding: 16
                    opacity: (root.hasWordSync && (root.lyricsLines[root.currentLyricsIdx]?.words ?? null) !== null) ? 0 : 0.9
                }

                SequentialAnimation {
                    running: root.lyricsLines[root.currentLyricsIdx]?.isInterlude ?? false
                    loops: Animation.Infinite
                    NumberAnimation { target: currTxt; property: "opacity"; to: 0.15; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { target: currTxt; property: "opacity"; to: 0.63; duration: 900; easing.type: Easing.InOutSine }
                }

                Row {
                    id: interludeDots
                    visible: root.lyricsLines[root.currentLyricsIdx]?.isInterlude ?? false
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    spacing: root.fontSize * 0.8

                    Repeater {
                        model: 3
                        delegate: Item {
                            required property int index
                            implicitWidth: dot.width
                            implicitHeight: dot.height + root.fontSize * 0.8

                            //Rectangle {
                            Text {
                                id: dot
                                width: root.fontSize * 0.28
                                height: width
                                font.pixelSize: root.fontSize * 0.8
                                text: root.interlude[index]
                                color: CP.magenta
                                opacity: 0.3
                                scale: 0.8
                                y: root.fontSize * 0.25
                                anchors.horizontalCenter: parent.horizontalCenter

                                transform: Translate { id: dotShift; x: 0 }

                                SequentialAnimation {
                                    running: interludeDots.visible
                                    loops: Animation.Infinite

                                    // offset per dot
                                    PauseAnimation { duration: index * 800 }

                                    // PRE-GLITCH: jitter posizione + flash cyan (80ms)
                                    PropertyAction { target: dot;       property: "color";      value: CP.alpha(CP.cyan, 0.9) }
                                    PropertyAction { target: dot;       property: "scale";      value: 1.2 }
                                    PropertyAction { target: dotShift;  property: "x";          value: -3 }
                                    PauseAnimation { duration: 25 }
                                    PropertyAction { target: dot;       property: "scale";      value: 0.72 }
                                    PropertyAction { target: dotShift;  property: "x";          value: 3 }
                                    PauseAnimation { duration: 25 }
                                    PropertyAction { target: dot;       property: "color";      value: CP.magenta }
                                    PropertyAction { target: dot;       property: "opacity";    value: 0.85 }
                                    PropertyAction { target: dotShift;  property: "x";          value: 0 }
                                    PauseAnimation { duration: 30 }

                                    // MAIN BURST: peak yellow + micro-stutter (120ms)
                                    PropertyAction { target: dot;       property: "color";      value: CP.yellow }
                                    PropertyAction { target: dot;       property: "scale";      value: 1.35 }
                                    PropertyAction { target: dot;       property: "opacity";    value: 1.0 }
                                    PauseAnimation { duration: 40 }
                                    PropertyAction { target: dot;       property: "scale";      value: 1.15 }
                                    PropertyAction { target: dotShift;  property: "x";          value: -2 }
                                    PauseAnimation { duration: 40 }
                                    PropertyAction { target: dot;       property: "scale";      value: 1.0 }
                                    PropertyAction { target: dotShift;  property: "x";          value: 0 }
                                    PauseAnimation { duration: 40 }

                                    // HOLDBRIGHT: magenta (150ms)
                                    PropertyAction { target: dot;       property: "color";      value: CP.magenta }
                                    PauseAnimation { duration: 150 }

                                    // DECAY STUTTER: flicker opacita' + scatto laterale (100ms)
                                    PropertyAction { target: dot;       property: "opacity";    value: 0.55 }
                                    PropertyAction { target: dotShift;  property: "x";          value: 2 }
                                    PauseAnimation { duration: 25 }
                                    PropertyAction { target: dot;       property: "opacity";    value: 0.8 }
                                    PropertyAction { target: dotShift;  property: "x";          value: 0 }
                                    PauseAnimation { duration: 50 }

                                    // FADE TO IDLE (150ms)
                                    ParallelAnimation {
                                        NumberAnimation { target: dot; property: "scale"; to: 0.8; duration: 150; easing.type: Easing.Linear }
                                        NumberAnimation { target: dot; property: "opacity"; to: 0.3; duration: 150; easing.type: Easing.Linear }
                                    }

                                    // IDLE (tail padding per ciclo uniforme a 2400ms)
                                    PauseAnimation { duration: (2 - index) * 800 + 200 }
                                }
                            }
                        }
                    }
                }

                Flow {
                    width: parent.width; spacing: 0; leftPadding: 16; rightPadding: 16
                    visible: root.hasWordSync && (root.lyricsLines[root.currentLyricsIdx]?.words ?? null) !== null
                    Repeater {
                        model: root._wordGroups
                        delegate: Item {
                            id: wordDel
                            required property int index
                            required property var modelData
                            // modelData = { syllables: [...], startIdx: N }
                            readonly property real leadingW: (modelData.syllables[0].isWordStart === true) ? 6 : 0
                            implicitWidth: leadingW + syllRow.implicitWidth
                            implicitHeight: syllRow.implicitHeight

                            Row {
                                id: syllRow
                                x: wordDel.leadingW
                                spacing: 0
                                Repeater {
                                    model: wordDel.modelData.syllables
                                    delegate: Item {
                                        id: sylDel
                                        required property int index
                                        required property var modelData
                                        readonly property int globalIdx: wordDel.modelData.startIdx + index
                                        readonly property real fillProg: {
                                            if (globalIdx < root.currentWordIdx) return 1.0
                                            if (globalIdx > root.currentWordIdx) return 0.0
                                            const w = root.lyricsLines[root.currentLyricsIdx]?.words?.[globalIdx]
                                            if (!w?.endTime || w.endTime <= w.time) return 1.0
                                            return Math.max(0, Math.min(1, (root._currentPosSecs - w.time) / (w.endTime - w.time)))
                                        }
                                        implicitWidth: sylContent.implicitWidth
                                        implicitHeight: sylContent.implicitHeight

                                        Item {
                                            id: sylContent
                                            scale: letterMode ? 1.0 : _wordScale
                                            transformOrigin: Item.Center
                                            transform: Translate { y: sylContent.letterMode ? 0 : sylContent._wordLift }
                                            implicitWidth: letterMode ? letterRow.implicitWidth : baseWord.implicitWidth
                                            implicitHeight: letterMode ? letterRow.implicitHeight : baseWord.implicitHeight
                                            readonly property bool letterMode: sylDel.modelData.word.length > 1
                                                                                && sylDel.modelData.word.length <= 12
                                                                                && ((sylDel.modelData.endTime ?? 0) - sylDel.modelData.time) >= 1.0
                                            readonly property real activeLetterIdx: {
                                                if (!letterMode) return -1
                                                const d = (sylDel.modelData.endTime ?? 0) - sylDel.modelData.time
                                                if (d <= 0) return 0
                                                return Math.max(0, (root._currentPosSecs - sylDel.modelData.time) / d) * sylDel.modelData.word.length
                                            }
                                            property real _animProg: 0
                                            Component.onCompleted: { if (sylDel.globalIdx < root.currentWordIdx) _animProg = 1.0 }
                                            NumberAnimation { id: activateAnim; target: sylContent; property: "_animProg"
                                                            from: 0; to: 1; duration: 420; easing.type: Easing.Linear }
                                            Connections {
                                                target: root
                                                function onCurrentWordIdxChanged() {
                                                    if (root.currentWordIdx === sylDel.globalIdx) { sylContent._animProg = 0; activateAnim.restart() }
                                                }
                                            }
                                            property real _wordScale: {
                                                if (sylDel.globalIdx > root.currentWordIdx && !activateAnim.running) return 0.95
                                                const p = sylContent._animProg
                                                if (p < 0.7) return 0.95 + 0.075 * (p / 0.7)
                                                return 1.025 - 0.025 * ((p - 0.7) / 0.3)
                                            }
                                            property real _wordLift: {
                                                if (sylDel.globalIdx > root.currentWordIdx && !activateAnim.running) return 0
                                                return -(root.fontSize * 0.6 / 12.0) * Math.sin(sylContent._animProg * Math.PI)
                                            }
                                            Text { id: baseWord; text: sylDel.modelData.word; font.family: "Oxanium"
                                                    font.pixelSize: root.fontSize * 0.8; font.weight: Font.Bold
                                                    color: CP.alpha(CP.magenta, 0.52); visible: !sylContent.letterMode }
                                            Item {
                                                visible: !sylContent.letterMode
                                                width: baseWord.implicitWidth
                                                height: baseWord.implicitHeight
                                                layer.enabled: true
                                                layer.effect: MultiEffect {
                                                    maskEnabled: true
                                                    maskSource: sweepMask
                                                    shadowEnabled: true
                                                    shadowColor: CP.yellow
                                                    shadowBlur: 0.8
                                                    shadowOpacity: Math.sin(Math.max(0, Math.min(1, sylDel.fillProg)) * Math.PI) * 0.65
                                                    shadowHorizontalOffset: 0
                                                    shadowVerticalOffset: 0
                                                }
                                                Text {
                                                    width: parent.width
                                                    text: sylDel.modelData.word
                                                    font.family: "Oxanium"
                                                    font.pixelSize: root.fontSize * 0.8
                                                    font.weight: Font.Bold
                                                    color: CP.yellow
                                                }
                                                Rectangle {
                                                    id: sweepMask
                                                    visible: false
                                                    layer.enabled: true
                                                    width: parent.width
                                                    height: parent.height
                                                    readonly property real fp: Math.max(0, Math.min(1, sylDel.fillProg))
                                                    gradient: Gradient {
                                                        orientation: Gradient.Horizontal
                                                        GradientStop {
                                                            position: 0.0
                                                            color: sweepMask.fp >= 0.15 ? "white" : Qt.rgba(1, 1, 1, sweepMask.fp / 0.15)
                                                        }
                                                        GradientStop {
                                                            position: Math.max(0.001, sweepMask.fp - 0.15)
                                                            color: sweepMask.fp > 0 ? "white" : "transparent"
                                                        }
                                                        GradientStop {
                                                            position: Math.min(0.999, sweepMask.fp + 0.04)
                                                            color: sweepMask.fp >= 0.97 ? "white" : "transparent"
                                                        }
                                                        GradientStop { position: 1.0; color: sweepMask.fp >= 0.97 ? "white" : "transparent" }
                                                    }
                                                }
                                            }

                                            Row {
                                                id: letterRow
                                                visible: sylContent.letterMode
                                                spacing: 0
                                                Repeater {
                                                    model: sylContent.letterMode ? sylDel.modelData.word.length : 0
                                                    delegate: Item {
                                                        id: letterDel
                                                        required property int index
                                                        readonly property string ch: sylDel.modelData.word[index]
                                                        readonly property real lDur: {
                                                            const d = (sylDel.modelData.endTime ?? 0) - sylDel.modelData.time
                                                            return d > 0 ? d / sylDel.modelData.word.length : 0
                                                        }
                                                        readonly property real lStart: sylDel.modelData.time + index * lDur
                                                        readonly property real lfp: lDur > 0
                                                                                    ? Math.max(0, Math.min(1, (root._currentPosSecs - lStart) / lDur))
                                                                                    : sylDel.fillProg
                                                        readonly property real gFalloff: Math.max(0,
                                                                                        1 / (1 + Math.abs(sylContent.activeLetterIdx - (index + 0.5)) * 0.9))
                                                        
                                                        implicitWidth: letterBase.implicitWidth
                                                        implicitHeight: letterBase.implicitHeight

                                                        readonly property real _lScale: {
                                                            const p = Math.max(0, Math.min(1, lfp))
                                                            if (p <= 0) return 0.95
                                                            if (p < 0.7) return 0.95 + 0.075 * (p / 0.7)
                                                            return 1.025 - 0.025 * ((p - 0.7) / 0.3)
                                                        }
                                                        readonly property real _lLift: -(root.fontSize * 0.6 / 12.0) * Math.sin(Math.max(0, Math.min(1, lfp)) * Math.PI)
                                                        scale: _lScale
                                                        transformOrigin: Item.Center
                                                        transform: Translate { y: letterDel._lLift }
                                                        Text {
                                                            id: letterBase
                                                            text: letterDel.ch
                                                            font.family: "Oxanium"; font.pixelSize: root.fontSize * 0.8; font.weight: Font.Bold
                                                            color: CP.alpha(CP.magenta, 0.52)
                                                        }
                                                        Item {
                                                            width: letterBase.implicitWidth; height: letterBase.implicitHeight
                                                            layer.enabled: true
                                                            layer.effect: MultiEffect {
                                                                maskEnabled: true; maskSource: letterMask
                                                                shadowEnabled: true; shadowColor: CP.yellow; shadowBlur: 0.9
                                                                shadowOpacity: Math.sin(letterDel.lfp * Math.PI) * letterDel.gFalloff * 1.1
                                                                shadowHorizontalOffset: 0; shadowVerticalOffset: 0
                                                            }
                                                            Text {
                                                                width: parent.width; text: letterDel.ch
                                                                font.family: "Oxanium"; font.pixelSize: root.fontSize * 0.8; font.weight: Font.Bold
                                                                color: CP.yellow
                                                            }
                                                            Rectangle {
                                                                id: letterMask; visible: false; layer.enabled: true
                                                                width: parent.width; height: parent.height
                                                                readonly property real fp: letterDel.lfp
                                                                gradient: Gradient {
                                                                    orientation: Gradient.Horizontal
                                                                    GradientStop { position: 0.0; color: letterMask.fp >= 0.15 ? "white" : Qt.rgba(1, 1, 1, letterMask.fp / 0.15) }
                                                                    GradientStop { position: Math.max(0.001, letterMask.fp - 0.15); color: letterMask.fp > 0 ? "white" : "transparent" }
                                                                    GradientStop { position: Math.min(0.999, letterMask.fp + 0.04); color: letterMask.fp >= 0.97 ? "white" : "transparent" }
                                                                    GradientStop { position: 1.0; color: letterMask.fp >= 0.97 ? "white" : "transparent" }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    visible: (!root.hasWordSync || (root.lyricsLines[root.currentLyricsIdx]?.words ?? null) === null) &&
                                !(root.lyricsLines[root.currentLyricsIdx]?.isInterlude ?? false)
                    width: parent.width; height: root._sweepProgress * currTxt.implicitHeight; clip: true
                    Text {
                        width: parent.width; text: root._currLyricsTxt; font.family: "Oxanium"; font.weight: Font.Bold
                        font.pixelSize: root.effectiveFontSize * 0.8; color: CP.yellow; leftPadding: 16
                        horizontalAlignment: Text.AlignLeft; wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
    // nextRow fuori dal clip di lyricsArea, con slide orizzontale
    Item {
        x: 0
        y: Math.min(
            lyricsArea.y + lyricsContainer.y + currRow.y + currRow.height + (currRow.y - prevRow.y - prevRow.height),
            parent.height - nextTxt.implicitHeight
        )
        width: parent.width
        height: nextTxt.implicitHeight
        visible: root.lyricsReady && root.currentLyricsIdx + 1 < root.lyricsLines.length
        clip: true

        Item {
            x: root._nextSlide
            width: parent.width
            height: parent.height
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true; blurMax: 8; blur: 0.72
            }
            Text {
                id: nextTxt
                width: parent.width
                text: root._nextLyricsTxt
                opacity: root._nextIsInterlude ? 0 : 1
                font.family: "Oxanium"; font.pixelSize: root.effectiveFontSize * 0.45; font.weight: Font.Medium
                color: CP.alpha(CP.magenta, 0.38); horizontalAlignment: Text.AlignLeft
                leftPadding: 36; bottomPadding: 12; wrapMode: Text.WordWrap 
            }
            Row {
                visible: root._nextIsInterlude
                anchors.left: parent.left; anchors.leftMargin: 36
                anchors.top: parent.top; anchors.topMargin: 0
                spacing: 12
                Repeater {
                    model: 3
                    delegate: Item {
                        required property int index
                        width: root.fontSize * 0.7
                        height: root.fontSize * 0.5
                        Text {
                            anchors.fill: parent
                            font.pixelSize: root.fontSize * 0.45
                            text: root.interlude[index]
                            color: CP.alpha(CP.magenta, 0.38)
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    }
}