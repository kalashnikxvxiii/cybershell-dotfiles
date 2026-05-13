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
        if (shuffle) currentIndex = Math.floor(Math.random() * entries.length)
        isPlaying = true
    }

    function pause() {
        isPlaying = false
        _advanceTimer.stop()
    }

    function stop() {
        isPlaying = false
        currentIndex = 0
        _advanceTimer.stop()
    }

    function _isWpe(path) {
        return path.indexOf("/steamcmd-isolated/.steam/SteamApps/workshop") !== -1
    }

    function _ts() {
        var d = new Date()
        return ("0"+d.getHours()).slice(-2) + ":" +
                ("0"+d.getMinutes()).slice(-2) + ":" +
                ("0"+d.getSeconds()).slice(-2) + "." +
                ("00"+d.getMilliseconds()).slice(-3)
    }

    function _applyToScreens(screensList, entriesByScreen) {
        // Sort screens by type (WPE vs static)
        var wpeArgs = []
        var staticUpdates = []
        var wpeUpdates = []
        var newKind = Object.assign({}, _screenKind)

        // Phase 1 - classify
        for (var i = 0; i < screensList.length; i++) {
            var sn = screensList[i]
            var entry = entriesByScreen[sn]
            var p = entry.path

            if (_isWpe(p)) {
                wpeArgs.push(sn + ":" + p)
                wpeUpdates.push({ screen: sn, preview: entry.thumb || "" })
                newKind[sn] = "wpe"
            } else {
                staticUpdates.push({ screen: sn, path: p })
                newKind[sn] = "static"
            }
        }

        // Phase 2 - plugin static
        for (var s = 0; s < staticUpdates.length; s++) {
            WallpaperState.setScreenWallpaper(staticUpdates[s].screen, staticUpdates[s].path)
            WallpaperState.setScreenKind(staticUpdates[s].screen, "static")
        }

        // Phase 3 - plugin = preview WPE (loading state, replace the old "" transparent)
        for (var c = 0; c < wpeUpdates.length; c++) {
            WallpaperState.setScreenWallpaper(wpeUpdates[c].screen, wpeUpdates[c].preview)
            WallpaperState.setScreenKind(wpeUpdates[c].screen, "wpe")
        }

        // Phase 4 - kill any lingering linux-wallpaperengine on screens going to static
        if (staticUpdates.length > 0) {
            for (var k = 0; k < staticUpdates.length; k++) {
                var sn2 = staticUpdates[k].screen
                Quickshell.execDetached(["rm", "-f",
                    "/home/kalashnikxv/.cache/wallpaper-themer/pid_" + sn2])
                Quickshell.execDetached(["pkill", "-9", "-f",
                    "linux-wallpaperengine.*--screen-root " + sn2])
            }
        }

        // Phase 5 - spawn script for WPE screens
        if (wpeArgs.length > 0) {
            var cmd = ["/home/kalashnikxv/.config/hypr/scripts/wallpaper-themer.sh", "playlist-apply"]
            for (var c2 = 0; c2 < wpeArgs.length; c2++) cmd.push(wpeArgs[c2])
            Quickshell.execDetached(cmd)
        }

        _screenKind = newKind
        console.log("[playlist] _applyToScreens DONE - WallpaperState.screenKind=",
                    JSON.stringify(WallpaperState.screenKind))
    }

    function next() {
        if (entries.length === 0) return

        var entriesByScreen = ({})
        var screensList = []
        var indep = (screenMode === "both" && !sync && Quickshell.screens.length > 1)

        if (indep) {
            // Independent: each screen has its own path
            var newIndexes = ({})
            for (var i = 0; i < Quickshell.screens.length; i++) {
                var sn = Quickshell.screens[i].name
                var prev = _screenIndexes[sn] !== undefined ? _screenIndexes[sn] : -1
                var idx = shuffle
                        ? Math.floor(Math.random() * entries.length)
                        : (prev + 1) % entries.length
                newIndexes[sn] = idx
                entriesByScreen[sn] = entries[idx]
                screensList.push(sn)
            }
            _screenIndexes = newIndexes
        } else {
            //Sync: same path to all the target screens
            if (shuffle)
                currentIndex = Math.floor(Math.random() * entries.length)
            else
                currentIndex = (currentIndex + 1) % entries.length
            var entry = entries[currentIndex]
            for (var i = 0; i < Quickshell.screens.length; i++) {
                var sn = Quickshell.screens[i].name
                if (screenMode === "both" || screenMode === sn) {
                    entriesByScreen[sn] = entry
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
        if (entries.length === 0) return
        currentIndex = (currentIndex - 1 + entries.length) % entries.length
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
        console.log("[playlist] onIsPLayingChanged fired, isPlaying=", isPlaying)
        if (isPlaying) _applyCurrentEntry()
        else _advanceTimer.stop()
        _savePlaybackState()
    }

    onCurrentIndexChanged: _savePlaybackState()

    function _applyCurrentEntry() {
        console.log("[playlist] _applyCurrentEntry called, currentIndex=", currentIndex,
                    "entries.length=", entries.length, "isPlaying=", isPlaying,
                    "screenMode=", screenMode)
        if (currentIndex < 0 || currentIndex >= entries.length) return

        var entry = entries[currentIndex]
        var entriesByScreen = ({})
        var screensList = []
        
        for (var i = 0; i < Quickshell.screens.length; i++) {
            var sn = Quickshell.screens[i].name
            console.log("[playlist]     screen", sn, "match?",
                        (screenMode === "both" || screenMode === sn))
            if (screenMode === "both" || screenMode === sn) {
                entriesByScreen[sn] = entry
                screensList.push(sn)
            }
        }

        console.log("[playlist] _applyCurrentEntry screensList=", JSON.stringify(screensList))

        if (screensList.length > 0) _applyToScreens(screensList, entriesByScreen)

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
        var d = { playing: isPlaying, index: currentIndex }
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
                console.log("[playlist] _readPlaybackProc.onRead raw data:", data)
                try {
                    var d = JSON.parse(data.trim())
                    console.log("[playlist] parsed playback:", JSON.stringify(d), "entries.length=", root.entries.length)
                    if (typeof d.index === "number" && d.index >= 0 && d.index < root.entries.length) {
                        root.currentIndex = d.index
                        console.log("[playlist] currentIndex restored to", d.index)
                    } else {
                        console.log("[playlist] index NOT restored, condition failed (d.index=", d.index, "entries.length=", root.entries.length, ")")
                    }
                    if (d.playing === true) {
                        root.isPlaying = true
                        console.log("[playlist] isPlaying restored to true")
                    }
                } catch(e) {
                    console.log("[playlist] parse error:", e)
                }
            }
        }
    }

    Component.onCompleted: {
        console.log("[playlist] Component.onCompleted, isPlaying=", isPlaying)
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
                console.log("[playlist] _readFile loaded, entries.length=", root.entries.length,
                            "_playbackRestored=", root._playbackRestored)
                if (!root._playbackRestored) {
                    root._playbackRestored = true
                    _readPlaybackProc.command = ["bash", "-c", "cat '" + _dir + "/.playback' 2>/dev/null"]
                    _readPlaybackProc.running = false
                    _readPlaybackProc.running = true
                }
            } catch(e) {
                console.log("[playlist] _readFile parse error:", e)
            }
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
