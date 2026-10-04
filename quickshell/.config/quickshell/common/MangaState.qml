// MangaState.qml — UI state and persisted library for the manga panel.
// Persistence follows TransitionConfig: FileView to read, a python3 Process to
// write (it creates the directory too). The file lives in ~/.config and not in
// ~/.cache because reading progress is not regenerable.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // -- Panel -----------------------------------------
    property bool   panelOpen:  false
    property bool   readerOpen: false
    // Which screen shows the overlay; MangaPanel is instantiated per screen
    // via Variants and only the matching one becomes visible
    property string activeScreen: ""
    property string view:       "browse"    // "browse" | "detail" | "library"

    property var    openManga:   null       // parsed series being inspected
    property var    openChapter: null       // chapter being read

    // Set when reopening from the library. The chapter id is consumed as soon
    // as the chapter list arrives; the page survives until the reader has
    // something to scroll, and is zeroed on any normal chapter open so a later
    // read does not inherit someone else's bookmark.
    property string resumeChapterId: ""
    property int    resumePage: 0

    function togglePanel(screenName) {
        if (root.panelOpen) {
            root.closeAll()
        } else {
            root.activeScreen = screenName
            root.panelOpen = true
        }
    }

    function closeAll()    { root.readerOpen = false; root.panelOpen = false }

    // -- Filters ----------------------------------------
    // Which catalogue the browse view queries. MangaDex has the metadata and
    // the multi-language chapter lists; MangaWorld has the Italian catalogue
    // that MangaDex simply does not carry.
    property string source: "all"           // "all" | "mangadex" | "mangaworld"

    // Off by default and never widened implicitly: with the toggle down those
    // ratings are not even sent, so no cover of that kind ever reaches Qt's
    // image cache. Only MangaDex has ratings to filter on.
    property bool nsfwEnabled: false

    readonly property var contentRatings: nsfwEnabled
        ? ["safe", "suggestive", "erotica", "pornographic"]
        : ["safe", "suggestive"]

    // Series search: a title qualifies if it has any of these
    readonly property var searchLanguages: ["it", "en"]

    // Chapter list: preference order, original language appended per series
    function chapterLanguages(originalLang) {
        var l = ["it", "en"]
        if (originalLang && l.indexOf(originalLang) < 0) l.push(originalLang)
        return l
    }

    // Sorting key for grouping a chapter list by language
    function langRank(lang, originalLang) {
        if (lang === "it") return 0
        if (lang === "en") return 1
        if (lang === originalLang) return 2
        return 3
    }

    property bool dataSaver: true

    // -- Library -------------------------------
    property string libraryPath: (Quickshell.env("HOME") || "") + "/.config/quickshell/manga-library.json"
    property var    library: []

    function libraryIndex(mangaId) {
        for (var i = 0; i < library.length; i++)
            if (library[i].id === mangaId) return i
        return -1
    }

    function inLibrary(mangaId) { return libraryIndex(mangaId) >= 0 }

    function libraryEntry(mangaId) {
        var i = libraryIndex(mangaId)
        return i >= 0 ? library[i] : null
    }

    function addToLibrary(manga) {
        if (!manga || inLibrary(manga.id)) return
        var l = library.slice()
        l.push({
            id:             manga.id,
            title:          manga.title,
            coverFile:      manga.coverFile || "",
            cover:          manga.cover || "",
            // One id per catalogue: a MangaWorld id is a page url and means
            // nothing to MangaDex, so a merged entry has to keep both or
            // reopening it would lose half its chapters.
            sources:        manga.sources || ({}),
            source:         root.source,
            originalLang:   manga.originalLang || "",
            lastChapterId:  "",
            lastChapterNum: "",
            lastPage:       0,
            updatedAt:      new Date().toISOString()
        })
        library = l
        save()
    }

    function removeFromLibrary(mangaId) {
        var i = libraryIndex(mangaId)
        if (i < 0) return
        var l = library.slice()
        l.splice(i, 1)
        library = l
        save()
    }

    // Reading progress is what separates a reader from an image viewer, so it
    // is written from day one rather than bolted on later.
    function updateProgress(mangaId, chapterId, chapterNum, page) {
        var i = libraryIndex(mangaId)
        if (i < 0) return
        var l = library.slice()
        var e = ({})
        for (var k in l[i]) e[k] = l[i][k]
        e.lastChapterId  = chapterId
        e.lastChapterNum = chapterNum
        e.lastPage       = page
        e.updatedAt      = new Date().toISOString()
        l[i] = e
        library = l
        save()
    }

    // -- Persistence ---------------------------------
    function save() {
        _saveProc.command = ["python3", "-c",
            "import sys, os, json; os.makedirs(os.path.dirname(sys.argv[1]), exist_ok=True); open(sys.argv[1], 'w').write(sys.argv[2])",
            root.libraryPath,
            JSON.stringify({ version: 1, nsfwEnabled: root.nsfwEnabled,
                            dataSaver: root.dataSaver, source: root.source,
                            entries: root.library }, null, 2)]
        _saveProc.running = false
        _saveProc.running = true
    }

    property var _saveProc: Process {
        command: ["true"]
        running: false
    }

    property var _loadFile: FileView {
        path: root.libraryPath
        onLoaded: {
            try {
                var d = JSON.parse(text())
                if (Array.isArray(d.entries))       root.library     = d.entries
                if (d.nsfwEnabled !== undefined)    root.nsfwEnabled = d.nsfwEnabled
                if (d.dataSaver !== undefined)      root.dataSaver   = d.dataSaver
                if (d.source)                       root.source      = d.source
            } catch (e) {
                console.warn("[manga] libreria illeggibile, riparto vuoto:", e)
            }
        }
        onLoadFailed: { /* prima esecuzione: nessun file, va bene cosi' */ }
    }

    // -- IPC: toggle file, same handshake as WallpaperState -------------
    property string _lastToggleContent: ""

    // The file survives a shell restart, so it is blanked at startup and its
    // content recorded as the baseline: without this a stale value from the
    // previous session would open the panel on its own.
    property var _toggleInit: Process {
        command: ["bash", "-c", "echo -n '' > /tmp/qs-manga-toggle"]
        running: true
        onRunningChanged: {
            if (!running) {
                _toggleReader.reload()
                root._lastToggleContent = _toggleReader.text()
            }
        }
    }

    property var _toggleReader: FileView {
        id: _toggleReader
        path: "/tmp/qs-manga-toggle"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            var content = text().trim()
            if (content !== "" && content !== root._lastToggleContent) {
                root._lastToggleContent = content
                root.togglePanel(content.split("_")[0])
            }
        }
    }
}
