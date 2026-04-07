import "../../common/Colors.js" as CP
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

    property string originalWallpaper:  ""
    property string downloadingUrl:     ""
    property bool   wpePreviewActive:   false
    property bool   deleteDialogOpen:   false
    property bool   previewShown:       false
    property bool   downloading:        false
    property bool   _skipInit:          false
    property real   downloadProgress:   0
    property var    searchResultsModel: null
    property var    localBasenames:     ({})
    property var    allEntries:         []    

    ListModel { id: wallpaperModel }

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

    function applyWallpaper() {
        var idx = carousel.currentIndex
        if (idx < 0 || idx >= wallpaperModel.count) return
        var card = repeater.itemAt(idx)

        // If search preview is active, download and add to carousel
        if (carousel.searchFocused && carousel.selectedSearchUrl !== "") {
            downloadAndAdd(carousel.selectedSearchUrl, "")
            return
        }

        var entry = wallpaperModel.get(idx)
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
    }

    Process {
        id: downloadProc
        command: ["bash", "-c", "true"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                if (data.startsWith("PROGRESS:")) {
                    root.downloadProgress = parseInt(data.substring(9)) / 100
                } else if (data.startsWith("SAVED:")) {
                    var savedPath = data.substring(6)
                    // Add to catalog and carousel
                    var fname = savedPath.substring(savedPath.lastIndexOf("/") + 1)
                    var title = fname.substring(0, fname.lastIndexOf("."))
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
                    carousel.updateCards()
                    var bn = savedPath.substring(savedPath.lastIndexOf("/") + 1)
                    var lb = root.localBasenames
                    lb[bn] = true
                    root.localBasenames = lb
                    root.downloading = false
                    completionGlitch.start()
                    root.downloadProgress = 0
                    root.downloadingUrl = ""
                }
            }
        }
    }

    function downloadAndAdd(url, thumbPath) {
        root.downloading        = true
        root.downloadProgress   = 0
        root.downloadingUrl    = url
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

    function deleteCurrentWallpaper() {
        var idx = carousel.currentIndex
        if (idx < 0 || idx >= wallpaperModel.count) return
        var entry = wallpaperModel.get(idx)
        var path = entry.path

        // Remove file
        deleteProc.command = ["rm", "-f", path]
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

        root.deleteDialogOpen = false
    }

    function currentVisiblePosition() {
        var pos = 0
        for (var i = 0; i <= carousel.currentIndex && i < wallpaperModel.count; i++) {
            if (WallpaperState.matchesFilter(wallpaperModel.get(i))) pos++
        }
        return pos
    }

    function nextVisible() {
        var count = wallpaperModel.count
        if (count === 0) return
        var idx = carousel.currentIndex
        for (var i = 0; i < count; i++) {
            idx = (idx + 1) % count
            if (WallpaperState.matchesFilter(wallpaperModel.get(idx))) {
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
            if (WallpaperState.matchesFilter(wallpaperModel.get(idx))) {
                carousel.currentIndex = idx
                carousel.updateCards()
                return
            }
        }
    }

    function updateSearchPreview(thumbPath, fullUrl) {
        var isGif = fullUrl.toLowerCase().endsWith(".gif")
        if (isGif) {
            searchPreviewImage.source = ""
            searchPreviewGif.source = fullUrl
        } else {
            searchPreviewGif.source = ""
            searchPreviewImage.source = thumbPath ? fullUrl : ""
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
            // Refresh cache in background for next open
            bgRefreshProc.running = true
            WallpaperState.resetFilters()
            root.previewShown = false
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

        Item {
            id: mainLayout
            anchors.fill: parent
            focus: true

            WallpaperFilterBar {
                id: filterBar
                anchors.top: parent.top
                anchors.topMargin: root.isActiveScreen ? 230 : -100
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, parent.width - 80)

                Behavior on anchors.topMargin {
                    NumberAnimation { duration: 600; easing.type: Easing.OutExpo }
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

                property int currentIndex: 0
                readonly property real cardSpacing: -12
                property int visibleCount: 0
                property real savedVolume: 0.5
                property bool audioEnabled: false
                property bool fastMode: false
                property int rapidCount: 0
                property bool searchFocused: false
                property int selectedSearchIdx: -1
                property string selectedSearchUrl: ""

                onSelectedSearchIdxChanged: {
                    if (selectedSearchIdx >= 0 && searchGrid.count > 0) {
                        searchGrid.positionViewAtIndex(selectedSearchIdx, ListView.Center)
                        // Load more when near the end
                        if (selectedSearchIdx >= filterBar.resultsModel.count - 3) {
                            filterBar.loadMoreResults()
                        }
                    }
                }

                Timer {
                    id: fastModeTimer
                    interval: 400
                    onTriggered: {
                        if (!carousel.fastMode) return
                        carousel.fastMode = false
                        carousel.rapidCount = 0
                        for (var i = 0; i < repeater.count; i++) {
                            var item = repeater.itemAt(i)
                            if (item) item.animEnabled = true
                        }
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
                            continue
                        }

                        // Circular offset: shortest path around the ring
                        var rightDist = (visIdx - curVis + visCount) % visCount
                        var leftDist = (curVis - visIdx + visCount) % visCount
                        var offset = rightDist <= leftDist ? rightDist : -leftDist

                        var circDist = Math.min(rightDist, leftDist)
                        item.distFromCurrent = circDist
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
                    var halfCount = Math.floor(visCount / 2)

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
                            continue
                        }

                        var dist = cardDists[i]
                        item.distFromCurrent = dist
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
                            if (item) item.reveal()
                        }
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
                    function onSubFilterChanged()   { filterUpdateTimer.restart() }
                    function onColorFilterChanged()  { filterUpdateTimer.restart() }
                }

                Connections {
                    target: filterBar
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

                Repeater {
                    id: repeater
                    model: wallpaperModel
                    onItemAdded: { if (!root._skipInit) initTimer.restart() }

                    delegate: WallpaperCard {
                        y: 0
                        viewCurrentIndex: carousel.currentIndex
                        viewTotalVisible: carousel.visibleCount
                        isCurrent: index === carousel.currentIndex
                        videoVolume: isCurrent && carousel.audioEnabled ? carousel.savedVolume : 0
                        isVisible: {
                            var m = WallpaperState.macroFilter
                            var s = WallpaperState.subFilter
                            var c = WallpaperState.colorFilter
                            if (m === "awww" && source !== "awww") return false
                            if (m === "wpe" && source !== "wpe") return false
                            if (s !== "" && type !== s) return false
                            if (c !== "" && !WallpaperState._colorMatches(color, c)) return false
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

                CutShape {
                    anchors.fill: parent
                    fillColor: "transparent"
                    strokeColor: Colours.accentPrimary
                    strokeWidth: 2
                    inset: 1
                    cutTopLeft: 32
                    cutBottomRight: 32
                }

                // ── Download overalay (preview) ───────────────────────────────────
                Item {
                    id: previewDownloadOverlay
                    anchors.fill: parent
                    visible: root.downloading
                    z: 10

                    // Darken
                    Rectangle {
                        anchors.fill: parent
                        color: CP.alpha("#000000", 0.45)
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
                    spacing: 16

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

                    Text {
                        text: {
                            if (carousel.searchFocused && carousel.selectedSearchIdx >= 0
                                && carousel.selectedSearchIdx < filterBar.resultsModel.count)
                                return filterBar.resultsModel.get(carousel.selectedSearchIdx).source.toUpperCase()
                            if (carousel.currentIndex < 0 || carousel.currentIndex >= wallpaperModel.count)
                                return ""
                            var e = wallpaperModel.get(carousel.currentIndex)
                            return e.source.toUpperCase() + " / " + e.type.toUpperCase()
                        }
                        font.family: "Oxanium"
                        font.pixelSize: 10
                        font.letterSpacing: 1
                        color: Colours.textMuted
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
            Item {
                id: searchResultsPanel
                anchors.top: parent.top
                anchors.topMargin: parent.height - 200
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width - 80, 800)
                height: 140
                visible: filterBar.resultsModel ? filterBar.resultsModel.count > 0 : false
                
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: searchPanelMask
                    maskThresholdMin: 0.5
                }

                CutShape {
                    anchors.fill: parent
                    fillColor: CP.moduleBg
                    strokeColor: CP.alpha(CP.cyan, 0.2)
                    strokeWidth: 1
                    inset: 0.5
                    cutTopLeft: 24
                    cutBottomRight: 24
                }

                Text {
                    anchors.top: parent.top
                    anchors.topMargin: 4
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    text: "SEARCH RESULTS"
                    font.family: "Oxanium"
                    font.pixelSize: 9
                    font.letterSpacing: 2
                    color: Colours.textMuted
                }

                ListView {
                    id: searchGrid
                    anchors.fill: parent
                    anchors.topMargin: 20
                    anchors.bottomMargin: 8
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    orientation: ListView.Horizontal
                    spacing: 6
                    clip: true
                    interactive: true
                    focus: false
                    keyNavigationEnabled: false
                    boundsBehavior: Flickable.StopAtBounds

                    model: filterBar.resultsModel

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        z: -1
                        onWheel: wheel => {
                            searchGrid.flick(wheel.angleDelta.y * 8, 0)
                        }
                    }

                    delegate: Item {
                        width: 100
                        height: searchGrid.height
                        required property string fname
                        required property string thumbPath
                        required property string fullUrl
                        required property int index
                        required property string source

                        // Masked content (image clipped to cut shape)
                        Item {
                            id: resultContent
                            anchors.fill: parent

                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: resultCardMask
                                maskThresholdMin: 0.5
                            }

                            Image {
                                anchors.fill: parent
                                source: thumbPath ? "file://" + thumbPath : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }

                        // Source badge
                        CutShape {
                            id: sourceBadge
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: 2
                            width: badgeText.implicitWidth + 8
                            height: 22
                            fillColor: CP.alpha("#000000", 0.6)
                            cutBottomLeft: typeBadge.visible ? 0 : 4

                            Text {
                                id: badgeText
                                anchors.centerIn: parent
                                text: {
                                    switch (parent.parent.source) {
                                        case "r":  return "\uf281"
                                        case "rg": return "\uf281"
                                        case "a":  return "A"
                                        case "ag": return "AG"
                                        default:   return parent.parent.source.toUpperCase()
                                    }
                                }
                                font.family: parent.parent.source === "r" || parent.parent.source === "rg"
                                    ? "JetBrainsMono Nerd Font" : "Oxanium"
                                font.pixelSize: 12
                                font.letterSpacing: parent.parent.source === "r" || parent.parent.source === "rg" ? 0 : 1
                                color: {
                                    switch (parent.parent.source) {
                                        case "wh": return CP.cyan
                                        case "a":  return CP.yellow
                                        case "ag": return CP.yellow
                                        case "r":  return CP.magenta
                                        case "rg": return CP.magenta
                                        default:   return CP.cyan
                                    }
                                }
                            }
                        }

                        // Type badge (gif/img)
                        CutShape {
                            id: typeBadge
                            anchors.top: sourceBadge.bottom
                            anchors.right: parent.right
                            width: sourceBadge.implicitWidth
                            height: 14
                            fillColor: CP.alpha("#000000", 0.6)
                            cutBottomLeft: 4
                            z: 5
                            visible: parent.fullUrl.toLowerCase().endsWith(".gif")

                            Text {
                                id: typeText
                                anchors.centerIn: parent
                                text: "GIF"
                                font.family: "Oxanium"
                                font.pixelSize: 9
                                font.letterSpacing: 1
                                color: Colours.accentOk
                            }
                        }

                        // Downloaded indicator
                        CutShape {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            width: 24
                            height: 20
                            fillColor: CP.alpha("#000000", 0.6)
                            cutTopRight: 8
                            visible: {
                                var bn = parent.fullUrl.substring(parent.fullUrl.lastIndexOf("/") + 1)
                                return root.localBasenames[bn] === true
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "\u2713"
                                font.pixelSize: 18
                                color: Colours.accentOk
                            }
                        }

                        // ── Download overlay ───────────────────────────────────────────
                        Item {
                            anchors.fill: parent
                            visible: root.downloading && root.downloadingUrl === parent.fullUrl
                            z: 6

                            // Darken
                            Rectangle {
                                anchors.fill: parent
                                color: CP.alpha("#000000", 0.5)
                                opacity: root.downloading && root.downloadingUrl === parent.fullUrl ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }

                            // Scanlines
                            ScanlineOverlay { opacity: 0.12 }

                            // Download icon
                            Text {
                                anchors.centerIn: parent
                                text: "\uf019"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 16
                                color: CP.cyan
                                PulseAnim on opacity { running: true; minOpacity: 0.3; duration: 400 }
                            }

                            // Progress Bar
                            Item {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 3

                                Rectangle {
                                    anchors.fill: parent
                                    color: CP.alpha(CP.cyan, 0.15)
                                }

                                Rectangle {
                                    id: smallProgressBar
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

                        // Border (outside mask, not clipped)
                        CutShape {
                            anchors.fill: parent
                            fillColor: "transparent"
                            strokeColor: carousel.selectedSearchIdx === parent.index
                                        ? Colours.accentSecondary
                                        : CP.alpha(CP.cyan, 0.15)
                            strokeWidth: carousel.selectedSearchIdx === parent.index ? 2 : 1
                            inset: 0.5
                            cutTopLeft: 12
                            cutBottomRight: 12
                        }

                        // Mask shape
                        CutShape {
                            id: resultCardMask
                            anchors.fill: parent
                            layer.enabled: true
                            visible: false
                            fillColor: "white"
                            cutTopLeft: 12
                            cutBottomRight: 12
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                carousel.selectedSearchIdx = index
                                carousel.searchFocused = true
                                root.updateSearchPreview(thumbPath, fullUrl)
                                carousel.selectedSearchUrl = fullUrl
                            }
                        }
                    }
                }

                CutShape {
                    id: searchPanelMask
                    anchors.fill: parent
                    layer.enabled: true
                    visible: false
                    fillColor: "white"
                    cutTopLeft: 24
                    cutBottomRight: 24
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

            Keys.onPressed: event => {
                switch (event.key) {
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
                                if (carousel.rapidCount > 5 && !carousel.fastMode) {
                                    carousel.fastMode = true
                                    for (var i = 0; i < repeater.count; i++) {
                                        var item = repeater.itemAt(i)
                                        if (item) item.animEnabled = false
                                    }
                                    carousel.updateCardsFast()
                                }
                            } else {
                                carousel.rapidCount = 0
                            }
                            fastModeTimer.restart()

                            if (event.key === Qt.Key_Right) root.nextVisible()
                            else root.prevVisible()
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
                            // Clear search preview from current card
                            var escCard = repeater.itemAt(carousel.currentIndex)
                            if (escCard) {
                                escCard.searchPreviewThumb = ""
                                escCard.searchPreviewUrl = ""
                            }
                            event.accepted = true
                            break
                        }
                        if (WallpaperState.macroFilter !== "all" ||
                            WallpaperState.subFilter !== "" ||
                            WallpaperState.colorFilter !== "") {
                            WallpaperState.resetFilters()
                        } else {
                            root.restoreWallpaper()
                            WallpaperState.closePicker()
                        }
                        event.accepted = true
                        break
                    case Qt.Key_Tab:
                        WallpaperState.cycleMacro()
                        event.accepted = true
                        break
                    case Qt.Key_Backtab:
                        WallpaperState.cycleSub()
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
                        var upCard = repeater.itemAt(upIdx)

                        if (root.previewShown && upCard && upCard.videoPlaying
                            && upEntry.type === "video" && !root.wpePreviewActive) {
                            // Second press: WPE preview (temporary, not applied)
                            root.wpePreviewActive = true
                            Quickshell.execDetached(["bash", "-c",
                                root.scriptsDir + "/wallpaper-picker.sh preview-wpe "
                                + root.screen.name + " '" + upEntry.path + "'"])
                        } else if (!root.previewShown) {
                            // First press: static preview
                            root.previewShown = true
                            root.wpePreviewActive = false
                            Quickshell.execDetached(["bash", "-c",
                            root.scriptsDir + "/wallpaper-picker.sh preview "
                            + root.screen.name + " '" + upEntry.path + "'"])
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
                }
            }
        }
    }
}
