import "../../common/Colors.js" as CP
import "./WallpaperConst.js" as WC
import "../../common"
import Quickshell.Io
import QtQuick

Item {
    id:             root
    implicitWidth:  expanded ? 360 : 44
    implicitHeight: 44
    clip:           true

    property string _placeholderPrefix: ""
    property string currentQuery:       ""
    property string currentSort:        "relevance"
    property bool   _waitingForStart:   false
    property bool   _prefixGlitching:   false
    property bool   _updatingPrefix:    false
    property bool   isLocalFilter:      _activePrefixes.indexOf("#") >= 0
    property bool   searching:          false
    property bool   expanded:           false
    property bool   hasMore:            true
    property int    _pageResultCount:   0
    property int    currentPage:        1
    property var    _activePrefixes:    []

    signal resultClicked(string thumbPath, string fullUrl)
    signal localFilterChanged(string keywords)
    signal firstResultReady()

    function focusInput() {
        _placeholderPrefix = _randomPlaceholder()
        searchInput.forceActiveFocus()
    }

    function closeSearch() {
        _activePrefixes = []
        _placeholderPrefix = ""
        _waitingForStart = false
        currentSort = "relevance"
        sortDebounceTimer.stop()
        if (searching) {
            controlProc.running = true
            searching = false
        }
        searchResultsModel.clear()
        searchInput.text = ""
        expanded = false
    }

    function resubmit() { sortDebounceTimer.restart() }

    function _doResubmit() {
        if (currentQuery === "") return
        if (searching) controlProc.running = true
        currentPage = 1
        hasMore = true
        searching = true
        _waitingForStart = true
        searchProc.running = false
        searchProc.command = ["bash",
            Qt.resolvedUrl("../../scripts/search-wallpapers.sh").toString().replace("file://", ""),
            currentQuery, "1", currentSort]
        searchProc.running = true
    }

    function loadMore() {
        if (searching || !hasMore || currentQuery === "") return
        currentPage++
        searching = true
        searchProc.command = ["bash",
            Qt.resolvedUrl("../../scripts/search-wallpapers.sh").toString().replace('file://', ""),
            currentQuery, String(currentPage), currentSort]
        searchProc.running = true
    }

    function submitSearch() {
        if (searchInput.text.trim() === "" && _activePrefixes.length === 0) return
        if (_activePrefixes.indexOf("#") >= 0) {
            localFilterChanged(searchInput.text.trim())
            searchInput.focus = false
            root.parent.forceActiveFocus()
            return
        }
        var prefixPart = _activePrefixes.length > 0
                        ? "@" + _activePrefixes.map(function(p) { return p.substring(1) }).join("+") + " "
                        : ""
        currentQuery = prefixPart + searchInput.text.trim()
        currentPage = 1
        hasMore = true
        searching = true
        _waitingForStart = true
        searchResultsModel.clear()
        searchProc.command = ["bash",
            Qt.resolvedUrl("../../scripts/search-wallpapers.sh").toString().replace("file://", ""),
            currentQuery, "1", currentSort]
        searchProc.running = false
        searchProc.running = true
        searchInput.focus = false
        root.parent.forceActiveFocus()
    }

    function _randomPlaceholder() {
        var remaining = WC.prefixes.filter(function(p) {
            return p !== "#" && _activePrefixes.indexOf(p) === -1
        })
        if (remaining.length === 0) return ""
        return remaining[Math.floor(Math.random() * remaining.length)]
    }

    function _updatePrefixState() {
        if (_updatingPrefix) return
        var txt = searchInput.text
        if (_activePrefixes.length > 0 && _activePrefixes.indexOf("#") === -1 && !txt.startsWith("@")) return
        // Check for completed prefix (prefix + space)
        for (var i = 0; i < WC.prefixes.length; i++) {
            if (txt.startsWith(WC.prefixes[i] + " ")) {
                var query = txt.substring(WC.prefixes[i].length + 1)
                _updatingPrefix = true
                if (_activePrefixes.indexOf(WC.prefixes[i]) === -1) {
                    var np = _activePrefixes.filter(function(p) { return p !== "#" })
                    np.push(WC.prefixes[i])
                    _activePrefixes = np
                }
                searchInput.text = query
                searchInput.cursorPosition = query.length
                _updatingPrefix = false
                _placeholderPrefix = ""
                prefixGlitchAnim.restart()
                return
            }
        }
        // Special: # prefix activates immediately (no space needed)
        if (txt.startsWith("#")) {
            _updatingPrefix = true
            searchInput.text = txt.substring(1)
            _updatingPrefix = false
            if (_activePrefixes.indexOf("#") === -1) {
                _activePrefixes = ["#"]
                _placeholderPrefix = ""
                prefixGlitchAnim.restart()
            }
            localFilterChanged(searchInput.text)
            return
        }
        // Check for partial match
        if (txt.startsWith("@") && txt.indexOf(" ") === -1) {
            for (var j = 0; j < WC.prefixes.length; j++) {
                if (WC.prefixes[j].startsWith(txt) && WC.prefixes[j] !== txt
                    && _activePrefixes.indexOf(WC.prefixes[j]) === -1
                    && WC.prefixes[j] !== "#") {
                    _placeholderPrefix = WC.prefixes[j]
                    return
                }
            }
        }
        // Live local filter update
        if (_activePrefixes.indexOf("#") >= 0) {
            localFilterChanged(txt)
            return
        }
        _placeholderPrefix = ""
    }

    function _autocompletePrefix() {
        if (_placeholderPrefix !== "" && searchInput.text.startsWith("@")) {
            _updatingPrefix = true
            searchInput.text = _placeholderPrefix + " "
            _updatingPrefix = false
            searchInput.cursorPosition = searchInput.text.length
            _updatePrefixState()
        }
    }

    Behavior on implicitWidth {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    CutShape {
        anchors.fill: parent
        fillColor: root.expanded ? CP.alpha(CP.cyan, 0.08) : "transparent"
        strokeColor: root.expanded ? CP.alpha(CP.cyan, 0.4) : "transparent"
        strokeWidth: 1
        inset: 0.5
        cutTopLeft: 4
        cutBottomRight: 4
    }

    Text {
        anchors.centerIn: parent
        text: "\u2315"
        font.pixelSize: 16
        color: Colours.textMuted
        visible: !root.expanded
    }

    MouseArea {
        anchors.fill: parent
        visible: !root.expanded
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.expanded = true
            root._placeholderPrefix = root._randomPlaceholder()
            searchInput.forceActiveFocus()
        }
    }

    // ── Input area (manual layout, no Row) ─────────────────
    Item {
        id: inputArea
        anchors.fill: parent
        anchors.margins: 6
        visible: root.expanded

        // Prefix chips
        Row {
            id: prefixRow
            x: 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            visible: _activePrefixes.length > 0 && !_prefixGlitching
            z: 5

            Repeater {
                model: _activePrefixes
                CutShape {
                    height: 20
                    cutTopRight: 3
                    width: chipMeasure.implicitWidth + 10
                    fillColor: CP.alpha(WC.prefixColors[modelData] || CP.cyan, 0.15)
                    strokeColor: CP.alpha(WC.prefixColors[modelData] || CP.cyan, 0.6)
                    strokeWidth: 1
                    inset: 0.5

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        font.family: "Oxanium"
                        font.pixelSize: 12
                        font.letterSpacing: 1
                        color: WC.prefixColors[modelData] || CP.cyan
                    }

                    Text {
                        id: chipMeasure
                        visible: false
                        text: modelData
                        font.family: "Oxanium"
                        font.pixelSize: 12
                    }
                }
            }
        }

        // Ghost placeholder for prefix autocomplete
        Text {
            id: placeholderGhost
            x: searchInput.x
            anchors.verticalCenter: parent.verticalCenter
            visible: _placeholderPrefix !== ""
                    && searchInput.text.length > 0
                    && searchInput.text.length < _placeholderPrefix.length
                    && searchInput.text.startsWith("@")
                    && _activePrefixes.indexOf("#") === -1
            text: _placeholderPrefix
            font.family: "Oxanium"
            font.pixelSize: 12
            color: CP.alpha(Colours.textMuted, 0.35)
        }

        // Instructional placeholder when input is empty
        Text {
            id: emptyPlaceholder
            x: searchInput.x
            anchors.verticalCenter: searchInput.verticalCenter
            visible: root.expanded && searchInput.text === "" 
                    && _activePrefixes.indexOf("#") === -1
            text: {
                var remaining = WC.prefixes.filter(function(p) {
                    return p !== "#" && root._activePrefixes.indexOf(p) === -1
                })
                return remaining.join(" ") + (root._activePrefixes.length === 0 ? " #filter" : "")
            }
            font.family: "Oxanium"
            font.pixelSize: 12
            font.letterSpacing: 1
            color: CP.alpha(Colours.textMuted, 0.3)
        }

        // Text input — positioned after badge
        TextInput {
            id: searchInput
            x: _activePrefixes.length > 0 ? prefixRow.width + 6 : 0
            width: parent.width - x - submitBtn.width - stopBtn.width - 12
            height: parent.height
            verticalAlignment: TextInput.AlignVCenter
            font.family: "Oxanium"
            font.pixelSize: 12
            color: Colours.textPrimary
            selectionColor: CP.alpha(CP.cyan, 0.3)

            Behavior on x { NumberAnimation { duration: 150 } }

            Keys.onReturnPressed: event => {
                root.submitSearch()
                event.accepted = true
            }

            Keys.onEnterPressed: event => {
                root.submitSearch()
                event.accepted = true
            }

            Keys.onRightPressed: event => {
                if (searchInput.cursorPosition === searchInput.text.length && root._placeholderPrefix !== "") {
                    root._autocompletePrefix()
                    event.accepted = true
                } else {
                    event.accepted = false
                }
            }

            Keys.onLeftPressed: event => { event.accepted = false }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.closeSearch()
                    root.parent.forceActiveFocus()
                    event.accepted = true
                } else if (event.key === Qt.Key_Backspace && searchInput.cursorPosition === 0 && root._activePrefixes.length > 0) {
                    prefixRemoveAnim.start()
                    root._updatingPrefix = true
                    var newPrefixes = root._activePrefixes.slice()
                    newPrefixes.pop()
                    root._activePrefixes = newPrefixes
                    root._placeholderPrefix = root._randomPlaceholder()
                    if (newPrefixes.indexOf("#") === -1) root.localFilterChanged("")
                    root._updatingPrefix = false
                    event.accepted = true
                }
            }

            onTextChanged: root._updatePrefixState()
        }

        Text {
            id: submitBtn
            anchors.right: stopBtn.visible ? stopBtn.left : parent.right
            anchors.rightMargin: stopBtn.visible ? 6 : 0
            width: 20; height: parent.height
            text: "\u2192"
            font.pixelSize: 14
            color: Colours.accentSecondary
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.submitSearch()
            }
        }

        Text {
            id: stopBtn
            anchors.right: parent.right
            width: root.searching ? 20 : 0; height: parent.height
            text: "\u25A0"
            font.pixelSize: 12
            color: Colours.accentDanger
            verticalAlignment: Text.AlignVCenter
            visible: root.searching
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: controlProc.running = true
            }
        }
    }

    // Prefix glitch animation
    SequentialAnimation {
        id: prefixGlitchAnim
        onStarted: _prefixGlitching = true
        onStopped: _prefixGlitching = false

        PauseAnimation  { duration: 50 }
        PropertyAction  { target: prefixRow; property: "visible"; value: false }
        PauseAnimation  { duration: 40 }
        PropertyAction  { target: prefixRow; property: "visible"; value: true }
        PauseAnimation  { duration: 50 }
        PropertyAction  { target: prefixRow; property: "visible"; value: false }
        PauseAnimation  { duration: 30 }
        PropertyAction  { target: prefixRow; property: "visible"; value: true }
    }

    // Prefix removal glitch animation
    SequentialAnimation {
        id: prefixRemoveAnim
        PropertyAction  { target: prefixRow; property: "visible"; value: false }
        PauseAnimation  { duration: 50 }
        PropertyAction  { target: prefixRow; property: "visible"; value: true }
        PauseAnimation  { duration: 40 }
        PropertyAction  { target: prefixRow; property: "visible"; value: false }
        PauseAnimation  { duration: 30 }
        PropertyAction  { target: prefixRow; property: "visible"; value: true }
    }

    Text {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 4
        text: root.searching ? "SEARCHING..." : ""
        font.family: "Oxanium"
        font.pixelSize: 8
        font.letterSpacing: 1
        color: Colours.accentPrimary
        visible: root.searching
    }

    // ── Search results model ────────────────────────────────
    ListModel { id: searchResultsModel }
    readonly property alias resultsModel: searchResultsModel
    readonly property bool inputFocused: searchInput.activeFocus

    Process {
        id: searchProc
        command: ["true"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                if (data === "START") {
                    if (root._waitingForStart) {
                        searchResultsModel.clear()
                        root._waitingForStart = false
                    }
                    return
                }
                if (root._waitingForStart) return
                if (!root.expanded) return
                if (data === "DONE") {
                    root.searching = false
                    if (root._pageResultCount === 0) root.hasMore = false
                    root._pageResultCount = 0
                    return
                }
                if (data.startsWith("THUMB:")) {
                    var parts = data.substring(6).split("|")
                    if (parts.length >= 3) {
                        var isFirst = searchResultsModel.count === 0
                        var displayName = parts.length >= 7 && parts[6] !== ""
                                        ? parts[6] : parts[0]
                        searchResultsModel.append({
                            fname: displayName,
                            thumbPath: parts[1],
                            fullUrl: parts[2],
                            source: parts.length >= 4 ? parts[3] : "wh",
                            w: parts.length >= 6 ? parseInt(parts[4]) : 0,
                            h: parts.length >= 6 ? parseInt(parts[5]) : 0,
                            fileSize: parts.length >= 8 ? parseInt(parts[7]) : 0,
                            compat: parts.length >= 9 ? parts[8] : ""
                        })
                        root._pageResultCount++
                        if (isFirst) root.firstResultReady()
                    }
                }
            }
        }
    }

    Process {
        id: controlProc
        command: ["bash", "-c", "echo stop > /tmp/wallpaper_search_control"]
        running: false
    }

    Timer {
        id: sortDebounceTimer
        interval: 300
        repeat: false
        onTriggered: root._doResubmit()
    }
}
