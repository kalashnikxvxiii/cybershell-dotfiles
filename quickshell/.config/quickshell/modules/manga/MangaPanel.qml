// MangaPanel.qml — fullscreen overlay hosting two independent surfaces: the
// browse drawer pinned left, and the reader centred. Geometry and kinetics copy
// the wallpaper picker's playlist panel (WallpaperPicker.qml:2540-2564), only
// wider: 520 instead of 460, for cover grids and long titles.
import "../../common/Colors.js" as CP
import "../../common"
import "../../common/effects"
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    required property var screen
    readonly property bool wantOpen:
        MangaState.panelOpen && screen.name === MangaState.activeScreen

    // The surface outlives wantOpen by the length of the closing animation.
    // Bound directly, the layer would unmap the instant the panel closes and
    // the drawer would never be seen sliding out.
    property bool surfaceVisible: false

    onWantOpenChanged: {
        if (wantOpen) { closeDelay.stop(); root.surfaceVisible = true }
        else if (root.surfaceVisible) closeDelay.restart()
    }

    Timer {
        id: closeDelay
        interval: 340
        onTriggered: root.surfaceVisible = false
    }

    PanelWindow {
        id: win
        screen: root.screen
        WlrLayershell.namespace: "manga-reader"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.wantOpen
            ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        color: "transparent"
        visible: root.surfaceVisible

        // Everything below is inside this Loader: with the panel closed nothing
        // is instantiated, no image is held and no timer runs.
        // Not asynchronous: the entry animation has to start on the first frame,
        // and a deferred build would let the drawer pop in already in place.
        Loader {
            anchors.fill: parent
            active: root.surfaceVisible

            sourceComponent: Item {
                id: content
                focus: true

                // Armed one event-loop turn after the surface exists, so both
                // animations start from their closed values instead of from
                // whatever the defaults happened to be.
                property bool armed: false
                Timer { interval: 1; running: true; onTriggered: content.armed = true }

                readonly property bool shown: content.armed && root.wantOpen

                // Fades on its own, independent of the drawer's slide.
                // States rather than a Behavior: with a Behavior, `armed` drives
                // both the target value and `Behavior.enabled`, and QML does not
                // guarantee the Behavior is enabled first — so the value snaps
                // and nothing animates.
                Rectangle {
                    id: backdrop
                    anchors.fill: parent
                    color: CP.alpha(CP.void_, MangaState.readerOpen ? 0.55 : 0.35)
                    opacity: 0
                    Behavior on color { CAnim {} }

                    states: State {
                        name: "in"
                        when: content.shown
                        PropertyChanges { backdrop.opacity: 1 }
                    }
                    transitions: [
                        Transition {
                            from: ""; to: "in"
                            NumberAnimation { target: backdrop; property: "opacity"
                                              duration: 220; easing.type: Easing.OutQuad }
                        },
                        Transition {
                            from: "in"; to: ""
                            NumberAnimation { target: backdrop; property: "opacity"
                                              duration: 260; easing.type: Easing.InQuad }
                        }
                    ]

                    MouseArea {
                        anchors.fill: parent
                        onClicked: MangaState.readerOpen ? MangaState.readerOpen = false
                                                        : MangaState.closeAll()
                    }
                }

                // -- Drawer, pinned left --------------------
                Item {
                    id: slider
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    width: 520
                    clip: true

                    Item {
                        id: drawer
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width
                        // Base value is the closed position, so the first frame
                        // puts the drawer off-screen without animating there.
                        x: -width

                        states: State {
                            name: "in"
                            when: content.shown
                            PropertyChanges { drawer.x: 0 }
                        }
                        transitions: [
                            Transition {
                                from: ""; to: "in"
                                NumberAnimation { target: drawer; property: "x"
                                                  duration: 320; easing.type: Easing.OutCubic }
                            },
                            Transition {
                                from: "in"; to: ""
                                NumberAnimation { target: drawer; property: "x"
                                                  duration: 300; easing.type: Easing.InCubic }
                            }
                        ]

                        CutShape {
                            anchors.fill: parent
                            fillColor: CP.alpha(CP.void2, 0.96)
                            strokeColor: CP.alpha(Colours.accentSecondary, 0.5)
                            strokeWidth: 1
                            inset: 0.5
                            cutTopRight: 24
                            showLeft: false
                        }

                        // Swallows clicks landing on empty drawer space:
                        // without this they fall through to the backdrop
                        // underneath and dismiss the panel.
                        MouseArea { anchors.fill: parent }

                        ScanlineOverlay { anchors.fill: parent; opacity: 0.05 }

                        Text {
                            id: header
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.margins: 14
                            text: "◢ MANGA"
                            font.family: "Oxanium"
                            font.pixelSize: 22
                            font.letterSpacing: 3
                            font.bold: true
                            color: Colours.accentSecondary
                        }

                        // Back to the front page from wherever you are: the
                        // library, a series sheet, or a search several pages
                        // deep. Clearing the query is part of it — landing on
                        // "browse" while the field still holds a search would
                        // show the search, not the home listing.
                        CutShape {
                            id: homeBtn
                            anchors.right: libBtn.left
                            anchors.rightMargin: 6
                            anchors.verticalCenter: header.verticalCenter
                            width: homeLabel.implicitWidth + 16
                            height: 20
                            fillColor: homeMa.containsMouse
                                        ? CP.alpha(Colours.accentSecondary, 0.85) : "transparent"
                            strokeColor: CP.alpha(Colours.accentSecondary, 0.4)
                            strokeWidth: 1
                            inset: 0.5
                            cutBottomRight: 6
                            Behavior on fillColor { CAnim {} }

                            Text {
                                id: homeLabel
                                anchors.centerIn: parent
                                text: "HOME"
                                font.family: "Oxanium"
                                font.pixelSize: 10
                                font.letterSpacing: 1.5
                                font.bold: true
                                color: homeMa.containsMouse
                                       ? CP.void_ : CP.alpha(Colours.accentSecondary, 0.8)
                            }

                            MouseArea {
                                id: homeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    MangaState.view = "browse"
                                    browseView.goHome()
                                }
                            }
                        }

                        // Switches between browsing and what you already follow.
                        // Detail is not a destination here: it is reached from
                        // either list, and going back returns to the one you
                        // came from.
                        CutShape {
                            id: libBtn
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: header.verticalCenter
                            readonly property bool on: MangaState.view === "library"
                            width: libBtnLabel.implicitWidth + 16
                            height: 20
                            fillColor: on ? CP.alpha(Colours.accentSecondary, 0.85) : "transparent"
                            strokeColor: CP.alpha(Colours.accentSecondary, on ? 1.0 : 0.4)
                            strokeWidth: 1
                            inset: 0.5
                            cutBottomRight: 6
                            Behavior on fillColor   { CAnim {} }
                            Behavior on strokeColor { CAnim {} }

                            Text {
                                id: libBtnLabel
                                anchors.centerIn: parent
                                text: libBtn.on ? "BROWSE" : "LIBRARY"
                                font.family: "Oxanium"
                                font.pixelSize: 10
                                font.letterSpacing: 1.5
                                font.bold: true
                                color: libBtn.on ? CP.void_
                                                 : CP.alpha(Colours.accentSecondary, 0.8)
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: MangaState.view =
                                    MangaState.view === "library" ? "browse" : "library"
                            }
                        }

                        LibraryView {
                            anchors.top: header.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 14
                            anchors.topMargin: 10
                            visible: MangaState.view === "library"

                            onSeriesOpened: manga => {
                                MangaState.openManga = manga
                                MangaState.view = "detail"
                                MangaService.fetchChapters(manga,
                                    MangaState.chapterLanguages(manga.originalLang),
                                    MangaState.contentRatings)
                                MangaService.fetchExtraInfo(manga)
                            }

                            // Resume needs the chapter list too: the reader shows
                            // pages, but the label and the progress writes both
                            // need the chapter record behind them.
                            onResumeRequested: (manga, chapterId, page) => {
                                MangaState.openManga = manga
                                MangaState.view = "detail"
                                MangaState.resumeChapterId = chapterId
                                MangaState.resumePage = page
                                MangaService.fetchChapters(manga,
                                    MangaState.chapterLanguages(manga.originalLang),
                                    MangaState.contentRatings)
                                MangaService.fetchExtraInfo(manga)
                            }
                        }

                        BrowseView {
                            id: browseView
                            anchors.top: header.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 14
                            anchors.topMargin: 10
                            visible: MangaState.view === "browse"
                            onSeriesActivated: manga => {
                                MangaState.openManga = manga
                                MangaState.view = "detail"
                                MangaService.fetchChapters(manga,
                                    MangaState.chapterLanguages(manga.originalLang),
                                    MangaState.contentRatings)
                                MangaService.fetchExtraInfo(manga)
                            }
                            onEscaped: content.forceActiveFocus()
                        }

                        // Both views stay instantiated and only toggle
                        // visibility: going back must not refetch the grid nor
                        // lose its scroll position. Costs ~17 MB of covers.
                        DetailView {
                            anchors.top: header.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 14
                            anchors.topMargin: 10
                            visible: MangaState.view === "detail"
                            manga: MangaState.openManga
                            onBackRequested: MangaState.view = "browse"
                            onChapterActivated: ch => {
                                MangaState.openChapter = ch
                                // Picked by hand, so start at the top: leaving
                                // the bookmark set would drop the reader in the
                                // middle of a chapter the user chose fresh.
                                MangaState.resumePage = 0
                                MangaService.fetchPages(ch, MangaState.dataSaver)
                                MangaState.readerOpen = true
                            }
                        }
                    }
                }

                // A resume can only act once the chapter list is in: the reader
                // needs the chapter record itself, not just the stored id, for
                // its label and for writing progress back.
                Connections {
                    target: MangaService
                    function onChaptersLoaded() {
                        if (MangaState.resumeChapterId === "") return
                        var want = MangaState.resumeChapterId
                        MangaState.resumeChapterId = ""
                        var list = MangaService.chapters
                        for (var i = 0; i < list.length; i++) {
                            if (list[i].id !== want) continue
                            MangaState.openChapter = list[i]
                            MangaService.fetchPages(list[i], MangaState.dataSaver)
                            MangaState.readerOpen = true
                            return
                        }
                        // The chapter is gone — removed upstream, or filtered
                        // out by the current language choice. The series page is
                        // already open, so leave the user there.
                        MangaState.resumePage = 0
                    }
                }

                // -- Reader, centred -----------------------
                // Reading in a 520px column pinned to one edge makes no sense,
                // so this is a separate surface, not drawer content.
                Loader {
                    anchors.centerIn: parent
                    width: Math.min(1000, parent.width - 160)
                    height: parent.height - 80
                    active: MangaState.readerOpen
                    visible: active

                    // ReaderView declares focus: true, but it lives inside a
                    // Loader whose parent is a plain Item, so focus never
                    // reaches it and its Keys handler is dead. Forcing it on
                    // load is what makes +, - and 0 arrive.
                    onLoaded: item.forceActiveFocus()

                    // Focus travels into the reader while it is up; when it
                    // goes away the panel must take it back, or Escape stops
                    // working entirely from then on.
                    onActiveChanged: if (!active) content.forceActiveFocus()

                    sourceComponent: ReaderView {
                        pages: MangaService.pages
                        dataSaver: MangaState.dataSaver
                        chapterKey: MangaState.openChapter ? MangaState.openChapter.id : ""
                        startPage: MangaState.resumePage

                        // Refetching gives a different at-home node, but it also
                        // reassigns MangaService.pages, which sends the list back
                        // to the top. The position is saved and restored on the
                        // next tick — verified working.
                        property real _keepY: 0
                        property double _lastRefresh: 0

                        onNeedsFreshNode: {
                            var now = Date.now()
                            if (now - _lastRefresh < 15000) return
                            _lastRefresh = now
                            _keepY = contentY
                            MangaService.fetchPages(MangaState.openChapter, MangaState.dataSaver)
                        }

                        Connections {
                            target: MangaService
                            function onPagesLoaded() {
                                if (_keepY <= 0) return
                                var y = _keepY
                                _keepY = 0
                                Qt.callLater(function() { contentY = y })
                            }
                        }

                        chapterLabel: MangaState.openChapter
                            ? "◢ CAP " + MangaState.openChapter.chapter
                            + "  " + MangaState.openChapter.lang.toUpperCase()
                            : ""
                        focus: true
                        onCloseRequested: MangaState.readerOpen = false
                        onPageReached: i => {
                            if (MangaState.openManga && MangaState.openChapter)
                                MangaState.updateProgress(MangaState.openManga.id,
                                    MangaState.openChapter.id,
                                    MangaState.openChapter.chapter, i)
                        }
                    }
                }

                Keys.onEscapePressed: event => {
                    if (MangaState.readerOpen)             MangaState.readerOpen = false
                    else if (MangaState.view === "detail") MangaState.view = "browse"
                    else                                    MangaState.closeAll()
                    event.accepted = true
                }
            }
        }
    }
}
