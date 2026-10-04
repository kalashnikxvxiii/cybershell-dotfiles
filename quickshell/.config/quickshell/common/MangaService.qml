// MangaService.qml — MangaDex API client. Pure QML: Image and XMLHttpRequest
// both reach mangadex.org directly, so there is no local backend (see
// MANGA-DESIGN.md §2). Every list-producing call carries an incrementing
// request id: responses that land after the user moved on are discarded.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string api:      "https://api.mangadex.org"
    readonly property string coverBase: "https://uploads.mangadex.org/covers"
    readonly property string ua:       "quickshell-manga/0.1"

    // ── Series list ──────────────────────────────────────────────
    property var    results: []
    property int    total:   0
    property bool   loading: false
    property string error:   ""
    readonly property bool hasMore: results.length < total

    // ── Chapters of the open series ──────────────────────────────
    property var    chapters:        []
    property bool   loadingChapters: false
    property string chaptersError:   ""
    // Which series the list currently describes. The list is not emptied when a
    // fetch starts — that would make "empty" mean both "in flight" and "nothing
    // there" — so consumers compare this instead and show nothing while it
    // still names the previous series.
    property string chaptersFor:     ""

    // ── Pages of the open chapter ────────────────────────────────
    property var    pages:        []
    property bool   loadingPages: false
    property string pagesError:   ""

    // Explicit completion signals. Watching the list properties instead is
    // ambiguous: an empty list means both "request in flight" and "the answer
    // was empty", and callers cannot tell them apart.
    signal seriesLoaded()
    signal chaptersLoaded()
    signal pagesLoaded()
    signal failed(string what, string message)

    property int _reqId: 0

    // -- URL helpers ------------------------------------
    // Array params must be percent-encoded: a bare "[]" is dropped and the
    // filter silently does nothing.
    function _arr(key, values) {
        var out = ""
        for (var i = 0; i < values.length; i++)
            out += "&" + encodeURIComponent(key) + "%5B%5D=" + encodeURIComponent(values[i])
        return out
    }

    function _get(url, onOk, onFail) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== 4) return
            if (xhr.status !== 200) { onFail("HTTP " + xhr.status); return }
            try { onOk(JSON.parse(xhr.responseText)) }
            catch (e) { onFail("invalid response") }
        }
        xhr.open("GET", url)
        xhr.setRequestHeader("User-Agent", root.ua)
        xhr.send()
    }

    function _post(url, body, onOk, onFail) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== 4) return
            if (xhr.status !== 200) { onFail("HTTP " + xhr.status); return }
            try { onOk(JSON.parse(xhr.responseText)) }
            catch (e) { onFail("invalid response") }
        }
        xhr.open("POST", url)
        xhr.setRequestHeader("User-Agent", root.ua)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.send(JSON.stringify(body))
    }

    // Strips accents and punctuation so "Tāmen De Gùshì" and "Tamen De Gushi"
    // compare equal. Done by codepoint rather than a regex: NFKD splits the
    // accents into combining marks, and keeping only a-z0-9 drops them.
    function _normTitle(s) {
        if (!s) return ""
        var t = String(s)
        if (t.normalize) t = t.normalize("NFKD")
        t = t.toLowerCase()
        var out = ""
        for (var i = 0; i < t.length; i++) {
            var c = t.charCodeAt(i)
            if ((c >= 97 && c <= 122) || (c >= 48 && c <= 57)) out += t.charAt(i)
        }
        return out
    }

    function coverUrl(mangaId, fileName, thumb) {
        if (!mangaId || !fileName) return ""
        return root.coverBase + "/" + mangaId + "/" + fileName + (thumb ? ".256.jpg" : ".512.jpg")
    }

    // -- Parsing ---------------------------------------
    function _pickTitle(t, alts) {
        if (!t) return "—"
        if (t.it) return t.it
        if (t.en) return t.en
        if (alts) {
            for (var i = 0; i < alts.length; i++)
                if (alts[i] && alts[i].it) return alts[i].it
        }
        for (var k in t) return t[k]
        return "—"
    }

    function _parseManga(m) {
        var a = m.attributes || ({})
        var cover = ""
        var rels = m.relationships || []
        for (var i = 0; i < rels.length; i++) {
            if (rels[i].type === "cover_art" && rels[i].attributes)
                cover = rels[i].attributes.fileName
        }
        var warn = []
        var tags = a.tags || []
        for (var j = 0; j < tags.length; j++) {
            var ta = tags[j].attributes
            if (ta && ta.group === "content" && ta.name) warn.push(ta.name.en)
        }
        // Every spelling the series is known by. Needed to match it against
        // MangaUpdates, which often files a work under a different romanisation
        // or under its localised name.
        var alts = []
        for (var t in (a.title || {})) alts.push(a.title[t])
        var at = a.altTitles || []
        for (var q = 0; q < at.length; q++)
            for (var lk in at[q]) alts.push(at[q][lk])

        return {
            id:            m.id,
            title:         _pickTitle(a.title, a.altTitles),
            altTitles:     alts,
            description:   (a.description && (a.description.it || a.description.en)) || "",
            contentRating: a.contentRating || "safe",
            originalLang:  a.originalLanguage || "",
            status:        a.status || "",
            year:          a.year || 0,
            warnings:      warn,
            coverFile:     cover,
            // Ready to use, so the views do not have to know which catalogue
            // answered: MangaDex needs the url built from id + filename, while
            // MangaWorld hands one over directly.
            cover:         coverUrl(m.id, cover, true)
        }
    }

    // -- Sources ------------------------------------------
    // Which catalogue the next call talks to. The views set it; everything
    // downstream — chapter lists, page urls, the reader — works on the same
    // normalised shapes whichever answered.
    property string source: "all"     // "all" | "mangadex" | "mangaworld"
    property int _mwPage: 1
    // MangaDex paginates by offset, and that offset counts what MangaDex
    // returned — not the merged list, which is shorter once duplicates fold.
    property int _mdOffset: 0

    readonly property var allSources: ["mangadex", "mangaworld"]

    function _sourcesFor(s) {
        return s === "all" ? root.allSources : [s]
    }

    // Two catalogues carry many of the same works, so a merged grid would show
    // everything twice. Entries are folded together on a normalised title —
    // accents and punctuation stripped, same comparison the MangaUpdates
    // pairing uses — and the merged row remembers an id per catalogue so its
    // chapter lists can both be fetched later.
    readonly property string _mwScript:
        (Quickshell.env("HOME") || "") + "/.config/quickshell/scripts/manga-mangaworld.py"

    // One reusable process rather than one per call: it matches how the rest of
    // the service behaves and keeps the number of spawns bounded.
    property var _mwProc: Process {
        id: mwProc
        running: false
        property var handler: null
        stdout: StdioCollector {
            onStreamFinished: {
                var cb = mwProc.handler
                mwProc.handler = null
                if (!cb) return
                try { cb(JSON.parse(text)) }
                catch (e) { cb({ error: "invalid response" }) }
            }
        }
    }

    function _mw(cmd, arg, onDone, extra) {
        mwProc.handler = onDone
        mwProc.command = extra !== undefined
            ? ["python3", root._mwScript, cmd, arg, String(extra)]
            : ["python3", root._mwScript, cmd, arg]
        mwProc.running = false
        mwProc.running = true
    }

    // Japanese romanisation writes the same long vowel both ways — Toukyou and
    // Tokyo, Yuu and Yu — so the strict key never pairs them. Collapsing the
    // doubles catches that class. Measured on 80 real titles: no title that was
    // distinct before became ambiguous after.
    function _normLoose(s) {
        var t = _normTitle(s)
        var pairs = [["ou", "o"], ["uu", "u"], ["oo", "o"],
                     ["aa", "a"], ["ee", "e"], ["ii", "i"]]
        // split/join rather than a regex: QML's JS engine is unreliable with
        // regex literals, and this is the hot path of every merge.
        for (var i = 0; i < pairs.length; i++)
            t = t.split(pairs[i][0]).join(pairs[i][1])
        return t
    }

    // Every spelling a series answers to, strict and loose. MangaDex ships a
    // dozen alternative titles per work and MangaWorld files things under a
    // different romanisation, so matching on the main title alone missed most
    // of the overlap: measured 7 pairings out of 12, against 9 once the
    // aliases are in. Keys under four characters are dropped — they are the
    // ones that would collide by accident.
    function _titleKeys(m) {
        var all = [m.title]
        var alts = m.altTitles || []
        for (var i = 0; i < alts.length; i++) all.push(alts[i])
        var keys = []
        var seen = ({})
        for (var j = 0; j < all.length; j++) {
            var strict = _normTitle(all[j])
            var loose = _normLoose(all[j])
            if (strict.length >= 4 && !seen[strict]) { seen[strict] = true; keys.push(strict) }
            if (loose.length >= 4 && !seen[loose]) { seen[loose] = true; keys.push(loose) }
        }
        return keys
    }

    function _mergeInto(existing, src, items) {
        var out = existing.slice()
        var byKey = ({})
        for (var e = 0; e < out.length; e++) {
            var ek = _titleKeys(out[e])
            for (var x = 0; x < ek.length; x++)
                if (byKey[ek[x]] === undefined) byKey[ek[x]] = e
        }
        for (var i = 0; i < items.length; i++) {
            var m = items[i]
            var mk = _titleKeys(m)
            var hit = -1
            for (var y = 0; y < mk.length; y++)
                if (byKey[mk[y]] !== undefined) { hit = byKey[mk[y]]; break }

            if (hit < 0) {
                m.sources = ({})
                m.sources[src] = m.id
                var idx = out.length
                out.push(m)
                for (var z = 0; z < mk.length; z++)
                    if (byKey[mk[z]] === undefined) byKey[mk[z]] = idx
            } else {
                var prev = out[hit]
                if (!prev.sources) prev.sources = ({})
                prev.sources[src] = m.id
                // Keep whatever detail the other catalogue was missing, and pool
                // the aliases so later batches can match on either spelling.
                if (!prev.cover && m.cover) prev.cover = m.cover
                if (!prev.description && m.description) prev.description = m.description
                if (!prev.year && m.year) prev.year = m.year
                if (!prev.status && m.status) prev.status = m.status
                if (!prev.originalLang && m.originalLang) prev.originalLang = m.originalLang
                var pool = (prev.altTitles || []).slice()
                if (pool.indexOf(m.title) < 0) pool.push(m.title)
                var ma = m.altTitles || []
                for (var w = 0; w < ma.length; w++)
                    if (pool.indexOf(ma[w]) < 0) pool.push(ma[w])
                prev.altTitles = pool
                for (var q = 0; q < mk.length; q++)
                    if (byKey[mk[q]] === undefined) byKey[mk[q]] = hit
            }
        }
        return out
    }

    // -- MangaUpdates: extra metadata ---------------------
    // The two catalogues share no identifier, so a series can only be paired by
    // title. Measured over 20 real entries: 17 matched, 3 were rejected — and
    // all three rejections were genuinely different works. A wrong match is
    // worse than none, so anything the matcher is unsure about is dropped.
    readonly property string muApi: "https://api.mangaupdates.com/v1"
    property var  extraInfo: null
    property bool loadingExtra: false

    function fetchExtraInfo(manga) {
        root.extraInfo = null
        if (!manga || !manga.title) return
        root.loadingExtra = true

        var keys = ({})
        var alts = manga.altTitles || [manga.title]
        for (var i = 0; i < alts.length; i++) {
            var k = _normTitle(alts[i])
            if (k.length > 0) keys[k] = true
        }
        keys[_normTitle(manga.title)] = true

        _post(root.muApi + "/series/search", { search: manga.title, perpage: 5 },
            function (d) {
                var hits = d.results || []
                var found = null
                for (var h = 0; h < hits.length; h++) {
                    var rec = hits[h].record
                    if (keys[_normTitle(rec.title)]) { found = rec; break }
                }
                if (!found) { root.loadingExtra = false; return }
                // The search hit carries only part of the record: latest_chapter,
                // completed and the ranking live on the full series entry, so a
                // second call is needed once the pairing is settled.
                root._fetchExtraDetail(found)
            },
            function (e) { root.loadingExtra = false })
    }

    function _fetchExtraDetail(found) {
        _get(root.muApi + "/series/" + found.series_id, function (f) {
            // Payload before the flag, never the other way round: the flag is
            // what wakes the UI, so everything it then reads must already be in
            // place. Setting it first hands out a stale null.
            root.extraInfo = {
                title:    f.title || found.title || "",
                rating:   f.bayesian_rating || 0,
                votes:    f.rating_votes || 0,
                year:     f.year || "",
                type:     f.type || "",
                latest:   f.latest_chapter || 0,
                done:     f.completed === true,
                licensed: f.licensed === true,
                rank:     (f.rank && f.rank.position && f.rank.position.year) || 0,
                url:      f.url || ""
            }
            root.loadingExtra = false
        }, function (e) {
            // The pairing held but the detail call did not: keep what the
            // search already gave rather than showing nothing.
            root.extraInfo = {
                title:    found.title || "",
                rating:   found.bayesian_rating || 0,
                votes:    found.rating_votes || 0,
                year:     found.year || "",
                type:     found.type || "",
                latest:   0, done: false, licensed: false, rank: 0,
                url:      found.url || ""
            }
            root.loadingExtra = false
        })
    }

    // -- Genre tags ---------------------------------------
    // 77 tags in four groups (format 12, genre 25, theme 38, content 2).
    // Fetched once and kept: the list never changes during a session.
    property var genres: []
    property bool genresLoaded: false

    function fetchGenres() {
        if (root.genresLoaded || root.genres.length > 0) return
        _get(root.api + "/manga/tag", function (d) {
            var out = []
            for (var i = 0; i < d.data.length; i++) {
                var a = d.data[i].attributes
                if (!a || a.group !== "genre") continue
                out.push({ id: d.data[i].id, name: a.name.en || "?" })
            }
            out.sort(function (x, y) { return x.name < y.name ? -1 : 1 })
            root.genresLoaded = true
            root.genres = out
        }, function (e) { root.failed("genres", e) })
    }

    // -- Author lookup ------------------------------------
    // MangaDex has no free-text author filter on /manga: the name has to be
    // resolved to a uuid first, then passed as authors[].
    property var authorMatches: []

    property bool countingAuthors: false
    property var _authorScratch: []
    property var _authorDone: null

    property int _authorNext: 0
    property int _authorInflight: 0
    // Four at a time: MangaDex tolerates roughly five requests a second, and a
    // common surname like "Fujimoto" matches 22 records — sequentially that is
    // five seconds of waiting after pressing Enter.
    readonly property int _authorConcurrency: 4

    function searchAuthors(name, onDone) {
        if (!name || name.length === 0) { root.authorMatches = []; return }
        // 25, not 10: "Fujimoto" has 22 matches and the one that matters,
        // Fujimoto Tatsuki with 16 works, sits past the tenth. The endpoint
        // rejects order[relevance], so the whole set has to be pulled.
        _get(root.api + "/author?limit=25&name=" + encodeURIComponent(name), function (d) {
            var out = []
            for (var i = 0; i < d.data.length; i++)
                out.push({ id: d.data[i].id, name: d.data[i].attributes.name || "?", works: 0 })
            root._authorScratch = out
            root._authorDone = onDone || null
            root.authorMatches = []
            root.countingAuthors = true
            root._authorNext = 0
            root._authorInflight = 0
            root._pumpAuthors()
        }, function (e) { root.authorMatches = []; if (onDone) onDone([]) })
    }

    // A partial name matches many records, most of them stubs with no works at
    // all — picking one blind lands on an empty result with no explanation.
    // Counting first lets the empty ones be dropped and the real author float
    // to the front.
    function _pumpAuthors() {
        var list = root._authorScratch
        while (root._authorInflight < root._authorConcurrency
               && root._authorNext < list.length) {
            var i = root._authorNext
            root._authorNext = i + 1
            root._authorInflight = root._authorInflight + 1
            root._countOne(i)
        }
        if (root._authorInflight === 0 && root._authorNext >= list.length)
            root._finishAuthors()
    }

    function _countOne(i) {
        var a = root._authorScratch[i]
        _get(root.api + "/manga?limit=1" + _arr("authors", [a.id])
             + _arr("contentRating", ["safe", "suggestive", "erotica", "pornographic"]),
            function (d) {
                var l = root._authorScratch.slice()
                l[i] = { id: a.id, name: a.name, works: d.total || 0 }
                root._authorScratch = l
                root._authorInflight = root._authorInflight - 1
                root._pumpAuthors()
            },
            function (e) {
                root._authorInflight = root._authorInflight - 1
                root._pumpAuthors()
            })
    }

    function _finishAuthors() {
        var list = root._authorScratch
        var keep = []
        for (var k = 0; k < list.length; k++)
            if (list[k].works > 0) keep.push(list[k])
        keep.sort(function (a, b) { return b.works - a.works })
        root.countingAuthors = false
        root.authorMatches = keep
        if (root._authorDone) { root._authorDone(keep); root._authorDone = null }
    }

    // -- Browse / search ---------------------------------
    // `opts` is optional: { tags: [uuid…], authorId: uuid }
    // Per-source fetchers. Each hands its batch to `done` and never touches
    // the shared state, so the dispatcher below can run one or both and merge
    // whatever comes back.
    function _seriesMW(query, reset, rid, done) {
        // An empty box browses the archive, paginated 16 at a time. A keyword
        // search is not paginated — asking for page 2 of one comes back empty —
        // so only browsing advances the page.
        var browsing = !query || query.length === 0
        if (reset) root._mwPage = 1
        else if (browsing) root._mwPage = root._mwPage + 1

        _mw("search", query, function (d) {
            if (rid !== root._reqId) return
            var res = (d && d.results) || []
            var out = []
            for (var i = 0; i < res.length; i++) {
                out.push({
                    id:            res[i].url,      // the page url is the key here
                    title:         res[i].title,
                    altTitles:     [res[i].title],
                    description:   "",
                    contentRating: "safe",
                    originalLang:  "",
                    status:        "",
                    year:          0,
                    warnings:      [],
                    coverFile:     "",
                    cover:         res[i].cover
                })
            }
            // The archive reports no total, so a full page is read as "there is
            // more" and a short one as the end.
            done(out, browsing && res.length >= 16, d && d.error)
        }, root._mwPage)
    }

    function _seriesMD(query, langs, ratings, o, offset, rid, done) {
        var url = root.api + "/manga?limit=24&offset=" + offset
                + _arr("availableTranslatedLanguage", langs)
                + _arr("contentRating", ratings)
                + _arr("includes", ["cover_art"])

        if (o.tags && o.tags.length > 0) url += _arr("includedTags", o.tags)
        if (o.authorId) url += _arr("authors", [o.authorId])

        // latestUploadedChapter, not followedCount: the most-followed titles are
        // overwhelmingly delisted for licensing, so that ordering fills the grid
        // with series whose chapters cannot be opened.
        url += query && query.length > 0
            ? "&title=" + encodeURIComponent(query)
            : "&order%5BlatestUploadedChapter%5D=desc"

        _get(url, function (d) {
            if (rid !== root._reqId) return
            var out = []
            for (var i = 0; i < d.data.length; i++) out.push(_parseManga(d.data[i]))
            done(out, offset + out.length < (d.total || 0), null)
        }, function (e) { done([], false, e) })
    }

    function fetchSeries(query, langs, ratings, reset, opts) {
        if (reset) { root.results = []; root.total = 0 }
        var rid = ++root._reqId
        root.loading = true
        root.error = ""
        var o = opts || ({})

        var srcs = _sourcesFor(root.source)
        if (reset) root._mdOffset = 0
        var pending = srcs.length
        var merged = reset ? [] : root.results.slice()
        var anyMore = false
        var lastErr = ""

        // Each source folds into the same list as it lands, so a slow catalogue
        // never blocks the other from being merged — only the final commit
        // waits for both.
        function collect(src, items, more, err) {
            if (err) lastErr = err
            if (more) anyMore = true
            merged = _mergeInto(merged, src, items)
            if (--pending > 0) return
            if (rid !== root._reqId) return
            if (merged.length === 0 && lastErr) {
                root.error = lastErr
                root.loading = false
                root.failed("series", lastErr)
                return
            }
            // hasMore compares results against total; with no real count to
            // report, total is nudged one past the list while more remains.
            root.total = anyMore ? merged.length + 1 : merged.length
            root.loading = false
            root.results = merged
            root.seriesLoaded()
        }

        for (var s = 0; s < srcs.length; s++) {
            if (srcs[s] === "mangaworld")
                _seriesMW(query, reset, rid, function (i, m, e) { collect("mangaworld", i, m, e) })
            else
                // Offset counts only what MangaDex itself returned, which the
                // merged list no longer reflects once duplicates are folded.
                _seriesMD(query, langs, ratings, o, reset ? 0 : root._mdOffset, rid,
                          function (i, m, e) { root._mdOffset += i.length; collect("mangadex", i, m, e) })
        }
    }

    // -- Single series ------------------------------------
    // A library entry only stores what the list needs to draw a row. Reopening
    // a series wants the whole record — description, rating, warnings — so it
    // is pulled fresh instead of being half-reconstructed from disk.
    function fetchManga(mangaId, onDone) {
        _get(root.api + "/manga/" + mangaId + "?includes%5B%5D=cover_art",
            function (d) { if (onDone) onDone(_parseManga(d.data)) },
            function (e) { root.failed("manga", e); if (onDone) onDone(null) })
    }

    // -- Chapters --------------------------------
    // Per-source chapter fetchers, same shape as the series ones: hand the
    // batch to `done` and leave the shared state to the dispatcher.
    function _chaptersMW(seriesUrl, rid, done) {
        _mw("chapters", seriesUrl, function (d) {
            if (rid !== root._reqId) return
            var src = (d && d.chapters) || []
            var out = []
            for (var i = 0; i < src.length; i++) {
                out.push({
                    id:       src[i].url,   // the reader needs the url, not the hash
                    source:   "mangaworld",
                    chapter:  src[i].number || "?",
                    volume:   "",
                    title:    "",
                    // Everything on this site is Italian, so there is no
                    // language to filter on and nothing to group by.
                    lang:     "it",
                    pages:    0,            // unknown until the chapter is opened
                    external: "",
                    group:    "MangaWorld"
                })
            }
            done(out, d && d.error)
        })
    }

    function _chaptersMD(mangaId, langs, ratings, rid, done) {
        var url = root.api + "/manga/" + mangaId + "/feed?limit=500"
                + _arr("translatedLanguage", langs)
                + _arr("contentRating", ratings)
                + _arr("includes", ["scanlation_group"])
                + "&order%5Bchapter%5D=asc"

        _get(url, function (d) {
            if (rid !== root._reqId) return
            var out = []
            for (var i = 0; i < d.data.length; i++) {
                var a = d.data[i].attributes || ({})
                if (a.isUnavailable) continue
                // pages === 0 means MangaDex does not host the pages: the
                // chapter only exists at the publisher and can only be opened
                // in a browser. The reader is meant to be a place you stay in,
                // so those rows are dropped rather than listed as dead ends.
                if (!a.pages || a.pages < 1) continue
                // The same number often appears several times from different
                // scanlation groups; the group name is the only thing that
                // tells those rows apart.
                var grp = ""
                var rels = d.data[i].relationships || []
                for (var r = 0; r < rels.length; r++) {
                    if (rels[r].type === "scanlation_group" && rels[r].attributes)
                        grp = rels[r].attributes.name || ""
                }
                out.push({
                    id:       d.data[i].id,
                    source:   "mangadex",
                    chapter:  a.chapter || "?",
                    volume:   a.volume || "",
                    title:    a.title || "",
                    lang:     a.translatedLanguage || "",
                    pages:    a.pages || 0,
                    external: a.externalUrl || "",
                    group:    grp
                })
            }
            done(out, null)
        }, function (e) { done([], e) })
    }

    // Takes the series object rather than an id: a merged row carries one id
    // per catalogue, and both chapter lists are wanted at once.
    function fetchChapters(manga, langs, ratings) {
        var rid = ++root._reqId
        root.loadingChapters = true
        root.chaptersError = ""
        // Held aside, not published yet: naming the new series here would let
        // the view's guard pass while `chapters` still holds the previous one.
        // It is assigned together with the data, below.
        var forId = (manga && manga.id) ? manga.id : String(manga)

        var srcs = (manga && manga.sources) ? manga.sources
                 : ({ mangadex: (manga && manga.id) || manga })
        var names = []
        for (var k in srcs) if (srcs[k]) names.push(k)
        if (names.length === 0) {
            root.loadingChapters = false
            root.chaptersFor = forId
            root.chapters = []
            root.chaptersLoaded()
            return
        }

        var pending = names.length
        var merged = []
        var lastErr = ""

        function collect(items, err) {
            if (err) lastErr = err
            for (var i = 0; i < items.length; i++) merged.push(items[i])
            if (--pending > 0) return
            if (rid !== root._reqId) return
            if (merged.length === 0 && lastErr) {
                root.chaptersError = lastErr
                root.loadingChapters = false
                root.chaptersFor = forId
                root.chapters = []
                root.failed("chapters", lastErr)
                return
            }
            root.loadingChapters = false
            root.chaptersFor = forId
            root.chapters = merged
            root.chaptersLoaded()
        }

        for (var n = 0; n < names.length; n++) {
            if (names[n] === "mangaworld") _chaptersMW(srcs.mangaworld, rid, collect)
            else                            _chaptersMD(srcs.mangadex, langs, ratings, rid, collect)
        }
    }

    // ── Pages ────────────────────────────────────────────────────
    // baseUrl is ephemeral: it must be requested per chapter, never cached.
    //
    // The images are NOT loaded by Qt. A MangaDex at-home node answers 404 to
    // practically every request after the first one on a Qt connection, while
    // curl gets 200 on the identical URLs at the same instant: measured, 1 page
    // of 15 through Qt against 45 of 45 through curl, and replicating Qt's exact
    // headers in curl still returned 200. Qt offers no way to change its
    // connection handling from QML, so a helper script downloads the chapter
    // into a cache and the reader is handed local files.
    property bool downloadingPages: false

    readonly property string _cacheRoot:
        (Quickshell.env("HOME") || "") + "/.cache/quickshell/manga/pages/"
    readonly property string _fetchScript:
        (Quickshell.env("HOME") || "") + "/.config/quickshell/scripts/manga-fetch-chapter.sh"

    property var _pagesProc: Process {
        id: pagesProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                var lines = text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var l = lines[i].trim()
                    if (l.length > 0) out.push("file://" + l)
                }
                root.downloadingPages = false
                root.loadingPages = false
                if (out.length === 0) {
                    root.pagesError = "download failed"
                    root.failed("pages", root.pagesError)
                    return
                }
                root.pages = out
                root.pagesLoaded()
            }
        }
    }

    // Takes the chapter object: in a merged list each row comes from its own
    // catalogue, so the route cannot be read off the globally selected source.
    function fetchPages(chapter, dataSaver) {
        var rid = ++root._reqId
        root.loadingPages = true
        root.pagesError = ""

        var chapterId = (chapter && chapter.id !== undefined) ? chapter.id : chapter
        var from = (chapter && chapter.source) ? chapter.source : root.source

        if (from === "mangaworld") {
            // chapterId is the reading url. The page urls it returns go through
            // exactly the same downloader as MangaDex's: the disk cache and the
            // workaround for Qt's networking are source-agnostic.
            _mw("pages", chapterId, function (d) {
                if (rid !== root._reqId) return
                var urls = (d && d.pages) || []
                if (d.error || urls.length === 0) {
                    root.pagesError = d.error || "no pages"
                    root.loadingPages = false
                    root.failed("pages", root.pagesError)
                    return
                }
                // Cache directory name from the url, built by codepoint rather
                // than a regex literal: QML's JS engine is unreliable with those.
                var raw = String(chapterId)
                var key = ""
                for (var c = 0; c < raw.length; c++) {
                    var code = raw.charCodeAt(c)
                    if ((code >= 48 && code <= 57) || (code >= 97 && code <= 122)
                        || (code >= 65 && code <= 90)) key += raw.charAt(c)
                }
                key = key.substring(Math.max(0, key.length - 32))
                var cmd = [root._fetchScript, root._cacheRoot + "mw-" + key]
                for (var i = 0; i < urls.length; i++) cmd.push(urls[i])
                root.downloadingPages = true
                pagesProc.command = cmd
                pagesProc.running = false
                pagesProc.running = true
            })
            return
        }

        _get(root.api + "/at-home/server/" + chapterId, function (d) {
            if (rid !== root._reqId) return
            var ch = d.chapter || ({})
            var files = dataSaver ? (ch.dataSaver || []) : (ch.data || [])
            var seg = dataSaver ? "/data-saver/" : "/data/"
            if (!ch.hash || files.length === 0) {
                root.loadingPages = false
                root.pagesError = "no pages"
                root.failed("pages", root.pagesError)
                return
            }

            // Keyed by hash and quality: the two variants are different images
            // and must not share a directory.
            var cmd = [root._fetchScript,
                       root._cacheRoot + ch.hash + (dataSaver ? "-ds" : "-full")]
            for (var i = 0; i < files.length; i++)
                cmd.push(d.baseUrl + seg + ch.hash + "/" + files[i])

            root.downloadingPages = true
            pagesProc.command = cmd
            pagesProc.running = false
            pagesProc.running = true
        }, function (e) {
            if (rid !== root._reqId) return
            root.pagesError = e
            root.loadingPages = false
            root.failed("pages", e)
        })
    }
}
