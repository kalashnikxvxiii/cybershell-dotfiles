pragma Singleton

import Quickshell.Io
import Quickshell
import QtQuick

QtObject {
    id: root

    // ── Panel visibility ─────────────────────────────────
    property bool panelOpen: false
    function togglePanel() { panelOpen = !panelOpen }

    // ── Active playlist data ─────────────────────────────────
    property string intervalMode:       "fixed"
    property string screenMode:         "both"
    property string activeName:         ""
    property bool   shuffle:            false
    property bool   sync:               true
    property var    _saveActiveProc:    Process {
        command: ["true"]
        running: false
    }
    property var    _screenIndexes:     ({})
    property var    playlistNames:      []
    property var    _screenKind:        ({})
    property var    _allData:           ({})
    property var    entries:            []
    property int    interval:           300

    signal entryApplyRequestedFor(string screen, string path)

    // ── Playlist highlight state ──────────────────────────────────
    property string entryHighlightPath: ""
    property string selectedEntryPath:  ""
    property var    highlightFilter: ({ active: false, path: "", playlists: [] })

    // ── Delete playlist/wallpaper card confirm dialog ────────────────────
    property var    pendingDelete:      null

    function requestDeleteEntry(idx) {
        if (idx < 0 || idx >= entries.length) return
        var entry = entries[idx]
        if (!entry) return
        var bn = (entry.path || "").split("/").pop()
        pendingDelete = { type: "entry", payload: idx, label: bn }
    }

    function requestDeletePlaylist(name) {
        pendingDelete = { type: "playlist", payload: name, label: name }
    }

    function confirmDelete() {
        if (!pendingDelete) return
        if (pendingDelete.type === "entry") removeEntry(pendingDelete.payload)
        else if (pendingDelete.type === "playlist") deletePlaylist(pendingDelete.payload)
        pendingDelete = null
    }

    function cancelDelete() {
        pendingDelete = null
    }

    onPanelOpenChanged: {
        if (!panelOpen) {
            entryHighlightPath = ""
            selectedEntryPath = ""
        }
    }

    function selectEntry(path) {
        entryHighlightPath = ""
        selectedEntryPath = (selectedEntryPath === path) ? "" : path
    }

    function highlightEntry(path) {
        entryHighlightPath = path
        panelOpen = true
    }

    function setHighlightFilter(path) {
        var matches = []
        for (var name in _allData) {
            var arr = _allData[name]
            for (var i = 0; i < arr.length; i++)
                if (arr[i].path === path) { matches.push(name); break }
        }
        highlightFilter = { active: true, path: path, playlists: matches }
        panelOpen = true
    }

    function clearHighlightFilter() {
        highlightFilter = { active: false, path: "", playlists: [] }
    }

    // ── Playback state ────────────────────────────────────────
    property bool isPlaying:    false
    property int  currentIndex: 0

    // ── Playlist snapshot (decoupled from active/displayed playlist) ──
    property string playingIntervalMode:    "fixed"
    property string playingScreenMode:      "both"
    property string playingName:            ""
    property bool   playingShuffle:         false
    property bool   playingSync:            true
    property int    playingInterval:        300
    property var    playingEntries:         []

    signal entryApplyRequested(string path)

    // ── Playlist preview ──────────────────────────────────────────────
    signal previewRequested(string path, string source)

    function requestPreview(entry) {
        if (!entry) return
        previewRequested(entry.path, entry.source || "awww")
    }

    // ── Playlist selection ────────────────────────────────────────────
    onActiveNameChanged: {
        var toWrite = activeName !== "" ? activeName : "__none__"
        _saveActiveProc.command = ["bash", "-c",
            "printf '%s' '" + toWrite + "' > '" + _dir + "/.active'"]
        _saveActiveProc.running = false
        _saveActiveProc.running = true
    }

    function countInAll(path) {
        var count = 0
        for (var name in _allData) {
            var arr = _allData[name]
            for (var i = 0; i < arr.length; i++)
                if (arr[i].path === path) { count++; break }
        }
        return count
    }

    function deselectPlaylist() {
        activeName = ""
        entries = []
    }

    // ── Queries ────────────────────────────────────────────
    function isInPlaylist(path) {
        var arr = entries
        for (var i = 0; i < arr.length; i++)
            if (arr[i].path === path) return i + 1
        return -1
    }

    function positionOf(path) {
        var arr = entries
        for (var i = 0; i < arr.length; i++)
            if (arr[i].path === path) return i + 1
        return -1
    }

    // ── Mutations ─────────────────────────────────────────────
    function toggleEntry(path, type, title, source, thumb) {
        var arr = entries.slice()
        for (var i = 0; i < arr.length; i++) {
            if (arr[i].path === path) {
                arr.splice(i, 1)
                entries = arr
                _savePlaylist()
                return
            }
        }
        arr.push({
            path: path,
            type: type      || "image",
            title: title    || "",
            source: source  || "awww",
            thumb: thumb    || path,
            interval: interval
        })
        entries = arr
        panelOpen = true
        _savePlaylist()
    }

    function removeEntry(idx) {
        if (idx < 0 || idx >= entries.length) return
        var arr = entries.slice()
        arr.splice(idx, 1)
        entries = arr
        if (currentIndex >= entries.length) currentIndex = Math.max(0, entries.length - 1)
        _savePlaylist()
    }

    function moveEntry(from, to) {
        if (from === to || from < 0 || to < 0 || from >= entries.length || to >= entries.length) return
        var arr = entries.slice()
        var item = arr.splice(from, 1)[0]
        arr.splice(to, 0, item)
        entries = arr
        _savePlaylist()
    }

    function setEntryInterval(idx, secs) {
        if (idx < 0 || idx >= entries.length) return
        var arr = entries.slice()
        var e = arr[idx]
        arr[idx] = { path: e.path, type: e.type, title: e.title, source: e.source, thumb: e.thumb || e.path, interval: secs }
        entries = arr
        _savePlaylist()
    }

    function setPlaylistProp(key, value) {
        if      (key === "intervalMode") intervalMode = value
        else if (key === "interval")     interval     = value
        else if (key === "shuffle")      shuffle      = value
        else if (key === "screenMode")   screenMode   = value
        else if (key === "sync")         sync         = value
        _savePlaylist()
    }

    // ── Playback ────────────────────────────────────────────────
    function play() {
        if (entries.length === 0) return

        // Snapshot active state into playing state (decoupled from display)
        playingName         = activeName
        playingEntries      = entries.slice()
        playingIntervalMode = intervalMode
        playingInterval     = interval
        playingShuffle      = shuffle
        playingScreenMode   = screenMode
        playingSync         = sync
        currentIndex        = 0

        var indep = (screenMode === "both" && !playingSync && Quickshell.screens.length > 1)
        if (indep) {
            // Indep: randomize each screen's index independently when shuffle is on
            var newIndexes = ({})
            for (var i = 0; i < Quickshell.screens.length; i++) {
                var sn = Quickshell.screens[i].name
                if (playingShuffle) {
                    newIndexes[sn] = Math.floor(Math.random() * playingEntries.length)
                } else {
                    var cur = _screenIndexes[sn]
                    newIndexes[sn] = (cur !== undefined && cur >= 0 && cur < playingEntries.length) ? cur : 0
                }
            }
            _screenIndexes = newIndexes
        } else if (playingShuffle) {
            currentIndex = Math.floor(Math.random() * playingEntries.length)
        }
        isPlaying = true
    }

    function pause() {
        isPlaying = false
        _advanceTimer.stop()
    }

    function stop() {
        isPlaying       = false
        currentIndex    = 0
        playingName     = ""
        playingEntries  = []
        _advanceTimer.stop()
    }

    function _isWpe(path) {
        return path.indexOf("/steamcmd-isolated/.steam/SteamApps/workshop") !== -1
    }

    function _applyToScreens(screensList, pathsByScreen) {
        var allArgs = []
        var newKind = Object.assign({}, _screenKind)

        for (var i = 0; i < screensList.length; i++) {
            var sn = screensList[i]
            var p = pathsByScreen[sn]
            newKind[sn] = _isWpe(p) ? "wpe" : "static"
            allArgs.push(sn + ":" + p)
        }

        // Plugin sempre trasparente durante il cycle — awww renderizza tutto
        for (var c = 0; c < screensList.length; c++) {
            WallpaperState.setScreenWallpaper(screensList[c], "")
        }

        if (allArgs.length > 0) {
            var cmd = ["/home/kalashnikxv/.config/hypr/scripts/wallpaper-themer.sh", "playlist-apply"]
            for (var k = 0; k < allArgs.length; k++) cmd.push(allArgs[k])
            Quickshell.execDetached(cmd)
        }

        _screenKind = newKind
    }

    function next() {
        if (playingEntries.length === 0) return

        var entriesByScreen = ({})
        var screensList = []
        var indep = (playingScreenMode === "both" && !playingSync && Quickshell.screens.length > 1)

        if (indep) {
            // Independent: each screen has its own path
            var newIndexes = ({})
            for (var i = 0; i < Quickshell.screens.length; i++) {
                var sn = Quickshell.screens[i].name
                var prev = _screenIndexes[sn] !== undefined ? _screenIndexes[sn] : -1
                var idx = playingShuffle
                        ? Math.floor(Math.random() * playingEntries.length)
                        : (prev + 1) % playingEntries.length
                newIndexes[sn] = idx
                entriesByScreen[sn] = playingEntries[idx].path
                screensList.push(sn)
            }
            _screenIndexes = newIndexes
        } else {
            //Sync: same path to all the target screens
            if (playingShuffle)
                currentIndex = Math.floor(Math.random() * playingEntries.length)
            else
                currentIndex = (currentIndex + 1) % playingEntries.length
            var entry = playingEntries[currentIndex]
            for (var i = 0; i < Quickshell.screens.length; i++) {
                var sn = Quickshell.screens[i].name
                if (playingScreenMode === "both" || playingScreenMode === sn) {
                    entriesByScreen[sn] = entry.path
                    screensList.push(sn)
                }
            }
        }

        if (screensList.length > 0) _applyToScreens(screensList, entriesByScreen)

        if (isPlaying) {
            var ms = _currentInterval()
            if (ms > 0) { _advanceTimer.interval = ms; _advanceTimer.restart() }
            else _advanceTimer.stop()
        }
    }

    function prev() {
        if (playingEntries.length === 0) return
        currentIndex = (currentIndex - 1 + playingEntries.length) % playingEntries.length
        _applyCurrentEntry()
    }

    function _currentInterval() {
        if (intervalMode === "per_entry" && currentIndex < entries.length) {
            var ei = entries[currentIndex].interval
            if (ei > 0) return ei * 1000
        }
        return interval * 1000
    }

    onIsPlayingChanged: {
        if (isPlaying) _applyCurrentEntry()
        else _advanceTimer.stop()
        _savePlaybackState()
    }

    onCurrentIndexChanged: _savePlaybackState()

    function _applyCurrentEntry() {
        if (playingEntries.length === 0) return

        var pathsByScreen = ({})
        var screensList = []
        var indep = (playingScreenMode === "both" && !playinSync && Quickshell.screens.length > 1)

        if (indep) {
            // Each screen has its own index from _screenIndexes (persisted across restarts)
            var newIndexes = Object.assign({}, _screenIndexes)
            for (var i = 0; i < Quickshell.screens.length; i++) {
                var sn = Quickshell.screens[i].name
                var idx = newIndexes[sn]
                if (idx === undefined || idx < 0 || idx >= playingEntries.length) {
                    idx = playingShuffle ? Math.floor(Math.random() * playingEntries.length) : 0
                    newIndexes[sn] = idx
                }
                pathsByScreen[sn] = playingEntries[idx].path
                screensList.push(sn)
            }
            _screenIndexes = newIndexes
        } else {
            if (currentIndex < 0 || currentIndex >= playingEntries.length) return
            var entry = playingEntries[currentIndex]
            for (var i = 0; i < Quickshell.screens.length; i++) {
                var sn = Quickshell.screens[i].name
                if (playingScreenMode === "both" || playingScreenMode === sn) {
                    pathsByScreen[sn] = entry.path
                    screensList.push(sn)
                }
            }
        }

        if (screensList.length > 0) _applyToScreens(screensList, pathsByScreen)

        if (isPlaying) {
            var ms = _currentInterval()
            if (ms > 0) { _advanceTimer.interval = ms; _advanceTimer.restart() }
            else _advanceTimer.stop()
        }
    }

    property var _advanceTimer: Timer {
        repeat: false
        onTriggered: {
            if (root.isPlaying) root.next()
        }
    }

    // ── Persistence ────────────────────────────────────────────────────────────
    readonly property string _dir: "/home/kalashnikxv/.cache/wallpaper-picker/playlists"

    property bool   _playbackRestored:  false
    property var    _savePlaybackProc: Process {
        command: ["true"]
        running: false
    }

    function _savePlaybackState() {
        var d = {
            playing: isPlaying,
            index: currentIndex,
            screenIndexes: _screenIndexes
        }
        _savePlaybackProc.command = [
            "python3", "-c",
            "import sys; open(sys.argv[1], 'w').write(sys.argv[2])",
            _dir + "/.playback",
            JSON.stringify(d)
        ]
        _savePlaybackProc.running = false
        _savePlaybackProc.running = true
    }

    property var _readPlaybackProc: Process {
        command: ["true"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                try {
                    var d = JSON.parse(data.trim())
                    if (typeof d.index === "number" && d.index >= 0 && d.index < root.entries.length) {
                        root.currentIndex = d.index
                    }
                    if (d.screenIndexes && typeof d.screenIndexes === "object") {
                        root._screenIndexes = d.screenIndexes
                    }
                    if (d.playing === true) {
                        root.isPlaying = true
                    }
                } catch(e) {}
            }
        }
    }

    Component.onCompleted: {
        _mkdirProc.running = true
        // Force re-apply post hot-reload: if the singleton keeps isPlaying=true
        // but the code was reloaded, onIsPlayingChanged don't refire
        // Differs one tick to give entries the time to reload
        _reapplyAfterReload.start()
    }

    property var _reapplyAfterReload: Timer {
        interval: 200
        repeat: false
        onTriggered: {
            if (isPlaying && entries.length > 0) {
                _applyCurrentEntry()
            }
        }
    }

    property var _mkdirProc: Process {
        command: ["bash", "-c", "mkdir -p /home/kalashnikxv/.cache/wallpaper-picker/playlists"]
        running: false
        onRunningChanged: if (!running) root._doListNames()
    }

    function _doListNames() {
        _listProc.running = false
        _listProc.running = true
    }

    property var _listProc: Process {
        command: ["python3", "-c",
            "import json,glob,os\n" +
            "d='" + _dir + "'\n" +
            "names=sorted([os.path.basename(f)[:-5] for f in glob.glob(d+'/*.json') if not os.path.basename(f).startswith('.')])\n" +
            "af=d+'/.active'\n" +
            "active=open(af).read().strip() if os.path.exists(af) else ''\n" +
            "print(json.dumps({'names':names,'active':active}))"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                try {
                    var obj = JSON.parse(data.trim())
                    var names = obj.names || []
                    var active = obj.active || ""
                    root.playlistNames = names
                    if (active === "__none__") {
                        // deselezionato intenzionalmente
                    } else if (active !== "" && names.indexOf(active) >= 0) {
                        root.loadPlaylist(active)
                    } else if (names.length > 0) {
                        root.loadPlaylist(names[0])
                    }
                    root._loadAllProc.running = true
                } catch(e) {}
            }
        }
    }

    property var _loadAllProc: Process {
        command: ["python3", "-c",
            "import json,glob,os\n" +
            "d={}\n" +
            "for f in glob.glob('" + _dir + "/*.json'):\n" +
            "    n=os.path.basename(f)[:-5]\n" +
            "    try: d[n]=json.load(open(f)).get('entries',[])\n" +
            "    except: pass\n" +
            "print(json.dumps(d))"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                try { root._allData = JSON.parse(data) } catch(e) {}
            }
        }
    }

    function loadPlaylist(name) {
        activeName = name
        _readFile.path = _dir + "/" + name + ".json"
        _readFile.reload()
    }

    property var _readFile: FileView {
        path: ""
        onLoaded: {
            try {
                var d = JSON.parse(text())
                root.entries      = d.entries        || []
                root.intervalMode = d.interval_mode  || "fixed"
                root.interval     = d.interval       || 300
                root.shuffle      = d.shuffle        || false
                var sm = d.screen_mode || "both"
                if (sm === "sync" || sm === "independet" || sm === "indep") sm = "both"
                root.screenMode = sm
                root.sync = (d.sync !== undefined) ? d.sync : true
                if (!root._playbackRestored) {
                    root._playbackRestored = true
                    _readPlaybackProc.command = ["bash", "-c", "cat '" + _dir + "/.playback' 2>/dev/null"]
                    _readPlaybackProc.running = false
                    _readPlaybackProc.running = true
                }
            } catch(e) {}
        }
    }

    function _savePlaylist() {
        if (activeName === "") return
        var ad = _allData
        ad[activeName] = entries.slice()
        _allData = ad
        var d = {
            name: activeName,
            interval_mode: intervalMode,
            interval: interval,
            shuffle: shuffle,
            screen_mode: screenMode,
            sync: sync,
            entries: entries
        }
        _saveProc.command = [
            "python3", "-c",
            "import sys; open(sys.argv[1],'w').write(sys.argv[2])",
            _dir + "/" + activeName + ".json",
            JSON.stringify(d)
        ]
        _saveProc.running = false
        _saveProc.running = true
    }

    property var _saveProc: Process {
        command: ["true"]
        running: false
    }

    function createPlaylist(name) {
        if (name === "" || playlistNames.indexOf(name) >= 0) return
        var names = playlistNames.slice()
        names.push(name)
        playlistNames = names
        activeName    = name
        entries       = []
        intervalMode  = "fixed"
        interval      = 300
        shuffle       = false
        screenMode    = "both"
        _savePlaylist()
    }

    function deletePlaylist(name) {
        _delProc.command = ["rm", "-f", _dir + "/" + name + ".json"]
        _delProc.running = false
        _delProc.running = true
        var names = playlistNames.filter(function(n) { return n !== name })
        playlistNames = names
        if (activeName === name) {
            activeName = names.length > 0 ? names[0] : ""
            if (activeName !== "") loadPlaylist(activeName)
            else { entries = []; intervalMode = "fixed"; interval = 300; shuffle = false; screenMode = "both" }
        }
    }

    property var _delProc: Process {
        command: ["true"]
        running: false
    }
}
