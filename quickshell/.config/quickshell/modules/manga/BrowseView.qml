// BrowseView.qml — search and cover grid. Default ordering is
// latestUploadedChapter and not followedCount: the most-followed titles are
// almost all delisted for licensing, so that ordering surfaces series whose
// chapters cannot be read (see MANGA-DESIGN.md §10).
import "../../common/Colors.js" as CP
import "../../common"
import QtQuick
import QtQuick.Effects

Item {
    id: root

    signal seriesActivated(var manga)
    signal escaped()

    // "title" searches the series name; "author" resolves the typed name to an
    // author uuid first, because MangaDex has no free-text author filter.
    property string searchMode: "title"
    property var    selectedTags: []
    property var    selectedAuthor: null
    property bool   genresOpen: false

        // Appending only the new rows is what preserves the scroll position.
    // Reassigning the model sends the view back to the top: verified, both an
    // array and an integer count behave that way, a ListModel append does not.
    ListModel { id: gridModel }

    function _syncModel() {
        var r = MangaService.results
        for (var i = gridModel.count; i < r.length; i++)
            gridModel.append({
                mid:     r[i].id,
                mtitle:  r[i].title,
                mcover:  r[i].cover,
                mrating: r[i].contentRating,
                msrc:    Object.keys(r[i].sources || {}).join("+")
            })
    }

    Connections {
        target: MangaService
        function onSeriesLoaded() { root._syncModel() }
    }

    // -- Search field -----------------------------------
    CutShape {
        id: searchBox
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 30
        fillColor: CP.alpha(CP.void2, 0.6)
        strokeColor: CP.alpha(Colours.accentSecondary, searchInput.activeFocus ? 0.9 : 0.35)
        strokeWidth: 1
        inset: 0.5
        cutBottomRight: 10
        Behavior on strokeColor { CAnim {} }

        Text {
            id: searchIcon
            anchors.left: parent.left
            anchors.leftMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            text: String.fromCodePoint(0xF0349)   // nf-md-magnify
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            color: CP.alpha(Colours.accentSecondary, 0.7)
        }

        // Switches what the field means. Author mode needs a second round trip
        // to resolve the name, so it cannot just be another query parameter.
        CutShape {
            id: modeChip
            visible: MangaState.source !== "mangaworld"
            anchors.right: parent.right
            anchors.rightMargin: 5
            anchors.verticalCenter: parent.verticalCenter
            width: modeLabel.implicitWidth + 14
            height: 18
            fillColor: root.searchMode === "author"
                       ? CP.alpha(Colours.accentPrimary, 0.85) : "transparent"
            strokeColor: CP.alpha(Colours.accentPrimary,
                                  root.searchMode === "author" ? 1.0 : 0.4)
            strokeWidth: 1
            inset: 0.5
            cutBottomRight: 5
            Behavior on fillColor   { CAnim {} }
            Behavior on strokeColor { CAnim {} }

            Text {
                id: modeLabel
                anchors.centerIn: parent
                text: root.searchMode === "author" ? "AUTHOR" : "TITLE"
                font.family: "Oxanium"
                font.pixelSize: 10
                font.letterSpacing: 1.5
                font.bold: true
                color: root.searchMode === "author"
                       ? CP.void_ : CP.alpha(Colours.accentPrimary, 0.75)
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.searchMode = root.searchMode === "author" ? "title" : "author"
                    root.selectedAuthor = null
                    MangaService.authorMatches = []
                    // Re-run whatever the field now means. In author mode the
                    // text is a name to resolve, not a title, so a plain reload
                    // would search for an empty title and quietly drop it.
                    if (root.searchMode === "author" && searchInput.text.length > 0)
                        MangaService.searchAuthors(searchInput.text)
                    else
                        root.reload()
                }
            }
        }

        // Clears the search and goes back to the default listing. Without it the
        // only way out of a search was emptying the field by hand and pressing
        // Enter, which is not a way out anybody finds.
        Text {
            id: clearBtn
            visible: searchInput.text.length > 0
            anchors.right: modeChip.visible ? modeChip.left : parent.right
            anchors.rightMargin: modeChip.visible ? 6 : 9
            anchors.verticalCenter: parent.verticalCenter
            text: String.fromCodePoint(0xF0156)   // nf-md-close
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            color: clearMa.containsMouse ? CP.red : CP.alpha(Colours.textMuted, 0.7)
            Behavior on color { CAnim {} }

            MouseArea {
                id: clearMa
                anchors.fill: parent
                anchors.margins: -5
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.clearField()
            }
        }

        TextInput {
            id: searchInput
            anchors.left: searchIcon.right
            anchors.leftMargin: 8
            anchors.right: clearBtn.visible ? clearBtn.left
                         : modeChip.visible ? modeChip.left : parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            font.family: "Oxanium"
            font.pixelSize: 13
            font.letterSpacing: 1
            color: Colours.textPrimary
            clip: true
            onAccepted: {
                if (root.searchMode === "author")
                    MangaService.searchAuthors(searchInput.text)
                else
                    root.reload()
            }

            // First Escape leaves the search field, it does not close the
            // panel: accepting the event stops it from bubbling up.
            Keys.onEscapePressed: event => {
                searchInput.focus = false
                // Releasing focus is not enough: it must be handed back, or
                // every later Escape lands nowhere.
                root.escaped()
                event.accepted = true
            }

            Text {
                anchors.fill: parent
                visible: searchInput.text.length === 0
                text: root.searchMode === "author" ? "SEARCH AN AUTHOR"
                                                  : "SEARCH A SERIES"
                font: searchInput.font
                color: CP.alpha(Colours.textMuted, 0.5)
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // -- Status line ------------------------------------
    Text {
        id: status
        anchors.top: searchBox.bottom
        anchors.topMargin: 12
        anchors.left: parent.left
        text: MangaService.countingAuthors ? "◢ RESOLVING AUTHORS…"
            : MangaService.loading   ? "◢ SEARCHING…"
            : MangaService.error     ? "◢ ERROR: " + MangaService.error
            : MangaService.results.length === 0 ? "◢ NO RESULTS"
            : "◢ " + MangaService.results.length + " OF " + MangaService.total
        font.family: "Oxanium"
        font.pixelSize: 9
        font.letterSpacing: 2
        font.bold: true
        color: MangaService.error ? CP.red : CP.alpha(Colours.accentSecondary, 0.8)
    }

    // -- NSFW toggle ------------------------------
    // Red accent and an explicit click: this panel is a fullscreen overlay, so
    // it must never widen the ratings by accident.
    CutShape {
        id: nsfwBtn
        visible: MangaState.source !== "mangaworld"
        anchors.top: searchBox.bottom
        anchors.topMargin: 4
        anchors.right: parent.right
        width: nsfwLabel.implicitWidth + 14
        height: 16
        fillColor: MangaState.nsfwEnabled ? CP.alpha(CP.red, 0.85) : "transparent"
        strokeColor: CP.alpha(CP.red, MangaState.nsfwEnabled ? 1.0 : 0.4)
        strokeWidth: 1
        inset: 0.5
        cutBottomRight: 5
        Behavior on fillColor   { CAnim {} }
        Behavior on strokeColor { CAnim {} }

        Text {
            id: nsfwLabel
            anchors.centerIn: parent
            text: "NSFW"
            font.family: "Oxanium"
            font.pixelSize: 10
            font.letterSpacing: 1.5
            font.bold: true
            color: MangaState.nsfwEnabled ? "white" : CP.alpha(CP.red, 0.75)
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                MangaState.nsfwEnabled = !MangaState.nsfwEnabled
                MangaState.save()
                root.reload()
            }
        }
    }

    // -- Source selector --------------------------------
    // Three states rather than two: ALL merges both catalogues into one grid,
    // folding a series that exists in both into a single row. The filters below
    // only mean something for MangaDex, so they follow it.
    CutShape {
        id: srcBtn
        anchors.top: searchBox.bottom
        anchors.topMargin: 4
        anchors.right: genresBtn.visible ? genresBtn.left : parent.right
        anchors.rightMargin: genresBtn.visible ? 6 : 0
        readonly property string mode: MangaState.source
        readonly property color tint: mode === "all" ? CP.yellow
                                    : mode === "mangaworld" ? CP.neon
                                    : Colours.accentSecondary
        width: srcLabel.implicitWidth + 14
        height: 16
        fillColor: CP.alpha(tint, 0.85)
        strokeColor: tint
        strokeWidth: 1
        inset: 0.5
        cutBottomRight: 5
        Behavior on fillColor   { CAnim {} }
        Behavior on strokeColor { CAnim {} }

        Text {
            id: srcLabel
            anchors.centerIn: parent
            text: srcBtn.mode === "all" ? "ALL SOURCES"
                : srcBtn.mode === "mangaworld" ? "MANGAWORLD" : "MANGADEX"
            font.family: "Oxanium"
            font.pixelSize: 10
            font.letterSpacing: 1.5
            font.bold: true
            color: CP.void_
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                MangaState.source = MangaState.source === "all" ? "mangadex"
                                  : MangaState.source === "mangadex" ? "mangaworld" : "all"
                MangaService.source = MangaState.source
                // Filters that only exist on one catalogue are dropped rather
                // than carried across, where they would silently do nothing.
                root.selectedTags = []
                root.selectedAuthor = null
                root.searchMode = "title"
                MangaService.authorMatches = []
                root.reload()
            }
        }
    }

    // -- Genres toggle ----------------------------------
    CutShape {
        id: genresBtn
        visible: MangaState.source !== "mangaworld"
        anchors.top: searchBox.bottom
        anchors.topMargin: 4
        anchors.right: nsfwBtn.left
        anchors.rightMargin: 6
        width: genresLabel.implicitWidth + 14
        height: 16
        fillColor: root.selectedTags.length > 0
                   ? CP.alpha(Colours.accentSecondary, 0.85) : "transparent"
        strokeColor: CP.alpha(Colours.accentSecondary,
                              root.genresOpen || root.selectedTags.length > 0 ? 1.0 : 0.4)
        strokeWidth: 1
        inset: 0.5
        cutBottomRight: 5
        Behavior on fillColor   { CAnim {} }
        Behavior on strokeColor { CAnim {} }

        Text {
            id: genresLabel
            anchors.centerIn: parent
            text: root.selectedTags.length > 0 ? "GENRES " + root.selectedTags.length : "GENRES"
            font.family: "Oxanium"
            font.pixelSize: 10
            font.letterSpacing: 1.5
            font.bold: true
            color: root.selectedTags.length > 0
                   ? CP.void_ : CP.alpha(Colours.accentSecondary, 0.75)
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.genresOpen = !root.genresOpen
        }
    }

    // -- Genre chips, collapsible -----------------------
    // Kept out of the way by default: 25 chips would eat a third of a 520px
    // panel that exists to show covers.
    Item {
        id: genrePanel
        anchors.top: status.bottom
        anchors.topMargin: root.genresOpen ? 8 : 0
        anchors.left: parent.left
        anchors.right: parent.right
        clip: true
        height: root.genresOpen ? genreFlow.implicitHeight : 0
        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Flow {
            id: genreFlow
            width: parent.width
            spacing: 4

            Repeater {
                model: MangaService.genres
                delegate: CutShape {
                    id: chip
                    required property var modelData
                    readonly property bool on: root.selectedTags.indexOf(modelData.id) >= 0
                    width: chipLabel.implicitWidth + 12
                    height: 18
                    fillColor: on ? CP.alpha(Colours.accentSecondary, 0.85) : "transparent"
                    strokeColor: CP.alpha(Colours.accentSecondary, on ? 1.0 : 0.3)
                    strokeWidth: 1
                    inset: 0.5
                    cutBottomRight: 5
                    Behavior on fillColor   { CAnim {} }
                    Behavior on strokeColor { CAnim {} }

                    Text {
                        id: chipLabel
                        anchors.centerIn: parent
                        text: chip.modelData.name.toUpperCase()
                        font.family: "Oxanium"
                        font.pixelSize: 9
                        font.letterSpacing: 1
                        font.bold: true
                        color: chip.on ? CP.void_ : CP.alpha(Colours.textMuted, 0.85)
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleTag(chip.modelData.id)
                    }
                }
            }
        }
    }

    // -- Author matches ---------------------------------
    // A name like "oda" returns a dozen near-duplicate records, most of them
    // stubs with a single work, so the choice has to be the user's.
    Item {
        id: authorPanel
        anchors.top: genrePanel.bottom
        anchors.topMargin: visible ? 8 : 0
        anchors.left: parent.left
        anchors.right: parent.right
        height: visible ? authorFlow.implicitHeight : 0
        visible: root.searchMode === "author" && MangaService.authorMatches.length > 0
        clip: true

        Flow {
            id: authorFlow
            width: parent.width
            spacing: 4

            Repeater {
                model: MangaService.authorMatches
                delegate: CutShape {
                    id: aChip
                    required property var modelData
                    readonly property bool on: root.selectedAuthor
                                               && root.selectedAuthor.id === modelData.id
                    width: aLabel.implicitWidth + 12
                    height: 18
                    fillColor: on ? CP.alpha(Colours.accentPrimary, 0.85) : "transparent"
                    strokeColor: CP.alpha(Colours.accentPrimary, on ? 1.0 : 0.3)
                    strokeWidth: 1
                    inset: 0.5
                    cutBottomRight: 5
                    Behavior on fillColor { CAnim {} }

                    Text {
                        id: aLabel
                        anchors.centerIn: parent
                        text: aChip.modelData.name + "  " + aChip.modelData.works
                        font.family: "Oxanium"
                        font.pixelSize: 9
                        font.letterSpacing: 0.5
                        color: aChip.on ? CP.void_ : CP.alpha(Colours.textMuted, 0.85)
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedAuthor = aChip.modelData
                            root.reload()
                        }
                    }
                }
            }
        }
    }

    // -- Cover grid -----------------------------------
    GridView {
        id: grid
        anchors.top: authorPanel.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        cellWidth: Math.floor(width / 3)
        cellHeight: Math.round(cellWidth * 1.45) + 22
        model: gridModel
        boundsBehavior: Flickable.StopAtBounds

        // One row ahead, not two: measured, the second row costs ~37 MB of
        // decoded covers for scrolling comfort that is barely noticeable.
        cacheBuffer: cellHeight

        // Endless scroll: ask for the next page a little before the bottom.
        onContentYChanged: {
            if (MangaService.loading || !MangaService.hasMore) return
            if (contentY + height > contentHeight - cellHeight)
                root.loadMore()
        }

        delegate: Item {
            id: card
            required property int index
            required property string mid
            required property string mtitle
            required property string mcover
            required property string mrating
            required property string msrc
            required property var modelData
            width: grid.cellWidth
            height: grid.cellHeight

            readonly property bool nsfw: mrating === "erotica" || mrating === "pornographic"
            
            // Hover zoom on the whole tile. z is raised so the enlarged card
            // overlaps its neighbours instead of being painted beneath them.
            scale: cardMa.containsMouse ? 1.07 : 1.0
            z: cardMa.containsMouse ? 2 : 0
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            Item {
                id: art
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 3
                width: grid.cellWidth - 6
                height: Math.round(width * 1.45)

                Image {
                    id: cover
                    anchors.fill: parent
                    source: card.mcover
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 256
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                    // Always layered: the mask is what keeps the cover inside
                    // the diagonal cut, otherwise the square image overflows
                    // the corner that the stroke draws. The same effect also
                    // carries the NSFW blur, since an item gets only one.
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: coverMask
                        blurEnabled: card.nsfw && !cardMa.containsMouse
                        blur: 1.0
                        blurMax: 48
                    }
                }

                CutShape {
                    id: coverMask
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true
                    fillColor: "white"
                    cutBottomRight: 10
                }

                // A plain Rectangle would overflow the cut just like the
                // image did, so the scrim is cut to the same shape.
                CutShape {
                    anchors.fill: parent
                    visible: card.nsfw && !cardMa.containsMouse
                    fillColor: CP.alpha(CP.void_, 0.88)
                    cutBottomRight: 10
                    Text {
                        anchors.centerIn: parent
                        text: card.mrating.toUpperCase()
                        font.family: "Oxanium"
                        font.pixelSize: 12
                        font.letterSpacing: 1.5
                        font.bold: true
                        color: CP.alpha(CP.red, 0.9)
                    }
                }

                // Which catalogue this row came from. Only shown while both
                // are in play: with a single source selected the badge would
                // repeat the same word on every card.
                CutShape {
                    visible: MangaState.source === "all"
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 3
                    readonly property bool both: card.msrc.indexOf("+") >= 0
                    readonly property color tint: both ? CP.yellow
                                                : card.msrc === "mangaworld" ? CP.neon
                                                : Colours.accentSecondary
                    width: srcTag.implicitWidth + 8
                    height: 13
                    fillColor: CP.alpha(tint, 0.9)
                    strokeColor: tint
                    strokeWidth: 1
                    inset: 0.5
                    cutTopRight: 4

                    Text {
                        id: srcTag
                        anchors.centerIn: parent
                        text: parent.both ? "MD+MW" : (card.msrc === "mangaworld" ? "MW" : "MD")
                        font.family: "Oxanium"
                        font.pixelSize: 8
                        font.letterSpacing: 0.5
                        font.bold: true
                        color: CP.void_
                    }
                }

                CutShape {
                    anchors.fill: parent
                    fillColor: "transparent"
                    strokeColor: cardMa.containsMouse
                                ? Colours.accentSecondary
                                : CP.alpha(Colours.accentSecondary, 0.25)
                    strokeWidth: 1
                    inset: 0.5
                    cutBottomRight: 10
                    Behavior on strokeColor { CAnim {} }
                }
            }

            Text {
                anchors.top: art.bottom
                anchors.topMargin: 3
                anchors.left: art.left
                anchors.right: art.right
                text: card.mtitle
                font.family: "Oxanium"
                font.pixelSize: 13
                font.letterSpacing: 0.5
                color: cardMa.containsMouse ? Colours.accentSecondary : Colours.textPrimary
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.WordWrap
                Behavior on color { CAnim {} }
            }

            MouseArea {
                id: cardMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.seriesActivated(MangaService.results[card.index])
            }
        }
    }

    // In author mode the typed text is not a title: it has already been turned
    // into an author uuid, so the title field must stay empty or the two
    // filters would cancel each other out.
    readonly property var _opts: ({
        tags: root.selectedTags,
        authorId: root.searchMode === "author" && root.selectedAuthor
                  ? root.selectedAuthor.id : ""
    })

    readonly property string _query:
        root.searchMode === "author" ? "" : searchInput.text

    // Empties the field and nothing else — no refetch, so the results stay put
    // and the grid does not jump while you retype. Focus goes back to the field
    // because clearing a search is almost always the start of another one.
    function clearField() {
        searchInput.text = ""
        searchInput.forceActiveFocus()
    }

    // Back to the default listing. The query goes, and with it the author
    // selection, which only exists as a consequence of a search. Genre filters
    // stay — they have their own visible toggle with a count, so leaving them
    // on is a choice the user can see rather than a hidden leftover.
    function goHome() {
        searchInput.text = ""
        root.selectedAuthor = null
        root.searchMode = "title"
        MangaService.authorMatches = []
        root.reload()
    }

    function reload() {
        gridModel.clear()
        MangaService.fetchSeries(root._query, MangaState.searchLanguages,
                                MangaState.contentRatings, true, root._opts)
    }

    function loadMore() {
        MangaService.fetchSeries(root._query, MangaState.searchLanguages,
                                MangaState.contentRatings, false, root._opts)
    }

    function toggleTag(id) {
        var t = root.selectedTags.slice()
        var i = t.indexOf(id)
        if (i >= 0) t.splice(i, 1)
        else t.push(id)
        root.selectedTags = t
        root.reload()
    }

    // The service is a singleton and keeps its results, but this view is
    // rebuilt by the panel's Loader at every open — so its ListModel starts
    // empty. Without the sync the second open shows nothing until something
    // forces a refetch.
    Component.onCompleted: {
        // The service is a singleton and outlives this view, so the source it
        // holds has to be re-aligned with the persisted choice on every open.
        MangaService.source = MangaState.source
        MangaService.fetchGenres()
        if (MangaService.results.length > 0) _syncModel()
        else reload()
    }
}
