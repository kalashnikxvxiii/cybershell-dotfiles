import "../../common/Colors.js" as CP
import "../../common/effects"
import "../../common"
import QtQuick.Layouts
import QtQuick
import Quickshell

Item {
    id: root

    MouseArea {
        anchors.fill: parent
        onPressed: root.forceActiveFocus()
    }

    property var wallpaperModel: null

    Connections {
        target: PlaylistState
        function onEntryHighlightPathChanged() {
            if (PlaylistState.entryHighlightPath === "") return
            var entries = PlaylistState.entries
            for (var i = 0; i < entries.length; i++) {
                if (entries[i].path === PlaylistState.entryHighlightPath) {
                    Qt.callLater(() => entryGrid.positionViewAtIndex(i, GridView.Center))
                    break
                }
            }
        }
    }

    // ── Background ────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: CP.alpha("#00060e", 0.96)
    }

    Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: 1
        color: CP.alpha(CP.yellow, 0.3)
    }

    ScanlineOverlay {
        anchors.fill: parent
        opacity: 0.04
    }

    // ── Content layout ────────────────────────────────────────────────────
    Item {
        id: topZone
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.height / 3 + (newNameBar.visible ? newNameBar.Layout.preferredHeight + topSections.spacing : 0) - 64

        ColumnLayout {
            id: topSections
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            // ── Header + Selector (combined) ────────────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 114

                // Left: accent bar + title
                Item {
                    id: _headerLeft
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: _titleText.implicitWidth + 42

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.topMargin: 15
                        anchors.bottomMargin: 15
                        width: 5
                        color: Colours.accentPrimary
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 15
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            id: _titleText
                            text: "PLAYLIST"
                            font.family: "Oxanium"
                            font.pixelSize: 48
                            font.letterSpacing: 8
                            color: Colours.accentPrimary
                        }

                        Text {
                            visible: PlaylistState.activeName !== ""
                            text: PlaylistState.activeName.toUpperCase()
                            font.family: "Oxanium"
                            font.pixelSize: 13
                            font.letterSpacing: 3
                            color: Colours.accentSecondary
                        }
                    }
                }

                // Top-Right: close
                Item {
                    id: _closeBtn
                    anchors.right: parent.right
                    anchors.top: parent.top
                    width: 35; height: 35

                    Text {
                        anchors.right: parent.right
                        text: "\u00d7"
                        font.pixelSize: 21
                        color: Colours.textMuted
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PlaylistState.togglePanel()
                    }
                }

                // Bottom-right: add-remove
                Row {
                    id: _actionRow
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    spacing: 6

                    Item {
                        width: 28; height: 28

                        CutShape {
                            anchors.fill: parent
                            fillColor: "transparent"
                            strokeColor: CP.alpha(CP.cyan, 0.3)
                            strokeWidth: 1; inset: 0.5
                            cutTopLeft: 6; cutBottomRight: 6
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            font.pixelSize: 18
                            color: Colours.accentSecondary
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: newNameBar.visible = !newNameBar.visible
                        }
                    }

                    Item {
                        width: 28; height: 28
                        visible: PlaylistState.activeName !== ""

                        CutShape {
                            anchors.fill: parent
                            fillColor: "transparent"
                            strokeColor: CP.alpha(CP.red, 0.3)
                            strokeWidth: 1; inset: 0.5
                            cutTopLeft: 6; cutBottomRight: 6
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "\u2715"
                            font.pixelSize: 14
                            color: Colours.accentDanger
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PlaylistState.requestDeletePlaylist(PlaylistState.activeName)
                        }
                    }
                }
            }

            // ── New playlist name input ──────────────────────────────────────────────────────────────
            Item {
                id: newNameBar
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                visible: false

                CutShape {
                    anchors.fill: parent
                    fillColor: CP.alpha(CP.cyan, 0.06)
                    strokeColor: _nameInput.text !== "" ? CP.alpha(CP.yellow, 0.7) : CP.alpha(CP.cyan, 0.3)
                    strokeWidth: 1; inset: 0.5
                    cutTopLeft: 12; cutBottomRight: 12
                    Behavior on strokeColor { ColorAnimation { duration: 150 } }
                }
                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 15
                    anchors.rightMargin: 15
                    text: "playlist name..."
                    visible: _nameInput.text === ""
                    verticalAlignment: Text.AlignVCenter
                    font.family: "Oxanium"
                    font.pixelSize: 16
                    color: CP.alpha(Colours.textMuted, 0.4)
                }
                TextInput {
                    id: _nameInput
                    anchors.fill: parent
                    anchors.leftMargin: 15
                    anchors.rightMargin: 15
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: "Oxanium"
                    font.pixelSize: 16
                    color: Colours.textPrimary

                    onAccepted: {
                        var n = text.trim().replace(/[\s\/]+/g, "-").replace(/[^a-zA-Z0-9\-_]/g, "")
                        if (n !== "") PlaylistState.createPlaylist(n)
                        text = ""
                        newNameBar.visible = false
                        root.forceActiveFocus()
                    }

                    Keys.priority: Keys.AfterItem
                    Keys.onLeftPressed: (event) => event.accepted = true
                    Keys.onRightPressed: (event) => event.accepted = true
                    Keys.onEscapePressed: {
                        text = ""
                        newNameBar.visible = false
                        root.forceActiveFocus()
                    }
                }
            }

            // ── Configs ────────────────────────────────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 84

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 6

                    // row 1: timing
                    RowLayout{
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 0

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            CutShape {
                                anchors.fill: parent
                                fillColor: CP.alpha(CP.cyan, 0.08)
                                strokeColor: CP.alpha(CP.cyan, 0.3)
                                strokeWidth: 1; inset: 0.5
                                cutTopLeft: 9
                            }
                            Text {
                                id: _modeTxt
                                anchors.centerIn: parent
                                text: PlaylistState.intervalMode === "fixed" ? "FIXED" : "PER-ENTRY"
                                font.family: "Oxanium"
                                font.pixelSize: 14
                                font.letterSpacing: 2
                                color: Colours.accentSecondary
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: PlaylistState.setPlaylistProp("intervalMode",
                                    PlaylistState.intervalMode === "fixed" ? "per_entry" : "fixed")
                            }
                        }

                        // Global interval input (fixed mode only)
                        Item {
                            id: _intervalSlot
                            Layout.preferredWidth: 150
                            Layout.fillHeight: true
                            visible: PlaylistState.intervalMode === "fixed"

                            readonly property int _totalSec:    PlaylistState.interval
                            readonly property int _h:           Math.floor(_totalSec / 3600)
                            readonly property int _m:           Math.floor((_totalSec % 3600) / 60)
                            readonly property int _s:           _totalSec % 60

                            function _pad(n) { return n < 10 ? "0" + n : n.toString() }

                            function _commit() {
                                var h = parseInt(_hInput.text) || 0
                                var m = parseInt(_mInput.text) || 0
                                var s = parseInt(_sInput.text) || 0
                                PlaylistState.setPlaylistProp("interval", h * 3600 + m * 60 + s)
                            }
                            function _revert() {
                                _hInput.text = _pad(_h)
                                _mInput.text = _pad(_m)
                                _sInput.text = _pad(_s)
                            }

                            readonly property bool _disabled: _h === 0 && _m === 0 && _s === 0
                            readonly property bool _dirty: 
                                (parseInt(_hInput.text) || 0) !== _h
                                || (parseInt(_mInput.text) || 0) !== _m
                                || (parseInt(_sInput.text) || 0) !== _s

                            CutShape {
                                anchors.fill: parent
                                fillColor: CP.alpha(CP.cyan, 0.07)
                                strokeColor: _intervalSlot._dirty ? CP.alpha(CP.yellow, 0.7) : CP.alpha(CP.cyan, 0.25)
                                strokeWidth: 1; inset: 0.5
                                cutBottomRight: 9; showLeft: _intervalSlot._dirty ? true : false
                                Behavior on strokeColor { ColorAnimation { duration: 150 } }
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 0

                                TextInput {
                                    id: _hInput
                                    width: 22
                                    maximumLength: 2
                                    selectByMouse: true
                                    horizontalAlignment: TextInput.AlignHCenter
                                    verticalAlignment: TextInput.AlignVCenter
                                    font.family: "Oxanium"; font.pixelSize: 15
                                    color: _intervalSlot._disabled ? Colours.textMuted : Colours.accentPrimary
                                    validator: IntValidator { bottom: 0; top: 99 }

                                    onActiveFocusChanged: if (activeFocus) selectAll()
                                    onTextChanged: if (activeFocus) _intervalSlot._commit()

                                    Binding {
                                        target: _hInput
                                        property: "text"
                                        value: _intervalSlot._pad(_intervalSlot._h)
                                        when: !_hInput.activeFocus
                                    }
                                    
                                    WheelHandler {
                                        acceptedDevices: PointerDevice.Mouse
                                        onWheel: event => {
                                            var v = _intervalSlot._h + (event.angleDelta.y > 0 ? 1 : -1)
                                            v = math.max(0, Math.min(99, v))
                                            PlaylistState.setPlaylistProp("interval",
                                                v * 3600 + _intervalSlot._m * 60 + _intervalSlot._s)
                                        }
                                    }

                                    onAccepted: root.forceActiveFocus()
                                    Keys.onEscapePressed: root.forceActiveFocus()
                                    Keys.priority: Keys.AfterItem
                                    Keys.onLeftPressed: (event) => event.accepted = true
                                    Keys.onRightPressed: (event) => event.accepted = true
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "h:"; font.family: "Oxanium"; font.pixelSize: 14; color: Colours.textMuted
                                }

                                TextInput {
                                    id: _mInput
                                    width: 22
                                    maximumLength: 2
                                    selectByMouse: true
                                    horizontalAlignment: TextInput.AlignHCenter
                                    verticalAlignment: TextInput.AlignVCenter
                                    font.family: "Oxanium"; font.pixelSize: 15
                                    color: _intervalSlot._disabled ? Colours.textMuted : Colours.accentPrimary
                                    validator: IntValidator { bottom: 0; top: 59 }

                                    onActiveFocusChanged: if (activeFocus) selectAll()
                                    onTextChanged: if (activeFocus) _intervalSlot._commit()

                                    Binding {
                                        target: _mInput
                                        property: "text"
                                        value: _intervalSlot._pad(_intervalSlot._m)
                                        when: !_mInput.activeFocus
                                    }

                                    WheelHandler {
                                        acceptedDevices: PointerDevice.Mouse
                                        onWheel: event => {
                                            var v = _intervalSlot._m + (event.angleDelta.y > 0 ? 1 : -1)
                                            v = Math.max(0, Math.min(99, v))
                                            PlaylistState.setPlaylistProp("interval",
                                                _intervalSlot._h * 3600 + v * 60 + _interval._s)
                                        }
                                    }
                                    onAccepted: root.forceActiveFocus()
                                    Keys.onEscapePressed: root.forceActiveFocus()
                                    Keys.priority: Keys.AfterItem
                                    Keys.onLeftPressed: (event) => event.accepted = true
                                    Keys.onRightPressed: (event) => event.accepted = true
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "m:"; font.family: "Oxanium"; font.pixelSize: 14; color: Colours.textMuted
                                }

                                TextInput {
                                    id: _sInput
                                    width: 22
                                    maximumLength: 2
                                    selectByMouse: true
                                    horizontalAlignment: TextInput.AlignHCenter
                                    verticalAlignment: TextInput.AlignVCenter
                                    font.family: "Oxanium"; font.pixelSize: 15
                                    color: _intervalSlot._disabled ? Colours.textMuted : Colours.accentPrimary
                                    validator: IntValidator { bottom: 0; top: 59 }

                                    onActiveFocusChanged: if (activeFocus) selectAll()
                                    onTextChanged: if (activeFocus) _intervalSlot._commit()

                                    Binding {
                                        target: _sInput
                                        property: "text"
                                        value: _intervalSlot._pad(_intervalSlot._s)
                                        when: !_sInput.activeFocus
                                    }

                                    WheelHandler {
                                        acceptedDevices: PointerDevice.Mouse
                                        onWheel: event => {
                                            var v = _intervalSlot._s + (event.angleDelta.y > 0 ? 1 : -1)
                                            v = Math.max(0, Math.min(59, v))
                                            PlaylistState.setPlaylistProp("interval",
                                                _intervalSlot._h * 3600 + _intervalSlot._m * 60 + v)
                                        }
                                    }

                                    onAccepted: root.forceActiveFocus()
                                    Keys.onEscapePressed: root.forceActiveFocus()
                                    Keys.priority: Keys.AfterItem
                                    Keys.onLeftPressed: (event) => event.accepted = true
                                    Keys.onRightPressed: (event) => event.accepted = true
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "s"; font.family: "Oxanium"; font.pixelSize: 14; color: Colours.textMuted
                                }
                            }
                        }
                    }

                    // Row 2: playback
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 6

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            CutShape {
                                anchors.fill: parent
                                fillColor: PlaylistState.shuffle ? CP.alpha(CP.yellow, 0.12) : "transparent"
                                strokeColor: PlaylistState.shuffle ? Colours.accentPrimary : CP.alpha(CP.yellow, 0.2)
                                strokeWidth: 1; inset: 0.5
                                cutBottomRight: 9
                            }
                            Text {
                                id: _shufTxt
                                anchors.centerIn: parent
                                text: "\u21c5 SHUF"
                                font.family: "Oxanium"
                                font.pixelSize: 14
                                font.letterSpacing: 2
                                color: PlaylistState.shuffle ? Colours.accentPrimary : Colours.textMuted
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: PlaylistState.setPlaylistProp("shuffle", !PlaylistState.shuffle)
                            }
                        }

                        // Screen mode toggle
                        Item {
                            id: _screenSel
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            property bool   _dropdownOpen:  false
                            property var    _options:   {
                                var arr = ["both"]
                                for (var i = 0; i < Quickshell.screens.length; i++)
                                    arr.push(Quickshell.screens[i].name)
                                return arr
                            }

                            function _cycle(dir) {
                                var idx = _options.indexOf(PlaylistState.screenMode)
                                if (idx < 0) idx = 0
                                idx = (idx + dir + _options.length) % _options.length
                                PlaylistState.setPlaylistProp("screenMode", _options[idx])
                            }
                            function _label(v) { return v === "both" ? "BOTH" : v.toUpperCase() }

                            CutShape {
                                anchors.fill: parent
                                fillColor: "transparent"
                                strokeColor: CP.alpha(CP.cyan, _screenSel._dropdownOpen ? 0.4 : 0.2)
                                strokeWidth: 1; inset: 0.5
                                cutTopLeft: 9; cutBottomRight: 9
                            }
                            Text {
                                anchors.centerIn: parent
                                text: _screenSel._label(PlaylistState.screenMode)
                                font.family: "Oxanium"
                                font.pixelSize: 14
                                font.letterSpacing: 2
                                color: PlaylistState.screenMode === "both" ? Colours.textMuted : Colours.accentSecondary
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: _screenSel._dropdownOpen = !_screenSel._dropdownOpen
                                onWheel: wheel => {
                                    _screenSel._cycle(wheel.angleDelta.y > 0 ? -1 : 1)
                                    wheel.accepted = true
                                }
                            }
                        }
                    }
                }
            }

            // ── Play controls ────────────────────────────────────
            Item {
                id: _playControls
                Layout.fillWidth: true
                Layout.fillHeight: true

                CutShape {
                    anchors.fill: parent
                    fillColor: CP.alpha(CP.void2, 0.5)
                    strokeColor: CP.alpha(CP.cyan, 0.15)
                    strokeWidth: 1; inset: 0.5
                    cutTopLeft: 6; cutBottomRight: 6
                }

                property int _btnH: Math.min(_playControls.height - 10, 44)

                // Play / Pause
                Item {
                    id: _playBtn
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(_playControls._btnH * 1.2)
                    height: _playControls._btnH

                    CutShape {
                        anchors.fill: parent
                        fillColor: PlaylistState.isPlaying ? CP.alpha(CP.cyan, 0.2) : "transparent"
                        strokeColor: PlaylistState.isPlaying ? Colours.accentSecondary : CP.alpha(CP.cyan, 0.3)
                        strokeWidth: 1; inset: 0.5
                        cutTopLeft: 5; cutBottomRight: 5
                    }
                    Text {
                        anchors.centerIn: parent
                        text: PlaylistState.isPlaying ? "\u23f8" : "\u25b6"
                        font.pixelSize: Math.round(parent.height * 0.4)
                        color: PlaylistState.isPlaying ? Colours.accentSecondary : Colours.textMuted
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PlaylistState.isPlaying ? PlaylistState.pause() : PlaylistState.play()
                    }
                }

                // Prev
                Item {
                    anchors.right: _playBtn.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: _playControls._btnH 
                    height: _playControls._btnH

                    Text {
                        anchors.centerIn: parent
                        text: "\u23ee"
                        font.pixelSize: Math.round(_playControls._btnH * 0.4)
                        color: Colours.textMuted
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PlaylistState.prev()
                    }
                }

                // Next
                Item {
                    id: _nextBtn
                    anchors.left: _playBtn.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: _playControls._btnH
                    height: _playControls._btnH

                    Text {
                        anchors.centerIn: parent
                        text: "\u23ed"
                        font.pixelSize: Math.round(_playControls._btnH * 0.4)
                        color: Colours.textMuted
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PlaylistState.next()
                    }
                }

                // Stop
                Item {
                    anchors.left: _nextBtn.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: _playControls._btnH
                    height: _playControls._btnH

                    Text {
                        anchors.centerIn: parent
                        text: "\u23f9"
                        font.pixelSize: Math.round(_playControls._btnH * 0.38)
                        color: Colours.accentDanger
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PlaylistState.stop()
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: PlaylistState.entries.length > 0
                        ? (PlaylistState.currentIndex + 1) + "/" + PlaylistState.entries.length
                        : "0/0"
                    font.family: "Oxanium"
                    font.pixelSize: 10
                    color: Colours.textMuted
                }
            }

            // ── Playlist chips (scorrimento orizzontale) ────────────────────
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 22

                Flickable {
                    id: _chipsFlick
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: _clearFilterBtn.visible ? _clearFilterBtn.left : parent.right
                    anchors.rightMargin: _clearFilterBtn.visible ? 6 : 0
                    contentWidth: _chipsRow.implicitWidth
                    contentHeight: height
                    clip: true
                    flickableDirection: Flickable.HorizontalFlick

                    Row {
                        id: _chipsRow
                        height: parent.height
                        spacing: 6

                        Repeater {
                            model: PlaylistState.playlistNames
                            delegate: Item {
                                required property string modelData
                                width: _chipTxt.implicitWidth + 24
                                height: 18
                                anchors.verticalCenter: parent.verticalCenter
                                readonly property bool active: PlaylistState.activeName === modelData
                                readonly property bool highlighted: PlaylistState.highlightFilter.active
                                                                    && PlaylistState.highlightFilter.playlists.indexOf(modelData) >= 0

                                CutShape {
                                    anchors.fill: parent
                                    fillColor: active       ? CP.alpha(CP.yellow, 0.15)
                                            : highlighted   ? CP.alpha(CP.magenta, 0.18)
                                                            : "transparent"
                                    strokeColor: active     ? Colours.accentPrimary
                                            : highlighted   ? CP.alpha(CP.magenta, 0.65)
                                                            : CP.alpha(CP.cyan, 0.2)
                                    strokeWidth: 1; inset: 0.5
                                    cutTopLeft: 9; cutBottomRight: 9
                                }
                                Text {
                                    id: _chipTxt
                                    anchors.centerIn: parent
                                    text: modelData.toUpperCase()
                                    font.family: "Oxanium"
                                    font.pixelSize: 10
                                    font.letterSpacing: 1
                                    color: active       ? Colours.accentPrimary
                                        :  highlighted  ? CP.magenta
                                                        : Colours.textMuted
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (PlaylistState.activeName === modelData)
                                            PlaylistState.deselectPlaylist()
                                        else
                                            PlaylistState.loadPlaylist(modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: _clearFilterBtn
                    visible: PlaylistState.highlightFilter.active
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: _clearTxt.implicitWidth + 14
                    height: 16

                    CutShape {
                        anchors.fill: parent
                        fillColor: CP.alpha(CP.red, 0.12)
                        strokeColor: CP.alpha(CP.red, 0.55)
                        strokeWidth: 1; inset: 0.5
                        cutTopLeft: 3; cutBottomRight: 3
                    }
                    Text {
                        id: _clearTxt
                        anchors.centerIn: parent
                        text: "\u2715 CLEAR"
                        font.family: "Oxanium"
                        font.pixelSize: 7
                        font.letterSpacing: 1
                        color: Colours.accentDanger
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PlaylistState.clearHighlightFilter()
                    }
                }
            }
        }

        // ── Divider ──────────────────────────────────────────
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: CP.alpha(CP.yellow, 0.15)
        }
    }

    // ── Scrollable content area ───────────────────────────
    Item {
        id: _scrollArea
        y: topZone.height
        height: root.height - topZone.height - 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 8
        anchors.rightMargin: 8

        property real   _proxyX:    0
        property real   _proxyY:    0
        property int    _dragIdx:   -1
        property int    _dropIdx:   -1

        readonly property var _dragData: _dragIdx >= 0 && _dragIdx < PlaylistState.entries.length
                                        ? PlaylistState.entries[_dragIdx] : null

        Item { id: _dummyDrag; visible: false }

        Text {
            anchors.centerIn: parent
            visible: PlaylistState.entries.length === 0
            text: "NO ENTRIES\nADD WITH [P] ON A WALLPAPER"
            font.family: "Oxanium"
            font.pixelSize: 10
            font.letterSpacing: 1
            color: CP.alpha(Colours.textMuted, 0.35)
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 1.6
        }

        GridView {
            id: entryGrid
            anchors.fill: parent
            anchors.topMargin: 8
            visible: PlaylistState.entries.length > 0
            clip: true
            cellWidth: Math.floor(width / 2)
            cellHeight: 130
            cacheBuffer: _scrollArea._dragIdx >= 0 ? 999999 : 320
            interactive: _scrollArea._dragIdx < 0
            model: PlaylistState.entries

            delegate: Item {
                id: _del
                width: entryGrid.cellWidth
                height: entryGrid.cellHeight

                required property var modelData
                required property int index

                opacity: _scrollArea._dragIdx === _del.index ? 0.25 : 1.0

                PlaylistCard {
                    anchors.fill: parent
                    anchors.margins: 2
                    index:         _del.index
                    path:          _del.modelData.path
                    type:          _del.modelData.type   || "image"
                    title:         _del.modelData.title  || ""
                    source:        _del.modelData.source || "awww"
                    thumb:         _del.modelData.thumb  || _del.modelData.path
                    entryInterval: _del.modelData.interval || PlaylistState.interval
                    wallpaperModel: root.wallpaperModel
                }

                // Highlight drop target
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    color: "transparent"
                    border.width: 2
                    border.color: _scrollArea._dropIdx === _del.index
                                && _scrollArea._dragIdx >= 0
                                ? CP.alpha(CP.cyan, 0.7) : "transparent"
                    z: 2
                }

                // Drag area - only on thumbnail (not on bar)
                MouseArea {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: parent.height - 36
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    drag.target: _dummyDrag
                    drag.axis: Drag.XAndYAxis
                    drag.threshold: 8
                    preventStealing: true
                    cursorShape: entryGrid.parent._dragIdx >= 0 ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                    property real _pressX:          0
                    property real _pressY:          0
                    property real _lastClickTime:   0
                    property bool _dragStarted:     false

                    onPressed: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            PlaylistState.requestPreview(_del.modelData)
                            return
                        }
                        _pressX = mouse.x
                        _pressY = mouse.y
                        _dragStarted = false
                    }
                    onPositionChanged: (mouse) => {
                        if (!(mouse.buttons & Qt.LeftButton)) return
                        var sa = entryGrid.parent
                        if (!_dragStarted) {
                            var dx = mouse.x - _pressX
                            var dy = mouse.y - _pressY
                            if (dx*dx + dy*dy < 64) return
                            _dragStarted = true
                            var pos0 = mapToItem(sa, mouse.x, mouse.y)
                            sa._dragIdx = _del.index
                            sa._dropIdx = _del.index
                            sa._proxyX = pos0.x
                            sa._proxyY = pos0.y
                            return
                        }
                        if (sa._dragIdx < 0) return
                        var pos = mapToItem(sa, mouse.x, mouse.y)
                        sa._proxyX = pos.x
                        sa._proxyY = pos.y
                        var col = Math.min(1, Math.max(0, Math.floor(pos.x / entryGrid.cellWidth)))
                        var row = Math.max(0, Math.floor((pos.y + entryGrid.contentY) / entryGrid.cellHeight))
                        sa._dropIdx = Math.min(row * 2 + col, PlaylistState.entries.length - 1)

                        var edgeZone = 50
                        var topEdge = entryGrid.y + edgeZone
                        var bottomEdge = entryGrid.y + entryGrid.height - edgeZone
                        if (pos.y < topEdge) {
                            _auotScrollTimer.direction = -1
                            _autoScrollTimer.start()
                        } else if (pos.y > bottomEdge) {
                            _autoScrollTimer.direction = 1
                            _autoScrollTimer.start()
                        } else {
                            _autoScrollTimer.stop()
                            _autoScrollTimer.direction = 0
                        }
                    }
                    onReleased: (mouse) => {
                        if (mouse.button === Qt.RightButton) return
                        _autoScrollTimer.stop()
                        _autoScrollTimer.direction = 0
                        var sa = entryGrid.parent
                        if (!_dragStarted) {
                            // Area X button: 22x16 top-right (card margin 2 + btn margin 3 = 5)
                            var onXBtn = mouse.x >= width - 27 && mouse.x < width - 5
                                        && mouse.y >= 5 && mouse.y < 21
                            if (onXBtn) {
                                PlaylistState.requestDeleteEntry(_del.index)
                            } else {
                                var now = Date.now()
                                if (now - _lastClickTime < 400) {
                                    // Double click -> apply wallpaper
                                    _lastClickTime = 0
                                    PlaylistState.entryApplyRequested(_del.modelData.path)
                                } else {
                                    // Single click -> select wallpaper
                                    _lastClickTime = now
                                    PlaylistState.selectEntry(_del.modelData.path)
                                }
                            }
                            sa._dragIdx = -1
                            sa._dropIdx = -1
                            return
                        }
                        var pos = mapToItem(sa, mouse.x, mouse.y)
                        var col = Math.min(1, Math.max(0, Math.floor(pos.x / entryGrid.cellWidth)))
                        var row = Math.max(0, Math.floor((pos.y + entryGrid.contentY) / entryGrid.cellHeight))
                        var finalIdx = Math.min(row * 2 + col, PlaylistState.entries.length - 1)
                        if (sa._dragIdx >= 0 && finalIdx !== sa._dragIdx)
                            PlaylistState.moveEntry(sa._dragIdx, finalIdx)
                        sa._dragIdx = -1
                        sa._dropIdx = -1
                    }
                }
            }
        }

        Timer {
            id: _autoScrollTimer
            interval: 16
            repeat: true
            property real direction: 0
            onTriggered: {
                if (_scrollArea._dragIdx < 0 || direction === 0) { stop(); return }
                var maxY = Math.max(0, entryGrid.contentHeight - entryGrid.height)
                var newY = Math.max(0, Math.min(maxY, entryGrid.contentY + direction * 8))
                if (newY === entryGrid.contentY) { stop(); direction = 0; return }
                entryGrid.contentY = newY
                var col = Math.min(1, Math.max(0, Math.floor(_scrollArea._proxyX / entryGrid.cellWidth)))
                var row = Math.max(0, Math.floor((_scrollArea._proxyY + entryGrid.contentY) / entryGrid.cellHeight))
                _scrollArea._dropIdx = Math.min(row * 2 + col, PlaylistState.entries.length - 1)
            }
        }

        // Proxy drag - follow the cursor
        Item {
            visible: _scrollArea._dragIdx >= 0
            x: _scrollArea._proxyX - width / 2
            y: _scrollArea._proxyY - height / 2
            width: entryGrid.cellWidth - 4
            height: entryGrid.cellHeight - 4
            z: 10
            opacity: 0.85

            PlaylistCard {
                anchors.fill: parent
                index:          _scrollArea._dragIdx >= 0 ? _scrollArea._dragIdx : 0
                path:           _scrollArea._dragData ? _scrollArea._dragData.path : ""
                type:           _scrollArea._dragData ? (_scrollArea._dragData.type || "image") : "image"
                title:          _scrollArea._dragData ? (_scrollArea._dragData.title || "")     : ""
                source:         _scrollArea._dragData ? (_scrollArea._dragData.source || "awww") : "awww"
                thumb:          _scrollArea._dragData ? (_scrollArea._dragData.thumb || _scrollArea._dragData.path) : ""
                entryInterval:  _scrollArea._dragData ? (_scrollArea._dragData.interval || PlaylistState.interval)  : PlaylistState.interval
            }
        }
    }

    // Screen selector dropdown
    Item {
        id: _screenDropdown
        visible: _screenSel._dropdownOpen
        z: 9999
        readonly property point _btnPos: _screenSel.mapToItem(root, 0, _screenSel.height + 3)
        x: _btnPos.x
        y: _btnPos.y
        width: _screenSel.width
        height: _ddCol.implicitHeight + 4

        CutShape {
            anchors.fill: parent
            fillColor: CP.void2
            strokeColor: CP.alpha(CP.cyan, 0.4)
            strokeWidth: 1; inset: 0.5
            cutTopLeft: 4; cutBottomRight: 4
        }
        Column {
            id: _ddCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 2
            spacing: 0

            Repeater {
                model: _screenSel._options
                delegate: Item {
                    required property string modelData
                    width: parent.width
                    height: 20
                    readonly property bool _active: PlaylistState.screenMode === modelData

                    Rectangle {
                        anchors.fill: parent
                        color: _active
                            ? CP.alpha(CP.cyan, 0.18)
                            : (_optMa.containsMouse ? CP.alpha(CP.cyan, 0.06) : "transparent")
                    }
                    Text {
                        anchors.centerIn: parent
                        text: _screenSel._label(modelData)
                        font.family: "Oxanium"
                        font.pixelSize: 10
                        font.letterSpacing: 1
                        color: _active ? Colours.accentSecondary : Colours.textMuted
                    }
                    MouseArea {
                        id: _optMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            PlaylistState.setPlaylistProp("screenMode", modelData)
                            _screenSel._dropdownOpen = false
                        }
                    }
                }
            }
        }
    }

    Item {
        id: _confirmDialog
        visible: PlaylistState.pendingDelete !== null
        anchors.fill: parent
        z: 10000

        Rectangle {
            anchors.fill: parent
            color: CP.alpha("#000000", 0.65)
            MouseArea {
                anchors.fill: parent
                onClicked: PlaylistState.cancelDelete()
            }
        }

        Item {
            anchors.centerIn: parent
            width: Math.min(parent.width - 40, 300)
            height: 130

            CutShape {
                anchors.fill: parent
                fillColor: CP.void2
                strokeColor: CP.alpha(CP.red, 0.6)
                strokeWidth: 2; inset: 1
                cutTopLeft: 12; cutBottomRight: 12
            }

            Column {
                anchors.centerIn: parent
                spacing: 10

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: PlaylistState.pendingDelete && PlaylistState.pendingDelete.type === "playlist"
                        ? "DELETE PLAYLIST?" : "REMOVE WALLPAPER?"
                    font.family: "Oxanium"
                    font.pixelSize: 12
                    font.letterSpacing: 3
                    color: Colours.accentDanger
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 260
                    horizontalAlignment: Text.AlignHCenter
                    text: PlaylistState.pendingDelete ? PlaylistState.pendingDelete.label.toUpperCase() : ""
                    font.family: "Oxanium"
                    font.pixelSize: 9
                    font.letterSpacing: 1
                    color: Colours.textMuted
                    elide: Text.ElideRight
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12

                    Item {
                        width: _okTxt.implicitWidth + 20
                        height: 24
                        
                        CutShape {
                            anchors.fill: parent
                            fillColor: CP.alpha(CP.red, 0.2)
                            strokeColor: Colours.accentDanger
                            strokeWidth: 1; inset: 0.5
                            cutTopLeft: 4; cutBottomRight: 4
                        }
                        Text {
                            id: _okTxt
                            anchors.centerIn: parent
                            text: "DELETE"
                            font.family: "Oxanium"
                            font.pixelSize: 9
                            font.letterSpacing: 1
                            color: Colours.accentDanger
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PlaylistState.confirmDelete()
                        }
                    }

                    Item {
                        width: _cancelTxt.implicitWidth + 20
                        height: 24

                        CutShape {
                            anchors.fill: parent
                            fillColor:"transparent"
                            strokeColor: CP.alpha(CP.cyan, 0.3)
                            strokeWidth: 1; inset: 0.5
                            cutTopLeft: 4; cutBottomRight: 4
                        }
                        Text {
                            id: _cancelTxt
                            anchors.centerIn: parent
                            text: "CANCEL"
                            font.family: "Oxanium"
                            font.pixelSize: 9
                            font.letterSpacing: 1
                            color: Colours.textMuted
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PlaylistState.cancelDelete()
                        }
                    }
                }
            }
        }
    }
}
