// LibraryView.qml — what you are following, with where you left off.
// MangaState has been storing progress since the reader existed; this is the
// view that finally shows it. A library row keeps only what a row needs to
// draw, so opening a series pulls the full record fresh from the service.
import "../../common/Colors.js" as CP
import "../../common"
import QtQuick

Item {
    id: root

    signal seriesOpened(var manga)
    signal resumeRequested(var manga, string chapterId, int page)

    property bool busy: false

    Text {
        id: head
        anchors.top: parent.top
        anchors.left: parent.left
        text: root.busy ? "◢ OPENING…"
            : MangaState.library.length === 0 ? "◢ LIBRARY EMPTY"
            : "◢ " + MangaState.library.length + " IN LIBRARY"
        font.family: "Oxanium"
        font.pixelSize: 11
        font.letterSpacing: 2
        font.bold: true
        color: CP.alpha(Colours.accentSecondary, 0.8)
    }

    Text {
        anchors.top: head.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.right: parent.right
        visible: MangaState.library.length === 0
        text: "Add a series from its page with ADD.\n"
            + "Reading progress is saved on its own, chapter and page."
        font.family: "Oxanium"
        font.pixelSize: 11
        color: CP.alpha(Colours.textMuted, 0.8)
        wrapMode: Text.WordWrap
    }

    ListView {
        id: list
        anchors.top: head.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        model: MangaState.library
        boundsBehavior: Flickable.StopAtBounds
        spacing: 4
        cacheBuffer: 200

        delegate: Item {
            id: row
            required property var modelData
            width: list.width
            height: 68

            readonly property bool started: modelData.lastChapterId !== ""

            Rectangle {
                anchors.fill: parent
                anchors.rightMargin: 2
                color: rowMa.containsMouse ? CP.alpha(Colours.accentSecondary, 0.1) : "transparent"
            }

            // Declared first so it sits underneath: the row handler covers the
            // whole delegate, and last it would swallow the clicks meant for
            // the RESUME and remove buttons drawn on top of it.
            MouseArea {
                id: rowMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root._open(row.modelData, false)
            }

            Image {
                id: cover
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 64
                // Entries written before sources existed only kept the
                // MangaDex filename, so the url is rebuilt for those.
                source: row.modelData.cover
                        || MangaService.coverUrl(row.modelData.id, row.modelData.coverFile, true)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 256
            }

            Text {
                id: rowTitle
                anchors.left: cover.right
                anchors.leftMargin: 10
                anchors.right: removeBtn.left
                anchors.rightMargin: 8
                anchors.top: parent.top
                anchors.topMargin: 6
                text: row.modelData.title
                font.family: "Oxanium"
                font.pixelSize: 12
                font.letterSpacing: 0.5
                font.bold: true
                color: rowMa.containsMouse ? Colours.accentSecondary : Colours.textPrimary
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.WordWrap
            }

            Text {
                id: progress
                anchors.left: rowTitle.left
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                text: row.started
                      ? "CH " + row.modelData.lastChapterNum
                        + "   ·   PAGE " + (row.modelData.lastPage + 1)
                      : "NOT STARTED"
                font.family: "Oxanium"
                font.pixelSize: 10
                font.letterSpacing: 1
                color: row.started ? CP.alpha(Colours.accentPrimary, 0.8)
                                   : CP.alpha(Colours.textMuted, 0.6)
            }

            // Only offered once there is something to resume: a button that
            // does nothing is worse than no button.
            CutShape {
                id: resumeBtn
                visible: row.started
                anchors.left: progress.right
                anchors.leftMargin: 10
                anchors.verticalCenter: progress.verticalCenter
                width: resumeLabel.implicitWidth + 14
                height: 16
                fillColor: resumeMa.containsMouse
                           ? CP.alpha(Colours.accentPrimary, 0.85) : "transparent"
                strokeColor: CP.alpha(Colours.accentPrimary, 0.5)
                strokeWidth: 1
                inset: 0.5
                cutBottomRight: 5
                Behavior on fillColor { CAnim {} }

                Text {
                    id: resumeLabel
                    anchors.centerIn: parent
                    text: "RESUME"
                    font.family: "Oxanium"
                    font.pixelSize: 9
                    font.letterSpacing: 1.5
                    font.bold: true
                    color: resumeMa.containsMouse ? CP.void_
                                                  : CP.alpha(Colours.accentPrimary, 0.85)
                }

                MouseArea {
                    id: resumeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root._open(row.modelData, true)
                }
            }

            CutShape {
                id: removeBtn
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.top: parent.top
                anchors.topMargin: 6
                width: 18
                height: 18
                fillColor: removeMa.containsMouse ? CP.red : "transparent"
                strokeColor: CP.alpha(CP.red, removeMa.containsMouse ? 1.0 : 0.4)
                strokeWidth: 1
                inset: 0.5
                cutBottomLeft: 6
                Behavior on fillColor { CAnim {} }

                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(0xF0156)   // nf-md-close
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: removeMa.containsMouse ? "white" : CP.alpha(CP.red, 0.8)
                }

                MouseArea {
                    id: removeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: MangaState.removeFromLibrary(row.modelData.id)
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: CP.alpha(Colours.accentSecondary, 0.12)
            }

        }
    }

    function _open(entry, resume) {
        // A MangaWorld-only entry has a page url for an id, which the MangaDex
        // endpoint cannot resolve. There is nothing richer to fetch for it, so
        // the row itself becomes the series object.
        if (entry.sources && !entry.sources.mangadex) {
            var local = {
                id: entry.id, title: entry.title, altTitles: [entry.title],
                description: "", contentRating: "safe", originalLang: entry.originalLang || "",
                status: "", year: 0, warnings: [], coverFile: entry.coverFile || "",
                cover: entry.cover || "", sources: entry.sources
            }
            MangaState.source = "all"
            MangaService.source = "all"
            if (resume && entry.lastChapterId !== "")
                root.resumeRequested(local, entry.lastChapterId, entry.lastPage)
            else
                root.seriesOpened(local)
            return
        }
        root.busy = true
        // Entries written before sources existed are MangaDex ones.
        MangaState.source = entry.source || "mangadex"
        MangaService.source = MangaState.source
        // A merged row keeps the id of whichever catalogue answered first, which
        // can be a MangaWorld url: MangaDex is asked for its own id instead.
        var mdId = (entry.sources && entry.sources.mangadex) || entry.id
        MangaService.fetchManga(mdId, function (m) {
            root.busy = false
            if (!m) return
            // fetchManga only knows MangaDex, so the ids the entry recorded are
            // put back: without them a merged series would reopen with half its
            // chapters missing. The library key goes back too, or the progress
            // writes would look for an entry that is not there.
            if (entry.sources) m.sources = entry.sources
            m.id = entry.id
            if (resume && entry.lastChapterId !== "")
                root.resumeRequested(m, entry.lastChapterId, entry.lastPage)
            else
                root.seriesOpened(m)
        })
    }
}
