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
    property string _activePrefix:      ""
    property string currentQuery:       ""
    property bool   _prefixGlitching:   false
    property bool   _updatingPrefix:    false
    property bool   isLocalFilter:      _activePrefix === "#"
    property bool   searching:          false
    property bool   expanded:           false
    property bool   hasMore:            true
    property int    _pageResultCount:   0
    property int    currentPage:        1

    // ── Prefix system ────────────────────────────────────
    readonly property var prefixes: ["@wh", "@a", "@r", "@wpe", "@gif", "@img", "#"]
    readonly property var prefixColors: ({
        "@wh":      CP.cyan,
        "@a":       CP.yellow,
        "@r":       CP.magenta,
        "@wpe":     CP.teal,
        "@gif":     CP.neon,
        "@img":     CP.cyan,
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
        _activePrefix = ""
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
        if (searchInput.text.trim() === "" && _activePrefix) return
        if (_activePrefix === "#") {
            localFilterChanged(searchInput.text.trim())
            searchInput.focus = false
            root.parent.forceActiveFocus()
            return
        }
        currentQuery = _activePrefix !== ""
                    ? _activePrefix + " " + searchInput.text.trim()
                    : searchInput.text.trim()
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
        return prefixes[Math.floor(Math.random() * prefixes.length)]
    }

    function _updatePrefixState() {
        if (_updatingPrefix) return
        var txt = searchInput.text
        // If prefix already active and text doeasn't start with @, keep it
        if (_activePrefix !== "" && _activePrefix !== "#" && !txt.startsWith("@")) return
        // Check for completed prefix (prefix + space)
        for (var i = 0; i < prefixes.length; i++) {
            if (txt.startsWith(prefixes[i] + " ")) {
                var query = txt.substring(prefixes[i].length + 1)
                _updatingPrefix = true
                _activePrefix = prefixes[i]
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
            if (_activePrefix !== "#") {
                _activePrefix = "#"
                placeholderPrefix = ""
                prefixGlitchAnim.restart()
            }
            localFilterChanged(searchInput.text)
            return
        }
        // Check for partial match
        if (txt.startsWith("@") && txt.indexOf(" ") === -1) {
            for (var j = 0; j < prefixes.length; j++) {
                if (prefixes[j].startsWith(txt) && prefixes[j] !== txt) {
                    _placeholderPrefix = prefixes[j]
                    _activePrefix = ""
                    return
                }
            }
        }
        // Live local filter update
        if (_activePrefix === "#") {
            localFilterChanged(txt)
            return
        }
        _placeholderPrefix = ""
        _activePrefix = ""
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

        // Prefix highlight badge
        Rectangle {
            id: prefixBadge
            x: 0
            anchors.verticalCenter: parent.verticalCenter
            width: {
                if (_activePrefix === "#")
                    return hashMeasure.implicitWidth + 14
                if (_activePrefix !== "")
                    return prefixMeasure.implicitWidth + 10
                return 0
            }
            height: 20
            radius: 3
            color: _activePrefix !== "" ? CP.alpha(prefixColors[_activePrefix] || CP.cyan, 0.15) : "transparent"
            border.color: _activePrefix !== "" ? CP.alpha(prefixColors[_activePrefix] || CP.cyan, 0.6) : "transparent"
            border.width: 1
            visible: _activePrefix !== "" && !_prefixGlitching
            z: 5

            Behavior on width { NumberAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: _activePrefix === "#" ? "# " +searchInput.text : _activePrefix 
                font.family: "Oxanium"
                font.pixelSize: 12
                font.letterSpacing: 1
                color: prefixColors[_activePrefix] || CP.cyan
                visible: _activePrefix !== "#"
            }

            Text {
                id: hashLabel
                anchors.left: parent.left
                anchors.leftMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                text: "#"
                font.family: "Oxanium"
                font.pixelSize: 12
                font.letterSpacing: 1
                color: prefixColors["#"] || CP.cyan
                visible: _activePrefix === "#"
            }

            Text {
                id: prefixMeasure
                visible: false
                text: _activePrefix + " "
                font.family: "Oxanium"
                font.pixelSize: 12
            }

            Text {
                id: hashMeasure
                visible: false
                text: "# " + searchInput.text
                font.family: "Oxanium"
                font.pixelSize: 12
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
                    && _activePrefix === ""
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
            visible: root.expanded && searchInput.text === "" && _activePrefix === ""
            text: "@wh @a @r @gif @img @wpe #filter"
            font.family: "Oxanium"
            font.pixelSize: 12
            font.letterSpacing: 1
            color: CP.alpha(Colours.textMuted, 0.3)
        }

        // Text input — positioned after badge
        TextInput {
            id: searchInput
            x: {
                if (_activePrefix === "#") return hashLabel.x + hashLabel.implicitWidth + 2
                if (_activePrefix !== "") return prefixBadge.width + 4
                return 0
            }
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

            Keys.onLeftPressed: event => { event.accepted = true }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.closeSearch()
                    root.parent.forceActiveFocus()
                    event.accepted = true
                } else if (event.key === Qt.Key_Backspace && searchInput.cursorPosition === 0 && root._activePrefix !== "") {
                    prefixRemoveAnim.start()
                    root._updatingPrefix = true
                    root._activePrefix = ""
                    root._placeholderPrefix = root._randomPlaceholder()
                    root.localFilterChanged("")
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
        property color glitchColor: prefixColors[_activePrefix] || CP.cyan

        onStarted: _prefixGlitching = true
        onStopped: _prefixGlitching = false

        PropertyAction { target: prefixBadge; property: "visible"; value: true }
        PropertyAction { target: prefixBadge; property: "color"; value: CP.alpha(CP.magenta, 0.3) }
        PropertyAction { target: prefixBadge; property: "border.color"; value: CP.magenta }
        PauseAnimation { duration: 60 }

        PropertyAction { target: prefixBadge; property: "color"; value: CP.alpha(CP.yellow, 0.3) }
        PropertyAction { target: prefixBadge; property: "border.color"; value: CP.yellow }
        PauseAnimation { duration: 60 }

        PropertyAction { target: prefixBadge; property: "color"; value: CP.alpha(prefixGlitchAnim.glitchColor, 0.15) }
        PropertyAction { target: prefixBadge; property: "border.color"; value: CP.alpha(prefixGlitchAnim.glitchColor, 0.6) }
        PauseAnimation { duration: 60 }

        PropertyAction { target: prefixBadge; property: "visible"; value: false }
        PauseAnimation { duration: 40 }

        PropertyAction { target: prefixBadge; property: "visible"; value: true }
    }

    // Prefix removal glitch animation
    SequentialAnimation {
        id: prefixRemoveAnim

        PropertyAction { target: prefixBadge; property: "visible"; value: true }
        PropertyAction { target: prefixBadge; property: "border.color"; value: CP.magenta }
        PropertyAction { target: prefixBadge; property: "color"; value: CP.alpha(CP.magenta, 0.3) }
        PauseAnimation { duration: 50 }

        PropertyAction { target: prefixBadge; property: "border.color"; value: CP.yellow }
        PropertyAction { target: prefixBadge; property: "color"; value: CP.alpha(CP.yellow, 0.2) }
        PauseAnimation { duration: 50 }

        PropertyAction { target: prefixBadge; property: "visible"; value: true }
        PauseAnimation { duration: 40 }

        PropertyAction { target: prefixBadge; property: "visible"; value: true }
        PropertyAction { target: prefixBadge; property: "color"; value: "transparent" }
        PropertyAction { target: prefixBadge; property: "border.color"; value: "transparent" }
        PauseAnimation { duration: 30 }

        PropertyAction { target: prefixBadge; property: "visible"; value: false }
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
                            h: parts.length >= 6 ? parseInt(parts[5]) : 0
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
