import "../../common/Colors.js" as CP
import "./WallpaperConst.js" as WC
import "../../common/effects"
import "../../common"
import Quickshell.Wayland
import Quickshell.Io
import Quickshell
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick

Scope {
    id: root

    readonly property string scriptsDir: "/home/kalashnikxv/.config/quickshell/scripts"
    readonly property string themerDir: "/home/kalashnikxv/.config/hypr/scripts"
    readonly property bool isActiveScreen:
        WallpaperState.pickerOpen && screen.name === WallpaperState.activeScreen
    
    required property var screen

    property string _pendingDownloadTitle:  ""
    property string _playlistPreviewPath:   ""
    property string localFilterKeywords:    ""
    property string _pendingDownloadUrl:    ""
    property string originalWallpaper:      ""
    property string downloadingTitle:       ""
    property string _searchFileSize:        ""
    property string downloadingUrl:         ""
    property string _currentSize:           ""
    property string _currentRes:            ""
    property bool   searchPreviewLoading:   false
    property bool   wpePreviewActive:       false
    property bool   deleteDialogOpen:       false
    property bool   previewShown:           false
    property bool   downloading:            false
    property bool   _skipInit:              false
    property real   downloadProgress:       0
    property var    searchResultsModel:     null
    property var    localBasenames:         ({})
    property var    allEntries:             []
    property var    favorites:              ({})
    property int    _carouselPreviewIdx:    -1
    property int    _searchPreviewIdx:      -1
    property int    _previewMsgIdx:         0
    property int    downloadCount:          0
    property int    favCount:               0

    ListModel { id: wallpaperModel }

    Process {
        id: searchPreviewProc
        command: ["true"]
        running: false
        onRunningChanged: if (!running) root.searchPreviewLoading = false
    }

    Process {
        id: searchSizeProc
        command: ["true"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var bytes = parseInt(data.trim())
                root._searchFileSize = isNaN(bytes) ? "" : root.formatSize(bytes)
            }
        }
    }

    Process {
        id: sizeProc
        command: ["true"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var bytes = parseInt(data.trim())
                root._currentSize = isNaN(bytes) ? "" : root.formatSize(bytes)
            }
        }
    }

    function formatSize(bytes) {
        if (!bytes || bytes <= 0) return ""
        if (bytes >= 1073741824) return (bytes / 1073741824).toFixed(1) + " GB"
        if (bytes >= 1048576) return (bytes / 1048576).toFixed(1) + " MB"
        return Math.round(bytes / 1024) + " KB"
    }

    function updateCurrentSize() {
        var idx = carousel.currentIndex
        if (idx < 0 || idx >= wallpaperModel.count) {
            _currentSize = ""
            return
        }
        var entry = wallpaperModel.get(idx)
        if (entry.source === "wpe" && entry.videoFile !== "") {
            sizeProc.command = ["bash", "-c",
                "stat -c%s '" + entry.videoFile + "' 2>/dev/null"]
        } else if (entry.source === "wpe") {
            sizeProc.command = ["bash", "-c",
                "du -sb '" + entry.path + "' 2>/dev/null | awk '{print $1}'"]
        } else {
            sizeProc.command = ["bash", "-c",
                "stat -c%s '" + entry.path + "' 2>/dev/null"]
        }
        sizeProc.running = false
        sizeProc.running = true
    }

    Process {
        id: favLoadProc
        command: ["bash", "-c", "cat $HOME/.cache/wallpaper-picker/favorites.json 2>/dev/null || echo '{}'"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.favorites = JSON.parse(data)
                    var c = 0; for (var k in root.favorites) c++
                    root.favCount = c
                } catch(e) {}
            }
        }
    }

    Process {
        id: favSaveProc
        command: ["true"]
        running: false
    }

    function toggleFavorite() {
        var idx = carousel.currentIndex
        if (idx < 0 || idx >= wallpaperModel.count) return
        var path = wallpaperModel.get(idx).path
        var f = root.favorites
        if (f[path]) {
            delete f[path]
        } else {
            f[path] = true
        }
        root.favorites = f
        var c = 0; for (var k in f) c++
        root.favCount = c
        favSaveProc.running = false
        favSaveProc.command = ["bash", "-c",
            "echo '" + JSON.stringify(f).replace(/'/g, "'\\''") + " | ..."]
        favSaveProc.running = true
    }

    Process {
        id: steamAuthProc
        command: ["true"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                if (data.indexOf("Waiting for confirmation") !== -1) {
                    steamAuthDialog.step = "confirming"
                } else if (data.indexOf("Unloading Steam API") !== -1 && steamAuthDialog.step === "confirming") {
                    steamAuthDialog.step = "success"
                } else if (data.indexOf("Invalid Password") !== -1) {
                    steamAuthDialog.step = "error"
                    steamAuthDialog.errorText = "INVALID PASSWORD"
                } else if (data.indexOf("Rate Limit") !== -1) {
                    steamAuthDialog.step = "error"
                    steamAuthDialog.errorText = "RATE LIMITED — WAIT"
                }
            }
        }
    }


    Process {
        id: resProc
        command: ["true"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                root._currentRes = data.trim()
            }
        }
    }

    function updateCurrentRes() {
        var idx = carousel.currentIndex
        if (idx < 0 || idx >= wallpaperModel.count) {
            _currentRes = ""
            return
        }
        var entry = wallpaperModel.get(idx)
        if (entry.source === "wpe" && entry.videoFile !== "") {
            resProc.command = ["bash", "-c",
                "ffprobe -v quiet -show_entries stream=width,height -of csv=p=0 '" +entry.videoFile + "' 2>/dev/null | head -1 | tr ',' 'x'"]
        } else if (entry.source === "wpe") {
            _currentRes = ""
            return
        } else {
            resProc.command = ["bash", "-c",
                "identify -ping -format '%wx%h\\n' '" + entry.path + "' 2>/dev/null | head -1"]
        }
        resProc.running = false
        resProc.running = true
    }

    Process {
        id: catalogProc
        command: ["bash", "-c", root.scriptsDir + "/wallpaper-picker.sh catalog"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                try {
                    var entry = JSON.parse(data)
                    root.allEntries.push(entry)
                    wallpaperModel.append(entry)
                    var bn = entry.path.substring(entry.path.lastIndexOf("/") + 1)
                    var lb = root.localBasenames
                    lb[bn] = true
                    root.localBasenames = lb
                } catch(e) {}
            }
        }
    }

    Connections {
        target: catalogProc
        function onRunningChanged() {
            if (!catalogProc.running)
                root.localBasenames = Object.assign({}, root.localBasenames)
        }
    }

    Process {
        id: bgRefreshProc
        command: ["bash", "-c", root.scriptsDir + "/wallpaper-picker.sh generate > /dev/null"]
        running: false
    }

    Timer {
        id: previewTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (!root.isActiveScreen) return
            var idx = carousel.currentIndex
            if (idx < 0 || idx >= wallpaperModel.count) return
            var entry = wallpaperModel.get(idx)
            root.previewShown = true
            Quickshell.execDetached(["bash", "-c",
                root.scriptsDir + "/wallpaper-picker.sh preview "
                + root.screen.name + " '" + entry.path + "'"])
        }
    }

    Timer {
        id: _panelReadyTimer
        interval: 100
        onTriggered: panelSlider._panelAnim = true
    }

    Timer {
        id: _jumpTimer
        interval: 15
        repeat: true
        
        property int direction:    1
        property int targetIdx:     -1

        onTriggered: {
            if (carousel.currentIndex === targetIdx) {
                stop()
                carousel.fastMode = false
                for (var i = 0; i < repeater.count; i++) {
                    var it = repeater.itemAt(i)
                    if (it) it.animEnabled = true
                }
                carousel.updateCards()
                return
            }
            if (direction > 0) root.nextVisible()
            else root.prevVisible()
        }
    }

    // Find the wallpaperModel index matching a basename or WPE id
    function findLocalIndex(identifier, isWpe) {
        for (var i = 0; i < wallpaperModel.count; i++) {
            var entry = wallpaperModel.get(i)
            if (isWpe) {
                // For WPE, compare the workshop ID (basename of path)
                var entryId = entry.path.substring(entry.path.lastIndexOf("/") + 1)
                if (entry.source === "wpe" && entryId === identifier) return i
            } else {
                // For regular wallpapres, compare the filename
                var entryBn = entry.path.substring(entry.path.lastIndexOf("/") + 1)
                if (entryBn === identifier) return i
            }
        }
        return -1
    }

    function applyWallpaper() {
        var idx = carousel.currentIndex
        if (idx < 0 || idx >= wallpaperModel.count) return
        var card = repeater.itemAt(idx)

        // If search preview is active, download and add to carousel
        if (carousel.searchFocused && carousel.selectedSearchUrl !== "") {
            var sr = filterBar.resultsModel.get(carousel.selectedSearchIdx)
            var dlTitle = sr ? sr.fname : ""
            var dlSource = sr ? sr.source : ""

            // Guard: check if alreay downloaded and navigate to it instead
            var identifier
            var isWpe = (dlSource === "wpe")
            if (isWpe) {
                identifier = carousel.selectedSearchUrl // WPE id
            } else {
                identifier = carousel.selectedSearchUrl.substring(
                    carousel.selectedSearchUrl.lastIndexOf("/") + 1
                )
            }

            if (root.localBasenames[identifier] === true)  {
                var localIdx = root.findLocalIndex(identifier, isWpe)
                if (localIdx >= 0) {
                    // Close search panel, navigate to the existing card
                    filterBar.closeSearch()
                    carousel.searchFocused = false
                    carousel.selectedSearchIdx = -1
                    carousel.selectedSearchUrl = ""
                    carousel.currentIndex = localIdx
                    carousel.updateCards()
                    // Trigger glitch animation on the matched card for visual feedback
                    var matchedCard = repeater.itemAt(localIdx)
                    if (matchedCard && matchedCard.reveal) matchedCard.reveal()
                    return
                }
            }

            downloadAndAdd(carousel.selectedSearchUrl, "", dlTitle, dlSource)
            return
        }

        var entry = wallpaperModel.get(idx)

        // If WPE preview is already active, just adopt the running process
        if (root.wpePreviewActive && entry.source === "wpe") {
            Quickshell.execDetached(["bash", "-c",
                root.themerDir + "/wallpaper-themer.sh adopt-wpe "
                + root.screen.name + " '" + entry.path + "'"])
            root.originalWallpaper = entry.path
            root.previewShown = false
            root.wpePreviewActive = false
            return
        }
        Quickshell.execDetached(["bash", "-c",
            root.themerDir + "/wallpaper-themer.sh set "
            + root.screen.name + " '" + entry.path + "'"])
        root.originalWallpaper = entry.path
        root.previewShown = false
    }

    function restoreWallpaper() {
        if (root.wpePreviewActive) {
            Quickshell.execDetached(["bash", "-c",
                root.scriptsDir + "/wallpaper-picker.sh stop-preview-wpe "
                + root.screen.name])
        }
        if (root.previewShown && root.originalWallpaper) {
            Quickshell.execDetached(["bash", "-c",
                root.themerDir + "/wallpaper-themer.sh set "
                + root.screen.name + " '" + root.originalWallpaper + "'"])
        }
        root.previewShown = false
        root.wpePreviewActive = false
        _playlistPreviewPath = ""
    }

    Process {
        id: downloadProc
        command: ["bash", "-c", "true"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                if (data.startsWith("ERROR:")) {
                    root.downloading = false
                    root.downloadProgress = 0
                    if (data === "ERROR:STEAM_AUTH") {
                        root._pendingDownloadUrl = root.downloadingUrl
                        root._pendingDownloadTitle = root.downloadingTitle
                        root.downloadingUrl = ""
                        steamAuthDialog.step = "password"
                        steamAuthDialog.open = true
                    } else {
                        root.downloadingUrl = ""
                    }
                    return
                }

                if (data.startsWith("PROGRESS:")) {
                    root.downloadProgress = parseInt(data.substring(9)) / 100
                } else if (data.startsWith("SAVED_WPE:")) {
                    var wpeParts = data.substring(10).split("|")
                    var wpePath = wpeParts[0]
                    var wpeType = wpeParts.length >= 2 ? wpeParts[1] : "scene"
                    var wpeVideoFile = wpeParts.length >= 3 ? wpeParts[2] : ""
                    var wpeThumb = wpeParts.length >= 4 ? wpeParts[3] : wpePath + "/preview.jpg"
                    // Read title from project.json
                    root._skipInit = true
                    var wpeId = wpePath.substring(wpePath.lastIndexOf("/") + 1)
                    wallpaperModel.append({
                        path: wpePath,
                        thumb: wpePath,
                        title: root.downloadingTitle || wpeId,
                        source: "wpe",
                        type: wpeType,
                        color: "#888888",
                        videoFile: wpeVideoFile
                    })
                    root._skipInit = false
                    for (var i = 0; i < repeater.count; i++) {
                        var it = repeater.itemAt(i)
                        if (it) it.animEnabled = false
                    }
                    carousel.updateCards()
                    for (var i = 0; i < repeater.count; i++) {
                        var it = repeater.itemAt(i)
                        if (it) it.animEnabled = true
                    }
                    root.downloading = false
                    root.downloadProgress = 0
                    root.downloadingUrl = ""
                    root.downloadCount++
                    completionGlitch.start()
                    // Regenerate catalog in background so new WPE persists
                    bgRefreshProc.running = true
                } else if (data.startsWith("SAVED:")) {
                    var savedPath = data.substring(6)
                    // Add to catalog and carousel
                    var fname = savedPath.substring(savedPath.lastIndexOf("/") + 1)
                    var title = root.downloadingTitle !== ""
                                ? root.downloadingTitle
                                : fname.substring(0, fname.lastIndexOf("."))
                    root._skipInit = true
                    wallpaperModel.append({
                        path: savedPath,
                        thumb: savedPath,
                        title: title,
                        source: "awww",
                        type: "image",
                        color: "#888888",
                        videoFile: ""
                    })
                    root._skipInit = false
                    for (var i = 0; i < repeater.count; i++) {
                        var it = repeater.itemAt(i)
                        if (it) it.animEnabled = false
                    }
                    carousel.updateCards()
                    for (var i = 0; i < repeater.count; i++) {
                        var it = repeater.itemAt(i)
                        if (it) it.animEnabled = true
                    }
                    var bn = savedPath.substring(savedPath.lastIndexOf("/") + 1)
                    var lb = root.localBasenames
                    lb[bn] = true
                    root.localBasenames = lb
                    root.downloadCount++
                    if (root.downloadingTitle !== "") {
                        var bn = savedPath.substring(savedPath.lastIndexOf("/") + 1)
                        var metaKey = bn.substring(0, bn.lastIndexOf("."))
                        metadataProc.command = ["bash", "-c",
                            "jq --arg k '" + metaKey + "' --arg v '" + root.downloadingTitle.replace(/'/g, "'\\''") + "' '. + {($k): $v}' " +
                            "\"$HOME/.cache/wallpaper-picker/metadata.json\" > /tmp/meta_tmp.json && " +
                            "mv /tmp/meta_tmp.json \"$HOME/.cache/wallpaper-picker/metadata.json\""]
                        metadataProc.running = true
                    }
                    root.downloading = false
                    completionGlitch.start()
                    root.downloadProgress = 0
                    root.downloadingUrl = ""
                }
            }
        }
    }

    function downloadAndAdd(url, thumbPath, title, source) {
        root.downloadingTitle   = title || ""
        root.downloadProgress   = 0
        root.downloadingUrl     = url
        root.downloading        = true

        if (source === "wpe") {
            downloadProc.command = ["bash", "-c",
                "REAL_HOME=\"$HOME\"; " +
                "printf 'PROGRESS:10\\n'; " +
                "HOME=$REAL_HOME/.config/steamcmd-isolated steamcmd +login banditobad " +
                "+workshop_download_item 431960 " + url + " +quit > /tmp/steamcmd_out.txt 2>&1; " +
                "if grep -q 'Invalid Password\\|Cached credentials not found\\|Steam Guard\\|Two-factor' /tmp/steamcmd_out.txt; then " +
                "  printf 'ERROR:STEAM_AUTH\\n'; exit 1; fi; " +
                "if ! grep -q 'Success. Downloaded' /tmp/steamcmd_out.txt; then " +
                "  printf 'ERROR:STEAM_FAIL\\n'; exit 1; fi; " +
                "printf 'PROGRESS:100\\n'; " +
                "WPE_DIR=\"$REAL_HOME/.config/steamcmd-isolated/.steam/SteamApps/workshop/content/431960/" + url + "\"; " +
                "if [ -d \"$WPE_DIR\" ] && [ -f \"$WPE_DIR/project.json\" ]; then " +
                "  TYPE=$(jq -r '.type // \"scene\"' \"$WPE_DIR/project.json\" 2>/dev/null | tr '[:upper:]' '[:lower:]'); " +
                "  VFILE=''; " +
                "  if [ \"$TYPE\" = \"video\" ]; then " +
                "    VFILE=$(jq -r '.file // \"\"' \"$WPE_DIR/project.json\" 2>/dev/null); " +
                "    [ -n \"$VFILE\" ] && VFILE=\"$WPE_DIR/$VFILE\"; " +
                "  fi; " +
                "  THUMB=\"$REAL_HOME/.cache/wallpaper-picker/thumbs/" + url + ".jpg\"; " +
                "  PREV=$(find \"$WPE_DIR\" -name 'preview.*' -type f 2>/dev/null | head -1); " +
                "  [ -n \"$PREV\" ] && { magick \"${PREV}[0]\" -resize x420 -quality 70 \"$THUMB\" 2>/dev/null || " +
                "    ffmpeg -y -i \"$PREV\" -vframes 1 -q:v 2 -vf 'scale=-1:420' \"$THUMB\" 2>/dev/null; }; " +
                "  printf 'SAVED_WPE:%s|%s|%s|%s\\n' \"$WPE_DIR\" \"$TYPE\" \"$VFILE\" \"$THUMB\"; " +
                "fi"]
            downloadProc.running = true
            return
        }
        downloadProc.command    = ["bash", "-c",
            "URL='" + url + "'; " +
            "DEST=\"$HOME/Pictures/wallpapers/$(basename \"$URL\")\"; " +
            "SIZE=$(curl -sI -L --max-time 10 \"$URL\" | grep -i content-length | tail -1 | awk '{print $2}' | tr -d '\\r'); " +
            "curl -sL --max-time 30 -o \"$DEST\" \"$URL\" & PID=$!; " +
            "while kill -0 $PID 2>/dev/null; do "+
            "  if [ -f \"$DEST\" ] && [ -n \"$SIZE\" ] && [ \"$SIZE\" -gt 0 ]; then " +
            "    CUR=$(stat -c%s \"$DEST\" 2>/dev/null || echo 0); " +
            "    echo \"PROGRESS:$((CUR * 100 / SIZE))\"; " +
            "  fi; " +
            "  sleep 0.2; " +
            "done; " +
            "wait $PID && echo \"SAVED:$DEST\""]
        downloadProc.running = true
    }

    Process {
        id: deleteProc
        command: ["true"]
        running: false
    }

    Process {
        id: metadataProc
        command: ["true"]
        running: false
    }

    function deleteCurrentWallpaper() {
        var idx = carousel.currentIndex
        if (idx < 0 || idx >= wallpaperModel.count) return
        var entry = wallpaperModel.get(idx)
        var path = entry.path

        // Remove file
        deleteProc.command = ["rm", "-rf", path]
        deleteProc.running = true

        // Remove from model
        root._skipInit = true
        wallpaperModel.remove(idx)
        root._skipInit = false
        
        // Remove from localBasenames
        var bn = path.substring(path.lastIndexOf("/") + 1)
        var lb = root.localBasenames
        delete lb[bn]
        root.localBasenames = lb

        // Snap index
        if (carousel.currentIndex >= wallpaperModel.count)
            carousel.currentIndex = wallpaperModel.count - 1
        carousel.updateCards()

        // Regenerate catalog to persist deletion
        bgRefreshProc.running = true

        root.deleteDialogOpen = false
    }

    function currentVisiblePosition() {
        var pos = 0
        for (var i = 0; i <= carousel.currentIndex && i < wallpaperModel.count; i++) {
            if (WallpaperState.matchesFilter(wallpaperModel.get(i))) pos++
        }
        return pos
    }

    function jumpToFraction(n) {
        // n in [0..9] -> fractionary position in the visible list
        var vis = []
        var count = wallpaperModel.count
        for (var i = 0; i < count; i++) {
            var entry = wallpaperModel.get(i)
            if (!WallpaperState.matchesFilter(entry)) continue
            if (filterBar.favoritesOnly && root.favorites[entry.path] !== true) continue
            if (root.localFilterKeywords !== "") {
                var kws = root.localFilterKeywords.toLowerCase().split(" ")
                var t = entry.title.toLowerCase()
                var ok = true
                for (var k = 0; k < kws.length; k++) {
                    if (kws[k] !== "" && t.indexOf(kws[k]) === -1) { ok = false; break }
                }
                if (!ok) continue
            }
            vis.push(i)
        }
        if (vis.length === 0) return

        var targetVisIdx = Math.max(0, Math.min(vis.length - 1, Math.floor((n / 9) * (vis.length - 1))))
        var targetIdx = vis[targetVisIdx]
        if (targetIdx === carousel.currentIndex) return

        var curVisIdx = vis.indexOf(carousel.currentIndex)
        if (curVisIdx === -1) {
            carousel.currentIndex = targetIdx
            carousel.updateCards()
            return
        }

        var rightSteps = (targetVisIdx - curVisIdx + vis.length) % vis.length
        var leftSteps = (curVisIdx - targetVisIdx + vis.length) % vis.length

        // Active fastMode smooth scroll
        if (!carousel.fastMode) {
            carousel.fastMode = true
            for (var i = 0; i < repeater.count; i++) {
                var it = repeater.itemAt(i)
                if (it) it.animEnabled = false
            }
        }

        _jumpTimer.targetIdx = targetIdx
        _jumpTimer.direction = rightSteps <= leftSteps ? 1 : -1
        _jumpTimer.start()
    }

    function nextVisible() {
        var count = wallpaperModel.count
        if (count === 0) return
        var idx = carousel.currentIndex
        for (var i = 0; i < count; i++) {
            idx = (idx + 1) % count
            var entry = wallpaperModel.get(idx)
            if (WallpaperState.matchesFilter(entry)
                && (!filterBar.favoritesOnly || root.favorites[entry.path] === true)
                && (root.localFilterKeywords === "" || (function() {
                    var kws = root.localFilterKeywords.toLowerCase().split(" ")
                    var t = entry.title.toLowerCase()
                    for (var k = 0; k < kws.length; k++) {
                        if (kws[k] !== "" && t.indexOf(kws[k]) === -1) return false
                    }
                    return true
                })())) {
                carousel.currentIndex = idx
                carousel.updateCards()
                return
            }
        }
    }

    function prevVisible() {
        var count = wallpaperModel.count
        if (count === 0) return
        var idx = carousel.currentIndex
        for (var i = 0; i < count; i++) {
            idx = (idx - 1 + count) % count
            var entry = wallpaperModel.get(idx)
            if (WallpaperState.matchesFilter(entry)
                && (!filterBar.favoritesOnly || root.favorites[entry.path] === true)
                && (root.localFilterKeywords === "" || (function() {
                    var kws = root.localFilterKeywords.toLowerCase().split(" ")
                    var t = entry.title.toLowerCase()
                    for (var k = 0; k < kws.length; k++) {
                        if (kws[k] !== "" && t.indexOf(kws[k]) === -1) return false
                    }
                    return true
                })())) {
                carousel.currentIndex = idx
                carousel.updateCards()
                return
            }
        }
    }

    function updateSearchPreview(thumbPath, fullUrl) {
        var isGif = fullUrl.toLowerCase().endsWith(".gif")
        var isWpe = /^\d+$/.test(fullUrl)
        // Thumbnail locale subito (instant)
        searchPreviewThumb.source = thumbPath ? "file://" + thumbPath : ""
        // Full-res in background (skip for WPE IDs - thumbnail is all we have)
        if (isWpe) {
            searchPreviewImage.source = ""
            var gifPath = thumbPath.replace(".jpg", ".gif")
            searchPreviewGif.source = gifPath ? "file://" + gifPath : ""
        } else if (isGif) {
            searchPreviewImage.source = ""
            searchPreviewGif.source = fullUrl
        } else {
            searchPreviewGif.source = ""
            searchPreviewImage.source = fullUrl ? fullUrl : ""
        }
    }

    onIsActiveScreenChanged: {
        if (isActiveScreen) {
            originalWpReader.path = "/home/kalashnikxv/.cache/wallpaper-themer/current_" + screen.name
            originalWpReader.reload()
            allEntries = []
            wallpaperModel.clear()
            carousel.currentIndex = 0
            catalogProc.running = true
            favLoadProc.running = true
            filterBar.favoritesOnly = false
            // Refresh cache in background for next open
            bgRefreshProc.running = true
            WallpaperState.resetFilters()
            root.previewShown = false
            panelSlider._panelAnim = false
            PlaylistState.panelOpen = false
            _panelReadyTimer.restart()
        } else {
            // Stop all video/audio on close
            carousel.audioEnabled = false
            for (var i = 0; i < repeater.count; i++) {
                var item = repeater.itemAt(i)
                if (item) item.videoPlaying = false
            }
        }
    }

    FileView {
        id: originalWpReader
        path: ""
        onLoaded: root.originalWallpaper = text().trim()
    }

    PanelWindow {
        id: win

        screen: root.screen
        WlrLayershell.namespace: "wallpaper-picker"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.isActiveScreen
            ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        color: "transparent"
        visible: root.isActiveScreen

        MouseArea {
            id: hoverTracker
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        Item {
            id: mainLayout
            anchors.fill: parent
            focus: true
            opacity: root.previewShown && !_hoveringElement ? 0.2 : 1.0

            Behavior on opacity { NumberAnimation { duration: 300 } }

            property real _mx: hoverTracker.mouseX
            property real _my: hoverTracker.mouseY
            property bool _hoveringElement: {
                if (!hoverTracker.containsMouse) return false
                var mx = _mx
                var my = _my
                var items = [
                    filterBar,
                    carousel,
                    infoBar,
                    searchResultsPanel,
                    searchPreviewCard,
                    deleteDialog,
                    panelSlider
                ]
                for (var i = 0; i < items.length; i++) {
                    var item = items[i]
                    if (!item.visible) continue
                    var p = mapToItem(item, mx, my)
                    if (p.x >= 0 && p.x <= item.width && p.y >=0 && p.y <= item.height)
                        return true
                }
                return false
            }

            WallpaperFilterBar {
                id: filterBar
                anchors.top: parent.top
                anchors.topMargin: root.isActiveScreen ? 230 : -100
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, parent.width - 80)

                favCount: root.favCount

                Behavior on anchors.topMargin {
                    NumberAnimation { duration: 600; easing.type: Easing.OutExpo }
                }
            }

            Item {
                id: fractionBar
                anchors.top: filterBar.bottom
                anchors.topMargin: 8
                anchors.horizontalCenter: filterBar.horizontalCenter
                width: filterBar.width - 40
                height: 16
                visible: filterBar.visible && carousel.visibleCount > 0

                readonly property int currentFraction: {
                    var pos = root.currentVisiblePosition()
                    var total = carousel.visibleCount
                    if (total <= 1) return 0
                    return Math.max(0, Math.min(9, Math.round(((pos - 1) / (total - 1)) * 9)))
                }

                Repeater {
                    model: 10
                    delegate: Item {
                        required property int index
                        width: fractionBar.width / 10
                        height: fractionBar.height
                        x: index * width

                        readonly property bool active: index === fractionBar.currentFraction

                        CutShape {
                            anchors.centerIn: parent
                            width: active ? 12 : 5
                            height: active ? 12 : 5
                            fillColor: active ? CP.cyan : CP.alpha(CP.cyan, 0.3)
                            strokeColor: active ? CP.alpha(CP.cyan, 0.9) : "transparent"
                            strokeWidth: 1; inset: 0.5
                            cutTopLeft: 2; cutBottomRight: 2

                            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                            Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                            Behavior on fillColor { ColorAnimation { duration: 220 } }
                            Behavior on strokeColor { ColorAnimation { duration: 220 } }
                        }
                    }
                }
            }

            // ── Carousel ────────────────────────────────────────
            Item {
                id: carousel
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                height: 460
                clip: true

                readonly property real  cardSpacing:        -12
                property string         selectedSearchUrl:  ""
                property bool           searchFocused:      false
                property bool           audioEnabled:       false
                property bool           fastMode:           false
                property real           savedVolume:        0.5
                property int            selectedSearchIdx:  -1
                property int            currentIndex:       0
                property int            visibleCount:       0
                property int            rapidCount:         0

                onCurrentIndexChanged: {
                    metaUpdateTimer.restart()
                }


                onSelectedSearchIdxChanged: {
                    if (selectedSearchIdx >= 0 && filterBar.resultsModel && filterBar.resultsModel.count > 0) {
                        searchResultsPanel.positionAtIndex(selectedSearchIdx)
                        // Load more when near the end
                        if (selectedSearchIdx >= filterBar.resultsModel.count - 3) {
                            filterBar.loadMoreResults()
                        }
                        var sr = filterBar.resultsModel.get(selectedSearchIdx)
                        if (sr.fileSize > 0) {
                            root._searchFileSize = root.formatSize(sr.fileSize)
                        } else {
                            var bn = sr.fullUrl.substring(sr.fullUrl.lastIndexOf("/") + 1)
                            if (root.localBasenames[bn] === true) {
                                searchSizeProc.command = ["bash", "-c",
                                    "stat -c%s \"$HOME/Pictures/wallpapers/" + bn + "\" 2>/dev/null"]
                                searchSizeProc.running = true
                            } else if (sr.source !== "wpe" && sr.fullUrl.startsWith("http")) {
                                searchSizeProc.command = ["bash", "-c",
                                    "curl -sIL --max-time 5 '" + sr.fullUrl + "' 2>/dev/null | grep -i '^content-length:' | tail -1 | awk '{print $2}' | tr -d '\\r'"]
                                searchSizeProc.running = true
                            } else if (sr.source === "wpe") {
                                searchSizeProc.command = ["bash", "-c",
                                    "curl -s --max-time 10 -X POST " +
                                    "'https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/' " +
                                    "-d 'itemcount=1&publishedfileids[0]=" + sr.fullUrl + "' 2>/dev/null | " +
                                    "python3 -c \"import sys,json; d=json.load(sys.stdin); " +
                                    "print(d['response']['publishedfiledetails'][0].get('file_size','0'))\" 2>/dev/null"]
                                searchSizeProc.running = true
                            } else {
                                root._searchFileSize = ""
                            }
                        }
                    } else {
                        root._searchFileSize = ""
                    }
                }

                Timer {
                    id: fastModeTimer
                    interval: 400
                    onTriggered: {
                        if (!carousel.fastMode) return
                        carousel.fastMode = false
                        carousel.rapidCount = 0
                        carousel.updateCards()
                    }
                }

                function widthForDist(dist) {
                    if (dist === 0) return 600
                    return Math.max(40, 200 - dist * 22)
                }

                function heightForDist(dist) {
                    if (dist === 0) return 450
                    return Math.max(160, 420 - dist * 28)
                }

                function centerXFor(idx) {
                    var center = width / 2 + 40
                    if (idx === currentIndex) return center

                    var dir = idx > currentIndex ? 1 : -1
                    var pos = center

                    for (var i = currentIndex; i !== idx; i += dir) {
                        var d1 = Math.abs(i - currentIndex)
                        var d2 = d1 + 1
                        var w1 = widthForDist(d1)
                        var w2 = widthForDist(d2)
                        pos += dir * (w1 / 2 + cardSpacing + w2 / 2)
                    }

                    return pos
                }

                function updateCardsFast() {
                    var count = repeater.count
                    if (count === 0) return

                    // Build visible indices
                    var vis = []
                    for (var i = 0; i < count; i++) {
                        var it = repeater.itemAt(i)
                        if (it && it.isVisible) vis.push(i)
                    }
                    visibleCount = vis.length
                    if (vis.length === 0) return

                    // Snap currentIndex
                    if (vis.indexOf(currentIndex) === -1) {
                        var best = vis[0]
                        for (var j = 1; j < vis.length; j++) {
                            if (Math.abs(vis[j] - currentIndex) < Math.abs(best - currentIndex))
                                best = vis[j]
                        }
                        currentIndex = best
                    }

                    var sp = 3
                    var cardW = 120
                    var cardH = Math.min(220, cardW * 2.2)
                    var curVis = vis.indexOf(currentIndex)
                    var visCount = vis.length

                    // Center current visible card
                    var centerX = width / 2 + 40

                    for (var i = 0; i < count; i++) {
                        var item = repeater.itemAt(i)
                        if (!item) continue

                        var visIdx = vis.indexOf(i)
                        if (visIdx === -1) {
                            item.distFromCurrent = 9999
                            item.cardWidth = 0
                            item.cardHeight = 0
                            item.x = centerX
                            item.isPreload = false
                            continue
                        }

                        // Circular offset: shortest path around the ring
                        var rightDist = (visIdx - curVis + visCount) % visCount
                        var leftDist = (curVis - visIdx + visCount) % visCount
                        var offset = rightDist <= leftDist ? rightDist : -leftDist

                        var circDist = Math.min(rightDist, leftDist)
                        if (circDist > 10) {
                            item.distFromCurrent = 9999
                            item.cardWidth = 0
                            item.cardHeight = 0
                            item.x = centerX
                            continue
                        }
                        item.distFromCurrent = circDist
                        item.isPreload = (circDist > 7)
                        if (item.opacity < 0.5) item.opacity = 1
                        item.cardWidth = cardW
                        item.cardHeight = cardH
                        item.x = centerX - cardW / 2 + offset * (cardW + sp)
                    }
                }

                // ── Imperative card update ──────────────────────
                function updateCards() {
                    if (fastMode) {
                        updateCardsFast()
                        return
                    }
                    
                    var count = repeater.count
                    if (count === 0) return

                    // Build visible indices list
                    var vis = []
                    for (var i = 0; i < count; i++) {
                        var it = repeater.itemAt(i)
                        if (it && it.isVisible) vis.push(i)
                    }
                    visibleCount = vis.length
                    if (vis.length === 0) return

                    // Snap currentIndex to nearest visible if needed
                    if (vis.indexOf(currentIndex) === -1) {
                        var best = vis[0]
                        for (var j = 1; j < vis.length; j++) {
                            if (Math.abs(vis[j] - currentIndex) < Math.abs(best - currentIndex))
                                best = vis[j]
                        }
                        currentIndex = best
                    }

                    var curVis = vis.indexOf(currentIndex)
                    var visCount = vis.length
                    var center = width / 2 + 40
                    var halfCount = Math.min(Math.floor(visCount / 2), 10)

                    // Calculate center X for each visible card
                    var centers = {}
                    var cardDists = {}

                    centers[vis[curVis]] = center
                    cardDists[vis[curVis]] = 0

                    // Walk right from current
                    var posRight = center
                    var posLeft = center

                    for (var d = 1; d <= halfCount; d++) {
                        // Right
                        var rIdx = (curVis + d) % visCount
                        var w1 = widthForDist(d - 1)
                        var w2 = widthForDist(d)
                        posRight += w1 / 2 + cardSpacing + w2 / 2
                        centers[vis[rIdx]] = posRight
                        cardDists[vis[rIdx]] = d

                        // Left (skip if same as right - even count, halfway point)
                        if (d < visCount - d) {
                            var lIdx = (curVis - d + visCount) % visCount
                            posLeft -= w1 / 2 + cardSpacing + w2 / 2
                            centers[vis[lIdx]] = posLeft
                            cardDists[vis[lIdx]] = d
                        }
                    }

                    // Apply positions
                    for (var i = 0; i < count; i++) {
                        var item = repeater.itemAt(i)
                        if (!item) continue

                        if (!item.isVisible || !(i in centers)) {
                            item.distFromCurrent = 9999
                            item.cardWidth = 0
                            item.cardHeight = 0
                            item.x = center
                            item.isPreload = false
                            continue
                        }

                        var dist = cardDists[i]
                        item.distFromCurrent = dist
                        item.isPreload = (dist > 7)
                        if (item.opacity < 0.5) item.opacity = 1
                        var w = widthForDist(dist)
                        var h = heightForDist(dist)
                        var newX = centers[i] - w / 2
                        
                        // Detect wrap-around: card jumping more than viewport width
                        var jump = Math.abs(newX - item.x)
                        if (jump > width) {
                            item.animEnabled = false
                            item.cardWidth = w
                            item.cardHeight = h
                            item.x = newX
                            item.animEnabled = true
                        } else {
                            item.cardWidth = w
                            item.cardHeight = h
                            item.x = newX
                        }
                    }
                }

                // ── Init: position without animation ────────────
                function initCards() {
                    var center = width / 2 + 40

                    // Start on the currently applie wallpaper
                    if (root.originalWallpaper !== "") {
                        for (var j = 0; j < repeater.count; j++) {
                            var e = wallpaperModel.get(j)
                            if (e && e.path === root.originalWallpaper) {
                                currentIndex = j
                                break
                            }
                        }
                    }

                    // Position ALL cards at center, invisible, no animation
                    for (var i = 0; i < repeater.count; i++) {
                        var item = repeater.itemAt(i)
                        if (!item) continue
                        item.animEnabled = false
                        item.cardWidth = 0
                        item.cardHeight = 0
                        item.x = center
                        item.opacity = 0
                    }

                    // Show current card immediately at full size
                    var curItem = repeater.itemAt(currentIndex)
                    if (curItem) {
                        curItem.cardWidth = widthForDist(0)
                        curItem.cardHeight = heightForDist(0)
                        curItem.x = center - widthForDist(0) / 2
                        curItem.opacity = 1
                        curItem.distFromCurrent = 0
                    }

                    // Schedule reveal
                    revealTimer.restart()
                    root.updateCurrentRes()
                    root.updateCurrentSize()
                }

                function refilterCards() {
                    // Reset to first visible card
                    for (var i = 0; i < repeater.count; i++) {
                        var item = repeater.itemAt(i)
                        if (item) item.animEnabled = false
                        if (item && item.isVisible) {
                            currentIndex = i
                            break
                        }
                    }
                    updateCards()
                    for (var i = 0; i < repeater.count; i++) {
                        var item = repeater.itemAt(i)
                        if (item) item.animEnabled = true
                    }
                }

                Timer {
                    id: initTimer
                    interval: 100
                    repeat: false
                    onTriggered: carousel.initCards()
                }

                Timer {
                    id: revealTimer
                    interval: 200
                    onTriggered: {
                        for (var i = 0; i < repeater.count; i++) {
                            var item = repeater.itemAt(i)
                            if (item) item.animEnabled = true
                        }
                        carousel.updateCards()
                        // Trigger glitch on each card
                        for (var i = 0; i < repeater.count; i++) {
                            var item = repeater.itemAt(i)
                            if (item && item.distFromCurrent <= 7) item.reveal()
                        }
                    }
                }

                Timer {
                    id: metaUpdateTimer
                    interval: 180
                    onTriggered: {
                        root.updateCurrentRes()
                        root.updateCurrentSize()
                    }
                }

                // ── React to filter changes ─────────────────────
                Timer {
                    id: filterUpdateTimer
                    interval: 0
                    onTriggered: carousel.refilterCards()
                }

                Connections {
                    target: WallpaperState
                    function onMacroFilterChanged() { filterUpdateTimer.restart() }
                    function onColorFilterChanged() { filterUpdateTimer.restart() }
                    function onSubFilterChanged()   { filterUpdateTimer.restart() }
                }

                Connections {
                    target: filterBar
                    function onFavoritesOnlyChanged() { filterUpdateTimer.restart() }
                    function onSearchFirstResult() {
                        carousel.searchFocused = true
                        carousel.selectedSearchIdx = 0
                        // Show first result in current card
                        if (filterBar.resultsModel.count > 0) {
                            var sr = filterBar.resultsModel.get(0)
                            if (sr) {
                                root.updateSearchPreview(sr.thumbPath, sr.fullUrl)
                                carousel.selectedSearchUrl = sr.fullUrl
                            }
                        }
                    }
                }

                Connections {
                    target: filterBar
                    function onLocalFilterChanged(keywords) {
                        root.localFilterKeywords = keywords
                        carousel.refilterCards()
                    }
                }

                Connections {
                    target: filterBar
                    function onSearchExpandedChanged() {
                        if (!filterBar.searchExpanded) {
                            carousel.searchFocused = false
                            carousel.selectedSearchIdx = -1
                            carousel.selectedSearchUrl = ""
                        }
                    }
                }

                Repeater {
                    id: repeater
                    model: wallpaperModel
                    onItemAdded: { if (!root._skipInit) initTimer.restart() }

                    delegate: WallpaperCard {
                        y: 0
                        carouselFastMode: carousel.fastMode
                        viewCurrentIndex: carousel.currentIndex
                        viewTotalVisible: carousel.visibleCount
                        isCurrent:  index === carousel.currentIndex
                        isFavorite: { var _fc = root.favCount; return root.favorites[path] === true }
                        videoVolume:    isCurrent && carousel.audioEnabled ? carousel.savedVolume : 0
                        resolution:     isCurrent ? root._currentRes : ""
                        isVisible: {
                            var m = WallpaperState.macroFilter
                            var s = WallpaperState.subFilter
                            var c = WallpaperState.colorFilter
                            if (m === "awww" && source !== "awww") return false
                            if (m === "wpe" && source !== "wpe") return false
                            if (s !== "" && type !== s) return false
                            if (c !== "" && !WallpaperState._colorMatches(color, c)) return false
                            // Local keyword filter
                            if (root.localFilterKeywords !== "") {
                                var kws = root.localFilterKeywords.toLowerCase().split(" ")
                                var t = title.toLowerCase()
                                for (var i = 0; i < kws.length; i++) {
                                    if (kws[i] !== "" && t.indexOf(kws[i]) === -1) return false
                                }
                            }
                            if (filterBar.favoritesOnly && root.favorites[path] !== true) return false
                            return true
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (index === carousel.currentIndex && parent.videoPlaying) {
                                    carousel.audioEnabled = !carousel.audioEnabled
                                    if (carousel.audioEnabled && carousel.savedVolume <= 0)
                                        carousel.savedVolume = 0.5
                                } else {
                                    carousel.currentIndex = index
                                    carousel.updateCards()
                                }
                            }
                            onDoubleClicked: root.applyWallpaper()
                            onWheel: wheel => {
                                if (index === carousel.currentIndex && parent.videoPlaying) {
                                    var delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                                    carousel.savedVolume = Math.max(0.01, Math.min(1, carousel.savedVolume + delta))
                                    carousel.audioEnabled = true
                                }
                            }
                        }
                    }
                }
            }

            // ── Search preview card (dedicated, not part of carousel) ──────────────
            Item {
                id: searchPreviewCard
                anchors.verticalCenter: carousel.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: 40
                width: 600
                height: 450
                z: 200
                visible: carousel.searchFocused && carousel.selectedSearchIdx >= 0

                transform: Matrix4x4 {
                    matrix: Qt.matrix4x4(
                        1, Math.tan(-10 * Math.PI / 180), 0, 0,
                        0, 1, 0, 0,
                        0, 0, 1, 0,
                        0, 0, 0, 1
                    )
                }

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: searchPreviewMask
                    maskThresholdMin: 0.5
                }

                Rectangle {
                    anchors.fill: parent
                    color: "#0a060e"
                }

                Image {
                    id: searchPreviewThumb
                    anchors.fill: parent
                    source: ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: searchPreviewImage.status !== Image.Ready
                            && searchPreviewGif.status !== AnimatedImage.Ready
                }

                Image {
                    id: searchPreviewImage
                    anchors.fill: parent
                    source: ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                AnimatedImage {
                    id: searchPreviewGif
                    anchors.fill: parent
                    source: ""
                    fillMode: Image.PreserveAspectCrop
                    playing: true
                    visible: source !== ""
                }

                // ── Resolution overlay ────────────────────────────────────────────
                Item {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 48

                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.4; color: Qt.rgba(0, 0, 0, 0.7) }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.85) }
                        }
                    }

                    Text {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        text: {
                            if (!filterBar.resultsModel || carousel.selectedSearchIdx < 0
                                || carousel.selectedSearchIdx >= filterBar.resultsModel.count)
                                return ""
                            var sr = filterBar.resultsModel.get(carousel.selectedSearchIdx)
                            if (sr.w > 0 && sr.h > 0)
                                return sr.w + "\u00d7" + sr.h
                            return ""
                        }
                        font.family: "Oxanium"
                        font.pixelSize: 13
                        font.letterSpacing: 2
                        color: Colours.textPrimary

                        transform: Matrix4x4 {
                            matrix: Qt.matrix4x4(
                                1, Math.tan(10 * Math.PI / 180), 0, 0,
                                0, 1, 0, 0,
                                0, 0, 1, 0,
                                0, 0, 0, 1
                            )
                        }
                    }
                }

                CutShape {
                    anchors.fill: parent
                    fillColor: "transparent"
                    strokeColor: Colours.accentPrimary
                    strokeWidth: 2
                    inset: 1
                    cutTopLeft: 32
                    cutBottomRight: 32
                }

                // ── Download overlay (preview) ───────────────────────────────────
                Item {
                    id: previewDownloadOverlay
                    anchors.fill: parent
                    visible: root.downloading
                    z: 10

                    // Darken
                    Rectangle {
                        anchors.fill: parent
                        color: CP.alpha(CP.black, 0.45)
                        opacity: root.downloading ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 300 } }
                    }

                    // Scanlines
                    ScanlineOverlay { opacity: 0.1 }

                    // Center column: icon + text + percentage
                    Column {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "\uf019"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 28
                            color: CP.cyan
                            PulseAnim on opacity { running: root.downloading; minOpacity: 0.3; duration: 400 }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "DOWNLOADING"
                            font.family: "Oxanium"
                            font.pixelSize: 10
                            font.letterSpacing: 3
                            color: CP.cyan
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Math.floor(root.downloadProgress * 100) + "%"
                            font.family: "Oxanium"
                            font.pixelSize: 14
                            color: CP.yellow
                        }
                    }

                    // Progress Bar
                    Item {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 4

                        Rectangle {
                            anchors.fill: parent
                            color: CP.alpha(CP.cyan, 0.15)
                        }

                        Rectangle {
                            id: previewProgressBar
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * root.downloadProgress
                            color: CP.cyan

                            SequentialAnimation on color {
                                loops: Animation.Infinite
                                running: root.downloading
                                ColorAnimation { to: CP.cyan; duration: 500 }
                                ColorAnimation { to: CP.magenta; duration: 60 }
                                ColorAnimation { to: CP.yellow; duration: 60 }
                                ColorAnimation { to: CP.cyan; duration: 60 }
                            }
                        }
                    }
                }

                // ── Completion glitch burst ───────────────────────────────
                Rectangle {
                    id: completionFlash
                    anchors.fill: parent
                    color: CP.magenta
                    opacity: 0
                    z: 11

                    SequentialAnimation {
                        id: completionGlitch
                        PropertyAction { target: completionFlash; property: "color"; value: CP.magenta }
                        NumberAnimation { target: completionFlash; property: "opacity"; to: 0.4; duration: 60 }
                        PropertyAction { target: completionFlash; property: "color"; value: CP.cyan }
                        NumberAnimation { target: completionFlash; property: "opacity"; to: 0.2; duration: 60 }
                        NumberAnimation { target: completionFlash; property: "opacity"; to: 0; duration: 180 }
                    }
                }

                // ── Search preview loading overlay ────────────────────────────────
                Item {
                    id: searchPreviewLoadingOverlay
                    anchors.fill: parent
                    visible: root.searchPreviewLoading
                    z: 12

                    onVisibleChanged: {
                        if (visible) {
                            root._previewMsgIdx = 0
                            msgCycleAnim.restart()
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: CP.alpha(CP.void2, 0.78)
                    }

                    ScanlineOverlay { opacity: 0.07 }

                    Column {
                        anchors.centerIn: parent
                        spacing: 16

                        // Stepped spinner: outer static frame + inner rotating ring
                        Item {
                            width: 64; height: 64
                            anchors.horizontalCenter: parent.horizontalCenter

                            CutShape {
                                anchors.fill: parent
                                fillColor: "transparent"
                                strokeColor: CP.alpha(CP.magenta, 0.22)
                                strokeWidth: 1
                                inset: 0.5
                                cutTopLeft: 18; cutTopRight: 18
                                cutBottomLeft: 18; cutBottomRight: 18
                            }

                            CutShape {
                                id: previewSpinRing
                                anchors.fill: parent
                                anchors.margins: 8
                                fillColor: "transparent"
                                strokeColor: CP.magenta
                                strokeWidth: 2
                                inset: 1
                                cutTopLeft: 10; cutTopRight: 10
                                cutBottomLeft: 10; cutBottomRight: 10
                            }

                            SequentialAnimation {
                                loops: Animation.Infinite
                                running: root.searchPreviewLoading
                                PropertyAction { target: previewSpinRing; property: "rotation"; value: 0 }
                                PauseAnimation { duration: 110 }
                                PropertyAction { target: previewSpinRing; property: "rotation"; value: 45 }
                                PauseAnimation { duration: 110 }
                                PropertyAction { target: previewSpinRing; property: "rotation"; value: 90 }
                                PauseAnimation { duration: 110 }
                                PropertyAction { target: previewSpinRing; property: "rotation"; value: 135 }
                                PauseAnimation { duration: 110 }
                                PropertyAction { target: previewSpinRing; property: "rotation"; value: 180 }
                                PauseAnimation { duration: 110 }
                                PropertyAction { target: previewSpinRing; property: "rotation"; value: 225 }
                                PauseAnimation { duration: 110 }
                                PropertyAction { target: previewSpinRing; property: "rotation"; value: 270 }
                                PauseAnimation { duration: 110 }
                                PropertyAction { target: previewSpinRing; property: "rotation"; value: 315 }
                                PauseAnimation { duration: 110 }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "\uf06e"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 22
                                color: CP.magenta
                                PulseAnim on opacity {
                                    running: root.searchPreviewLoading
                                    minOpacity: 0.2
                                    duration: 700
                                }
                            }
                        }

                        // Cycling messages
                        Text {
                            id: previewLoadMsg
                            anchors.horizontalCenter: parent.horizontalCenter

                            property var msgs: [
                                "SCANNING MATRIX...",
                                "INJECTING PIXELS...",
                                "PATCHING RETINAS...",
                                "CALIBRATING OPTICS...",
                                "DECODING AESTHETIC...",
                                "UPLOADING TO CORTEX...",
                                "SYNCING NEURAL MAP...",
                                "RENDERING SCENE..."
                            ]
                            text: msgs[root._previewMsgIdx % msgs.length]
                            font.family: "Oxanium"
                            font.pixelSize: 10
                            font.letterSpacing: 2
                            color: CP.magenta

                            SequentialAnimation {
                                id: msgCycleAnim
                                loops: Animation.Infinite
                                running: root.searchPreviewLoading
                                PauseAnimation  { duration: 1500 }
                                NumberAnimation { target: previewLoadMsg; property: "opacity"; to: 0; duration: 80 }
                                ScriptAction    { script: root._previewMsgIdx++ }
                                NumberAnimation { target: previewLoadMsg; property: "opacity"; to: 1; duration: 80 }
                            }
                        }
                    }
                }

                CutShape {
                    id: searchPreviewMask
                    anchors.fill: parent
                    layer.enabled: true
                    visible: false
                    fillColor: "white"
                    cutTopLeft: 32
                    cutBottomRight: 32
                }
            }

            // Info bar
            Item {
                id: infoBar
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 260
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width - 80, 800)
                height: 32
                visible: carousel.currentIndex >= 0 && carousel.currentIndex < wallpaperModel.count

                CutShape {
                    anchors.fill: parent
                    fillColor: CP.moduleBg
                    strokeColor: CP.alpha(CP.cyan, 0.25)
                    strokeWidth: 1
                    inset: 0.5
                    cutBottomLeft: 6
                    cutBottomRight: 6
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (carousel.searchFocused && filterBar.resultsModel && carousel.selectedSearchIdx >= 0
                                && carousel.selectedSearchIdx < filterBar.resultsModel.count)
                                return filterBar.resultsModel.get(carousel.selectedSearchIdx).fname.toUpperCase()
                            if (carousel.currentIndex < 0 || carousel.currentIndex >= wallpaperModel.count)
                                    return ""
                            return wallpaperModel.get(carousel.currentIndex).title.toUpperCase()
                        }
                        font.family: "Oxanium"
                        font.pixelSize: 12
                        font.letterSpacing: 2
                        color: Colours.textPrimary
                        elide: Text.ElideRight
                    }

                    // Source badge
                    Item {
                        property string _src: {
                            if (carousel.searchFocused && filterBar.resultsModel && carousel.selectedSearchIdx >= 0
                                && carousel.selectedSearchIdx < filterBar.resultsModel.count)
                                return filterBar.resultsModel.get(carousel.selectedSearchIdx).source || ""
                            if (carousel.currentIndex < 0 || carousel.currentIndex >= wallpaperModel.count) return ""
                            return wallpaperModel.get(carousel.currentIndex).source
                        }
                        visible: _src !== ""
                        width: _srcLbl.implicitWidth + 10; height: 18
                        Layout.alignment: Qt.AlignVCenter

                        CutShape {
                            anchors.fill: parent
                            fillColor: CP.alpha(parent._src === "wpe" ? CP.yellow : CP.cyan, 0.12)
                            strokeColor: CP.alpha(parent._src === "wpe" ? CP.yellow : CP.cyan, 0.55)
                            strokeWidth: 1; inset: 0.5
                            cutTopLeft: 3; cutBottomRight: 3
                        }
                        Text {
                            id: _srcLbl
                            anchors.centerIn: parent
                            text: parent._src.toUpperCase()
                            font.family: "Oxanium"; font.pixelSize: 8; font.letterSpacing: 1
                            color: parent._src === "wpe" ? Colours.accentPrimary : Colours.accentSecondary
                        }
                    }

                    // Type badge
                    Item {
                        property string _typ: {
                            if (carousel.searchFocused) return ""
                            if (carousel.currentIndex < 0 || carousel.currentIndex >= wallpaperModel.count) return ""
                            return wallpaperModel.get(carousel.currentIndex).type
                        }
                        visible: _typ !== ""
                        width: _typLbl.implicitWidth + 10; height: 18
                        Layout.alignment: Qt.AlignVCenter

                        CutShape {
                            anchors.fill: parent
                            fillColor: CP.alpha(CP.void2, 0.7)
                            strokeColor: CP.alpha(Colours.textMuted, 0.35)
                            strokeWidth: 1; inset: 0.5
                            cutTopLeft: 3; cutBottomRight: 3
                        }
                        Text {
                            id: _typLbl
                            anchors.centerIn: parent
                            text: parent._typ.toUpperCase()
                            font.family: "Oxanium"; font.pixelSize: 8; font.letterSpacing: 1
                            color: Colours.textMuted
                        }
                    }

                    Text {
                        text: carousel.searchFocused
                            ? root._searchFileSize
                            : root._currentSize
                        font.family: "Oxanium"
                        font.pixelSize: 10
                        font.letterSpacing: 1
                        color: Colours.accentSecondary
                        visible: text !== ""
                    }

                    Text {
                        text: carousel.searchFocused && filterBar.resultsModel
                            ? (carousel.selectedSearchIdx + 1) + " / " + filterBar.resultsModel.count
                            : root.currentVisiblePosition() + " / " + carousel.visibleCount
                        font.family: "Oxanium"
                        font.pixelSize: 10
                        color: Colours.textMuted
                    }
                }
            }

            // ── Search results grid ──────────────────────────────────────
            WallpaperSearchResults {
                id: searchResultsPanel
                anchors.top: parent.top
                anchors.topMargin: parent.height - 200
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width - 80, 800)
                height: 140

                selectedSearchIdx:  carousel.selectedSearchIdx
                downloadProgress:   root.downloadProgress
                downloadingUrl:     root.downloadingUrl
                localBasenames:     root.localBasenames
                downloadCount:      root.downloadCount
                resultsModel:       filterBar.resultsModel
                downloading:        root.downloading
                searching:          filterBar.searching

                onLoadMoreRequested: filterBar.loadMoreResults()

                onResultSelected: (index, thumbPath, fullUrl) => {
                    carousel.selectedSearchIdx = index
                    carousel.searchFocused = true
                    root.updateSearchPreview(thumbPath, fullUrl)
                    carousel.selectedSearchUrl = fullUrl
                }
            }

            // ── Sort buttons (above search results) ────────────────────────────
            Row {
                id: sortBar
                visible: searchResultsPanel.visible
                anchors.bottom: searchResultsPanel.top
                anchors.bottomMargin: 4
                anchors.right: searchResultsPanel.right
                spacing: 4

                Repeater {
                    model: WC.sortLabels
                    delegate: Item {
                        id: sortBtn
                        width: sortBtnLabel.implicitWidth + 14
                        height: 20

                        required property string    modelData
                        required property int       index

                        property bool      active: filterBar.currentSort === WC.sortOptions[index]

                        CutShape {
                            anchors.fill: parent
                            fillColor: sortBtn.active ? CP.alpha(CP.cyan, 0.15) : "transparent"
                            strokeColor: sortBtn.active ? Colours.accentSecondary : CP.alpha(CP.cyan, 0.2)
                            strokeWidth: 1
                            inset: 0.5
                            cutTopLeft: 3
                            cutBottomRight: 3
                        }

                        Text {
                            id: sortBtnLabel
                            anchors.centerIn: parent
                            text: modelData
                            font.family: "Oxanium"
                            font.pixelSize: 9
                            font.letterSpacing: 1
                            color: sortBtn.active ? Colours.accentSecondary : Colours.textMuted
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                filterBar.currentSort = WC.sortOptions[index]
                                filterBar.resubmit()
                            }
                        }
                    }
                }
            }

            // ── Playlist panel ───────────────────────────────────────────────────
            Item {
                id: panelSlider
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                width: parent.width / 3 - 180
                clip: true
                z: 50

                property bool _panelAnim: false

                PlaylistPanel {
                    id: playlistPanel
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width
                    x: PlaylistState.panelOpen ? 0 : -width
                    wallpaperModel: wallpaperModel

                    Behavior on x {
                        enabled: panelSlider._panelAnim
                        NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
                    }
                }
            }

            // ── Delete confirmation dialog ──────────────────────────────────
            Item {
                id: deleteDialog
                anchors.centerIn: parent
                width: 340
                height: 120
                z: 300
                visible: root.deleteDialogOpen
                opacity: root.deleteDialogOpen ? 1 : 0

                Behavior on opacity { NumberAnimation { duration: 150 } }

                CutShape {
                    anchors.fill: parent
                    fillColor: CP.moduleBg
                    strokeColor: CP.alpha(CP.red, 0.6)
                    strokeWidth: 2
                    inset: 1
                    cutTopLeft: 16
                    cutBottomRight: 16
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "DELETE WALLPAPER?"
                        font.family: "Oxanium"
                        font.pixelSize: 13
                        font.letterSpacing: 3
                        color: Colours.accentDanger
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            if (carousel.currentIndex < 0 || carousel.currentIndex >= wallpaperModel.count)
                                return ""
                            return wallpaperModel.get(carousel.currentIndex).title.toUpperCase()
                        }
                        font.family: "Oxanium"
                        font.pixelSize: 10
                        font.letterSpacing: 1
                        color: Colours.textMuted
                        elide: Text.ElideRight
                        width: 300
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 16

                        // Confirm
                        Item {
                            width: confirmText.implicitWidth + 24
                            height: 28

                            CutShape {
                                anchors.fill: parent
                                fillColor: CP.alpha(CP.red, 0.2)
                                strokeColor: Colours.accentDanger
                                strokeWidth: 1
                                inset: 0.5
                                cutTopLeft: 4
                                cutBottomRight: 4
                            }

                            Text {
                                id: confirmText
                                anchors.centerIn: parent
                                text: "ENTER - DELETE"
                                font.family: "Oxanium"
                                font.pixelSize: 10
                                font.letterSpacing: 1
                                color: Colours.accentDanger
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.deleteCurrentWallpaper()
                            }
                        }

                        // Cancel
                        Item {
                            width: cancelText.implicitWidth + 24
                            height: 28

                            CutShape {
                                anchors.fill: parent
                                fillColor: "transparent"
                                strokeColor: CP.alpha(CP.cyan, 0.3)
                                strokeWidth: 1
                                inset: 0.5
                                cutTopLeft: 4
                                cutBottomRight: 4
                            }

                            Text {
                                id: cancelText
                                anchors.centerIn: parent
                                text: "ESC - CANCEL"
                                font.family: "Oxanium"
                                font.pixelSize: 10
                                font.letterSpacing: 1
                                color: Colours.textMuted
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.delegateDialogOpen = false
                            }
                        }
                    }
                }
            }

            SteamAuthDialog {
                id: steamAuthDialog
                anchors.centerIn: parent
                width: 380
                height: 200
                z: 350

                onLoginRequested: (password) => {
                    steamAuthDialog.step = "working"
                    steamAuthProc.command = ["bash", "-c",
                        "HOME=$HOME/.config/steamcmd-isolated steamcmd +login banditobad " + password + " +quit 2>&1 | tr -d '\\033' | sed 's/\\[0m//g'"]
                    steamAuthProc.running = true
                }

                onClosed: {
                    root._pendingDownloadUrl = ""
                    root._pendingDownloadTitle = ""
                }
            }

            Timer {
                id: steamAuthCloseTimer
                interval: 1000
                onTriggered: {
                    steamAuthDialog.open = false
                    if (root._pendingDownloadUrl !== "") {
                        downloadAndAdd(root._pendingDownloadUrl, "", root._pendingDownloadTitle, "wpe")
                        root._pendingDownloadUrl = ""
                        root._pendingDownloadTitle = ""
                    }
                }
            }

            Connections {
                target: steamAuthDialog
                function onStepChanged() {
                    if (steamAuthDialog.step === "success")
                        steamAuthCloseTimer.restart()
                }
            }

            Keys.onPressed: event => {
                switch (event.key) {
                    case Qt.Key_F:
                        if (!filterBar.searchInputFocused && !carousel.searchFocused && !root.deleteDialogOpen) {
                            if (event.modifiers & Qt.AltModifier) {
                                filterBar.favoritesOnly = !filterBar.favoritesOnly
                            } else {
                                root.toggleFavorite()
                            }
                        }
                        event.accepted = true
                        break
                    case Qt.Key_R:
                        if (!filterBar.searchInputFocused && !carousel.searchFocused && !root.deleteDialogOpen) {
                            if (carousel.currentIndex >= 0 && carousel.currentIndex < wallpaperModel.count) {
                                root.deleteDialogOpen = true
                            }
                        }
                        event.accepted = true
                        break
                    case Qt.Key_Left:
                    case Qt.Key_Right:
                        if (filterBar.searchInputFocused || root.deleteDialogOpen) break
                        if (carousel.searchFocused && filterBar.resultsModel && filterBar.resultsModel.count > 0) {
                            // Navigate search results
                            if (event.key === Qt.Key_Right)
                                carousel.selectedSearchIdx = Math.min(carousel.selectedSearchIdx + 1, filterBar.resultsModel.count - 1)
                            else
                                carousel.selectedSearchIdx = Math.max(carousel.selectedSearchIdx - 1, 0)
                            // Update preview in dedicated card
                            var sr = filterBar.resultsModel.get(carousel.selectedSearchIdx)
                            if (sr) {
                                root.updateSearchPreview(sr.thumbPath, sr.fullUrl)
                                carousel.selectedSearchUrl = sr.fullUrl
                            }
                        } else {
                            // Normal carousel navigation
                            if (event.isAutoRepeat) {
                                carousel.rapidCount++
                            } else {
                                carousel.rapidCount = 0
                            }
                            fastModeTimer.restart()

                            if (event.key === Qt.Key_Right) root.nextVisible()
                            else root.prevVisible()

                            if (event.isAutoRepeat && carousel.rapidCount > 5 && !carousel.fastMode) {
                                carousel.updateCardsFast()
                                carousel.fastMode = true
                            }
                        }
                        event.accepted = true
                        break
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        if (root.deleteDialogOpen) {
                            root.deleteCurrentWallpaper()
                        } else if (!filterBar.searchInputFocused) {
                            root.applyWallpaper()
                        }
                        event.accepted = true
                        break
                    case Qt.Key_Escape:
                        if (root.deleteDialogOpen) {
                            root.deleteDialogOpen = false
                            event.accepted = true
                            break
                        }
                        if (carousel.searchFocused) {
                            carousel.searchFocused = false
                            carousel.selectedSearchIdx = -1
                            carousel.selectedSearchUrl = ""
                            filterBar.closeSearch()
                            event.accepted = true
                            break
                        }
                        if (PlaylistState.panelOpen) {
                            PlaylistState.panelOpen = false
                            event.accepted = true
                            break
                        }
                        if (WallpaperState.macroFilter !== "all" ||
                            WallpaperState.subFilter !== "" ||
                            WallpaperState.colorFilter !== "") {
                            WallpaperState.resetFilters()
                            root.localFilterKeywords = ""
                        } else {
                            root.restoreWallpaper()
                            WallpaperState.closePicker()
                        }
                        event.accepted = true
                        break
                    case Qt.Key_Tab:
                        if (searchResultsPanel.visible) {
                            var sidx = WC.sortOptions.indexOf(filterBar.currentSort)
                            filterBar.currentSort = WC.sortOptions[(sidx + 1) % WC.sortOptions.length]
                            filterBar.resubmit()
                        } else {
                            WallpaperState.cycleMacro()
                        }
                        event.accepted = true
                        break
                    case Qt.Key_Backtab:
                        if (searchResultsPanel.visible) {
                            var bidx = WC.sortOptions.indexOf(filterBar.currentSort)
                            filterBar.currentSort = WC.sortOptions[(bidx + WC.sortOptions.length - 1) % WC.sortOptions.length]
                            filterBar.resubmit()
                        } else {
                            WallpaperState.cycleSub()
                        }
                        event.accepted = true
                        break
                    case Qt.Key_Up:
                        if (carousel.searchFocused) {
                            carousel.searchFocused = false
                            event.accepted = true
                            break
                        }
                        if (!root.isActiveScreen) break
                        var upIdx = carousel.currentIndex
                        if (upIdx < 0 || upIdx >= wallpaperModel.count) break
                        var upEntry = wallpaperModel.get(upIdx)

                        if (root.previewShown && root._carouselPreviewIdx === upIdx) {
                            // Same card - remove preview
                            if (root.wpePreviewActive) {
                                Quickshell.execDetached(["bash", "-c",
                                root.scriptsDir + "/wallpaper-picker.sh stop-preview-wpe "
                                + root.screen.name])
                            }
                            if (root.originalWallpaper) {
                                Quickshell.execDetached(["bash", "-c",
                                root.scriptsDir + "/wallpaper-picker.sh preview "
                                + root.screen.name + " '" + root.originalWallpaper + "'"])
                            }
                            root.previewShown = false
                            root.wpePreviewActive = false
                            root._carouselPreviewIdx = -1
                        } else {
                            // New or different card - set/replace preview
                            root._carouselPreviewIdx = upIdx
                            var stopCmd = root.wpePreviewActive
                                        ? root.scriptsDir + "/wallpaper-picker.sh stop-preview-wpe "
                                        + root.screen.name + " && "
                                        : ""
                            if (upEntry.source === "wpe") {
                                // WPE: stop previous (if any) then start new
                                root.previewShown = true
                                root.wpePreviewActive = true
                                Quickshell.execDetached(["bash", "-c",
                                    stopCmd
                                    + root.scriptsDir + "/wallpaper-picker.sh preview-wpe "
                                    + root.screen.name + " '" + upEntry.path + "'"])
                            } else {
                                // Static stop WPE first if it was active
                                root.previewShown = true
                                root.wpePreviewActive = false
                                Quickshell.execDetached(["bash", "-c",
                                stopCmd
                                + root.scriptsDir + "/wallpaper-picker.sh preview "
                                + root.screen.name + " '" + upEntry.path + "'"])
                            }
                        }
                        event.accepted = true
                        break
                    case Qt.Key_Down:
                        if (!carousel.searchFocused && filterBar.resultsModel && filterBar.resultsModel.count > 0) {
                            carousel.searchFocused = true
                            if (carousel.selectedSearchIdx < 0) carousel.selectedSearchIdx = 0
                            event.accepted = true
                            break
                        }
                        if (carousel.searchFocused && carousel.selectedSearchIdx >= 0
                            && carousel.selectedSearchIdx < filterBar.resultsModel.count) {
                            if (root.previewShown && root._searchPreviewIdx === carousel.selectedSearchIdx) {
                                // Same result - remove preview
                                if (root.originalWallpaper) {
                                    Quickshell.execDetached(["bash", "-c",
                                        root.scriptsDir + "/wallpaper-picker.sh preview "
                                        + root.screen.name + " '" + root.originalWallpaper + "'"])
                                }
                                root.previewShown = false
                                root._searchPreviewIdx = -1
                            } else {
                                // New or different result - set/replace preview
                                var dlEntry = filterBar.resultsModel.get(carousel.selectedSearchIdx)
                                if (dlEntry) {
                                    root.previewShown = true
                                    root.wpePreviewActive = false
                                    root._searchPreviewIdx = carousel.selectedSearchIdx
                                    root.searchPreviewLoading = true
                                    root._previewMsgIdx = 0
                                    searchPreviewProc.command = ["bash", "-c",
                                        "F=/tmp/qs-search-preview-$$-$RANDOM; " +
                                        "curl -sL --max-time 15 -o \"$F\" '" + dlEntry.fullUrl + "' && " +
                                        root.scriptsDir + "/wallpaper-picker.sh preview "
                                        + root.screen.name + " \"$F\""]
                                    searchPreviewProc.running = true
                                }
                            }
                            event.accepted = true
                            break
                        }
                        if (root.wpePreviewActive) {
                            Quickshell.execDetached(["bash", "-c",
                                root.scriptsDir + "/wallpaper-picker.sh stop-preview-wpe "
                                + root.screen.name])
                        }
                        if (root.previewShown && root.originalWallpaper) {
                            Quickshell.execDetached(["bash", "-c",
                                root.scriptsDir + "/wallpaper-picker.sh preview "
                                + root.screen.name + " '" + root.originalWallpaper + "'"])
                        }
                        root.previewShown = false
                        root.wpePreviewActive = false
                        event.accepted = true
                        break
                    case Qt.Key_S:
                        filterBar.activateSearch()
                        event.accepted = true
                        break
                    case Qt.Key_M:
                        if (!filterBar.searchInputFocused) {
                            var mCard = repeater.itemAt(carousel.currentIndex)
                            if (mCard && mCard.videoPlaying) {
                                carousel.audioEnabled = !carousel.audioEnabled
                                if (carousel.audioEnabled && carousel.savedVolume <= 0) {
                                    carousel.savedVolume = 0.5
                                }
                            }
                        }
                        event.accepted = true
                        break
                    case Qt.Key_P:
                        if (!filterBar.searchInputFocused)
                            if (event.modifiers & Qt.ControlModifier) {
                                PlaylistState.togglePanel()
                            } else {
                                var pIdx = carousel.currentIndex
                                if (pIdx >= 0 && pIdx < wallpaperModel.count) {
                                    var e = wallpaperModel.get(pIdx)
                                    PlaylistState.toggleEntry(e.path, e.type, e.title || "", e.source, e.thumb || e.path)
                                }
                            }
                        event.accepted = true
                        break
                    case Qt.Key_0:
                    case Qt.Key_1:
                    case Qt.Key_2:
                    case Qt.Key_3:
                    case Qt.Key_4:
                    case Qt.Key_5:
                    case Qt.Key_6:
                    case Qt.Key_7:
                    case Qt.Key_8:
                    case Qt.Key_9:
                        if (!filterBar.searchInputFocused && !carousel.searchFocused && !root.deleteDialogOpen) {
                            root.jumpToFraction(event.key - Qt.Key_0)
                        }
                        event.accepted = true
                        break
                }
            }
        }
    }

    Connections {
        target: PlaylistState
        function onEntryApplyRequested(path) {
            var mode = PlaylistState.screenMode
            if (mode !== "both" && mode !== "sync" && mode !== root.screen.name) return
            Quickshell.execDetached(["bash", "-c",
                root.themerDir + "/wallpaper-themer.sh set "
                + root.screen.name + " '" + path + "'"])
        }
    }

    function setPreviewFromPlaylist(path, source) {
        // Toggle: same card already in preview -> remove
        if (_playlistPreviewPath === path) {
            if (root.wpePreviewActive) {
                Quickshell.execDetached(["bash", "-c",
                    root.scriptsDir + "/wallpaper-picker.sh stop-preview-wpe " + root.screen.name])
            }
            if (root.originalWallpaper) {
                Quickshell.execDetached(["bash", "-c",
                    root.scriptsDir + "/wallpaper-picker.sh preview "
                    + root.screen.name + " '" + root.originalWallpaper + "'"])
            }
            root.previewShown = false
            root.wpePreviewActive = false
            _playlistPreviewPath = ""
            return
        }

        // New preview
        var stopCmd = root.wpePreviewActive
                    ? root.scriptsDir + "/wallpaper-picker.sh stop-preview-wpe " + root.screen.name + " && "
                    : ""
        root.previewShown = true
        if (source === "wpe") {
            root.wpePreviewActive = true
            Quickshell.execDetached(["bash", "-c",
                stopCmd + root.scriptsDir + "/wallpaper-picker.sh preview-wpe "
                + root.screen.name + " '" + path + "'"])
        } else {
            root.wpePreviewActive = false
            Quickshell.execDetached(["bash", "-c",
                stopCmd + root.scriptsDir + "/wallpaper-picker.sh preview "
                + root.screen.name + " '" + path + "'"])
        }
        _playlistPreviewPath = path
    }

    Connections {
        target: PlaylistState
        function onPreviewRequested(path, source) {
            if (!root.isActiveScreen) return
            root.setPreviewFromPlaylist(path, source)
        }
    }
}
