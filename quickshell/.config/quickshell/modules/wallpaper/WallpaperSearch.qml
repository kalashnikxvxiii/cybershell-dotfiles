import "../../common/Colors.js" as CP
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
    property bool   _prefixGlitching:   false
    property bool   _updatingPrefix:    false
    property bool   isLocalFilter:      _activePrefixes.indexOf("#")
    property bool   searching:          false
    property bool   expanded:           false
    property bool   hasMore:            true
    property int    _pageResultCount:   0
    property int    currentPage:        1
    property var    _activePrefixes:    []

    // ── Prefix system ────────────────────────────────────
    readonly property var prefixes: ["@wh", "@a", "@r", "@wpe", "@gif", "@img", "@wc", "@rand", "#"]
    readonly property var prefixColors: ({
        "@wh":      CP.cyan,
        "@a":       CP.yellow,
        "@r":       CP.magenta,
        "@wpe":     CP.teal,
        "@gif":     CP.neon,
        "@img":     CP.cyan,
        "@wc":      CP.orange,
        "@rand":    CP.amber,
        "#":        CP.amber
    })

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
        if (searching) {
            controlProc.running = true
            searching = false
        }
        searchResultsModel.clear()
        searchInput.text = ""
        expanded = false
    }

    function loadMore() {
        if (searching || !hasMore || currentQuery === "") return
        currentPage++
        searching = true
        searchProc.command = ["bash",
            "/home/kalashnikxv/.config/quickshell/scripts/search-wallpapers.sh",
            currentQuery, String(currentPage)]
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
        searchResultsModel.clear()
        searchProc.command = ["bash",
            "/home/kalashnikxv/.config/quickshell/scripts/search-wallpapers.sh",
            currentQuery, "1"]
        searchProc.running = true
        searchInput.focus = false
        root.parent.forceActiveFocus()
    }

    function _randomPlaceholder() {
        var remaining = prefixes.filter(function(p) {
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
        for (var i = 0; i < prefixes.length; i++) {
            if (txt.startsWith(prefixes[i] + " ")) {
                var query = txt.substring(prefixes[i].length + 1)
                _updatingPrefix = true
                if (_activePrefixes.indexOf(prefixes[i]) === -1) {
                    var np = _activePrefixes.filter(function(p) { return p !== "#" })
                    np.push(prefixes[i])
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
            for (var j = 0; j < prefixes.length; j++) {
                if (prefixes[j].startsWith(txt) && prefixes[j] !== txt
                    && _activePrefixes.indexOf(prefixes[j]) === -1
                    && prefixes[j] !== "#") {
                    _placeholderPrefix = prefixes[j]
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
                Rectangle {
                    height: 20
                    radius: 3
                    width: chipMeasure.implicitWidth + 10
                    color: CP.alpha(root.prefixColors[modelData] || CP.cyan, 0.15)
                    border.color: CP.alpha(root.prefixColors[modelData] || CP.cyan, 0.6)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        font.family: "Oxanium"
                        font.pixelSize: 12
                        font.letterSpacing: 1
                        color: root.prefixColors[modelData] || CP.cyan
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
                var remaining = root.prefixes.filter(function(p) {
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
                            fileSize: parts.length >= 8 ? parseInt(parts[7]) : 0
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
}
