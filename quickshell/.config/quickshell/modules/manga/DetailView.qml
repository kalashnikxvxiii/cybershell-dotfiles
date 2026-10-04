// DetailView.qml — series sheet and chapter list.
// Chapters are grouped by language rather than mixed: a series with 39 IT and
// 99 EN chapters must show plainly where Italian stops. An empty list is a
// normal outcome, not an error — MangaDex's search index and its chapter feed
// disagree, so a series can match a language filter and have nothing in it.
import "../../common/Colors.js" as CP
import "../../common"
import QtQuick

Item {
    id: root

    property var manga: null
    signal backRequested()
    signal chapterActivated(var chapter)

    readonly property string originalLang: manga ? (manga.originalLang || "") : ""

    // The service keeps the previous series' chapters until the new ones land,
    // so opening a second manga would flash the first one's list. Reading
    // through this guard makes the view empty until the data is actually its
    // own, without the service having to blank the list and lose the
    // distinction between "loading" and "nothing there".
    readonly property var ownChapters:
        (root.manga && MangaService.chaptersFor === root.manga.id)
        ? MangaService.chapters : []

    // Every language the merged chapter list carries, in preference order.
    readonly property var availableLangs: {
        var seen = ({})
        var out = []
        var src = root.ownChapters
        for (var i = 0; i < src.length; i++) {
            var l = src[i].lang || "?"
            if (seen[l]) continue
            seen[l] = true
            out.push(l)
        }
        var orig = root.originalLang
        out.sort(function (a, b) {
            return MangaState.langRank(a, orig) - MangaState.langRank(b, orig)
        })
        return out
    }

    // Italian wins whenever it is on offer; otherwise the best-ranked language
    // present. Recomputed when the list changes, since a different series may
    // not carry the language the last one did.
    property string selectedLang: ""
    onAvailableLangsChanged: {
        if (root.availableLangs.indexOf(root.selectedLang) >= 0) return
        root.selectedLang = root.availableLangs.indexOf("it") >= 0
                            ? "it" : (root.availableLangs[0] || "")
    }

    // Which grouped row is open. One at a time: several expanded blocks at
    // once turn the list into a wall again, which is the thing being fixed.
    property string expandedNumber: ""
    onSelectedLangChanged: root.expandedNumber = ""

    // MangaWorld writes chapter numbers zero-padded ("01") and MangaDex plain
    // ("1"), so grouping on the raw string kept the two catalogues apart on
    // every single chapter. Comparing them as numbers is what actually merges
    // a chapter that exists on both.
    function _chapKey(n) {
        var f = parseFloat(String(n).replace(",", "."))
        return isNaN(f) ? String(n) : String(f)
    }

    // Same number from several scanlation groups — or from both catalogues —
    // collapses into one row. The variants live inside it and only appear when
    // asked for.
    readonly property var groupedChapters: {
        var src = root.sortedChapters
        var out = []
        var byNum = ({})
        for (var i = 0; i < src.length; i++) {
            var k = root._chapKey(src[i].chapter)
            if (byNum[k] === undefined) {
                byNum[k] = out.length
                // The canonical number is shown, not whichever spelling arrived
                // first: "01" and "1" would otherwise label the row at random.
                out.push({ number: k, items: [src[i]] })
            } else {
                out[byNum[k]].items.push(src[i])
            }
        }
        return out
    }

    // One language at a time now, so the list only needs ordering by number.
    readonly property var sortedChapters: {
        var src = root.ownChapters
        var out = []
        for (var i = 0; i < src.length; i++)
            if (src[i].lang === root.selectedLang) out.push(src[i])
        out.sort(function (a, b) {
            var na = parseFloat(a.chapter), nb = parseFloat(b.chapter)
            if (isNaN(na)) na = 0
            if (isNaN(nb)) nb = 0
            return na - nb
        })
        return out
    }

    // -- Header: back + title + library toggle -------------------------
    Item {
        id: head
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 34

        Text {
            id: backBtn
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: String.fromCodePoint(0xF004D)   // nf-md-arrow_left
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            color: backMa.containsMouse ? Colours.accentSecondary
                                        : CP.alpha(Colours.accentSecondary, 0.6)
            Behavior on color { CAnim {} }
            MouseArea {
                id: backMa
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.backRequested()
            }
        }

        Text {
            anchors.left: backBtn.right
            anchors.leftMargin: 10
            anchors.right: libBtn.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: root.manga ? root.manga.title : ""
            font.family: "Oxanium"
            font.pixelSize: 16
            font.letterSpacing: 1
            font.bold: true
            color: Colours.textPrimary
            elide: Text.ElideRight
        }

        CutShape {
            id: libBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: libLabel.implicitWidth + 16
            height: 18
            readonly property bool saved: root.manga && MangaState.inLibrary(root.manga.id)
            fillColor: saved ? CP.alpha(Colours.accentSecondary, 0.85) : "transparent"
            strokeColor: CP.alpha(Colours.accentSecondary, saved ? 1.0 : 0.4)
            strokeWidth: 1
            inset: 0.5
            cutBottomRight: 6
            Behavior on fillColor { CAnim {} }

            Text {
                id: libLabel
                anchors.centerIn: parent
                text: libBtn.saved ? "IN LIBRARY" : "ADD"
                font.family: "Oxanium"
                font.pixelSize: 10
                font.letterSpacing: 1.5
                font.bold: true
                color: libBtn.saved ? CP.void_ : CP.alpha(Colours.accentSecondary, 0.8)
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!root.manga) return
                    if (libBtn.saved) MangaState.removeFromLibrary(root.manga.id)
                    else MangaState.addToLibrary(root.manga)
                }
            }
        }
    }

    // -- Cover + metadata -----------------------------
    Item {
        id: info
        anchors.top: head.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        height: 120

        Image {
            id: cover
            anchors.top: parent.top
            anchors.left: parent.left
            width: 84
            height: 120
            source: root.manga ? (root.manga.cover || "") : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 256
        }

        Column {
            id: meta
            anchors.top: parent.top
            anchors.left: cover.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            spacing: 3

            Text {
                text: {
                    if (!root.manga) return ""
                    var p = []
                    if (root.manga.year) p.push(root.manga.year)
                    if (root.manga.status) p.push(root.manga.status.toUpperCase())
                    if (root.manga.originalLang) p.push(root.manga.originalLang.toUpperCase())
                    p.push(root.manga.contentRating.toUpperCase())
                    return p.join("  ·  ")
                }
                font.family: "Oxanium"
                font.pixelSize: 11
                font.letterSpacing: 1.5
                font.bold: true
                color: CP.alpha(Colours.accentSecondary, 0.75)
            }

            // MangaUpdates. Paired by title, since the two catalogues share no
            // identifier — anything the matcher is unsure about is dropped
            // rather than shown, so a blank line here means "no confident
            // match", not "no data".
            Text {
                visible: MangaService.loadingExtra || MangaService.extraInfo !== null
                text: {
                    if (MangaService.loadingExtra) return "MANGAUPDATES…"
                    var e = MangaService.extraInfo
                    if (!e) return ""
                    var p = []
                    if (e.rating > 0) p.push("★ " + e.rating.toFixed(2)
                                             + " (" + e.votes + ")")
                    if (e.rank > 0)   p.push("#" + e.rank)
                    if (e.latest > 0) p.push(e.latest + " CH")
                    p.push(e.done ? "COMPLETE" : "ONGOING")
                    if (e.type) p.push(e.type.toUpperCase())
                    return p.join("   ·   ")
                }
                font.family: "Oxanium"
                font.pixelSize: 11
                font.letterSpacing: 1.5
                font.bold: true
                color: CP.alpha(Colours.accentPrimary, 0.8)
            }

            // Content tags are an axis of their own: a title can be rated safe
            // and still carry Gore, so these show regardless of the NSFW toggle.
            Text {
                width: parent.width
                visible: root.manga && root.manga.warnings.length > 0
                text: root.manga ? "⚠ " + root.manga.warnings.join(" · ").toUpperCase() : ""
                font.family: "Oxanium"
                font.pixelSize: 11
                font.letterSpacing: 1
                font.bold: true
                color: CP.alpha(CP.red, 0.9)
                wrapMode: Text.WordWrap
            }

        }

        // The synopsis is the one field with no length bound, so it gets a
        // viewport instead of an elide. It sits outside the metadata column and
        // takes the height the column left over, which keeps the block exactly
        // as tall as the cover: growing with the text would have pushed it over
        // the chapter header below.
        Item {
            id: descBox
            anchors.top: meta.bottom
            anchors.topMargin: 3
            anchors.left: meta.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true

            readonly property real range: Math.max(0, descFlick.contentHeight
                                                      - descFlick.height)

            Flickable {
                id: descFlick
                anchors.fill: parent
                contentWidth: width
                contentHeight: descText.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                // Leaves the wheel alone when the whole synopsis already fits.
                interactive: descBox.range > 0

                Text {
                    id: descText
                    // Short of the full width by the track's gutter, so a line
                    // never runs under the scroll indicator.
                    width: descFlick.width - 6
                    text: root.manga ? root.manga.description : ""
                    font.family: "Oxanium"
                    font.pixelSize: 14
                    color: CP.alpha(Colours.textMuted, 0.9)
                    wrapMode: Text.WordWrap
                }
            }

            // A different series starts from the top: the viewport would
            // otherwise open at the previous synopsis' scroll position.
            Connections {
                target: root
                function onMangaChanged() { descFlick.contentY = 0 }
            }

            // Same idiom as the workspace preview: each edge fades only while
            // there is text past it, so the cut always reads as "more below"
            // rather than as the end of the description.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 14
                opacity: descFlick.contentY > 0.5 ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
                gradient: Gradient {
                    GradientStop { position: 0.0; color: CP.alpha(CP.void2, 0.96) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 14
                opacity: descFlick.contentY < descBox.range - 0.5 ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: CP.alpha(CP.void2, 0.96) }
                }
            }

            Rectangle {
                id: descTrack
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 2
                visible: descBox.range > 0
                color: CP.alpha(CP.void_, 0.5)

                Rectangle {
                    width: parent.width
                    height: Math.max(12, descTrack.height * descFlick.height
                                         / Math.max(1, descFlick.contentHeight))
                    y: descBox.range > 0
                       ? (descFlick.contentY / descBox.range)
                         * (descTrack.height - height)
                       : 0
                    color: CP.alpha(Colours.accentSecondary, 0.7)
                }
            }
        }
    }

    // -- Chapter list --------------------------
    Text {
        id: chapHead
        anchors.top: info.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        text: MangaService.loadingChapters ? "◢ CHAPTERS…"
                                            : "◢ " + root.sortedChapters.length + " CHAPTERS"
        font.family: "Oxanium"
        font.pixelSize: 11
        font.letterSpacing: 2
        font.bold: true
        color: CP.alpha(Colours.accentSecondary, 0.8)
    }

    // Languages as tabs rather than stacked sections: a series with 39 Italian
    // and 99 English chapters used to make you scroll past one to reach the
    // other. One row, one language shown at a time.
    Row {
        id: langTabs
        anchors.top: chapHead.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 4
        visible: root.availableLangs.length > 1

        Repeater {
            model: root.availableLangs
            delegate: CutShape {
                id: tab
                required property string modelData
                readonly property bool on: root.selectedLang === modelData
                readonly property int count: {
                    var n = 0
                    var src = root.ownChapters
                    for (var i = 0; i < src.length; i++)
                        if (src[i].lang === tab.modelData) n++
                    return n
                }
                width: tabLabel.implicitWidth + 16
                height: 20
                fillColor: on ? CP.alpha(Colours.accentSecondary, 0.85) : "transparent"
                strokeColor: CP.alpha(Colours.accentSecondary, on ? 1.0 : 0.35)
                strokeWidth: 1
                inset: 0.5
                cutBottomRight: 6
                Behavior on fillColor   { CAnim {} }
                Behavior on strokeColor { CAnim {} }

                Text {
                    id: tabLabel
                    anchors.centerIn: parent
                    text: tab.modelData.toUpperCase() + "  " + tab.count
                    font.family: "Oxanium"
                    font.pixelSize: 11
                    font.letterSpacing: 1.5
                    font.bold: true
                    color: tab.on ? CP.void_ : CP.alpha(Colours.textMuted, 0.85)
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectedLang = tab.modelData
                }
            }
        }
    }

    // Empty is a normal outcome, so it explains itself and offers a way out.
    Column {
        anchors.top: langTabs.visible ? langTabs.bottom : chapHead.bottom
        anchors.topMargin: 14
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8
        visible: !MangaService.loadingChapters && root.sortedChapters.length === 0

        Text {
            width: parent.width
            text: "No readable chapters in Italian, English or the original "
                + "language.\nChapters hosted by the publisher instead of by "
                + "MangaDex are left out, since they cannot be opened here."
            font.family: "Oxanium"
            font.pixelSize: 16
            color: CP.alpha(Colours.textMuted, 0.8)
            wrapMode: Text.WordWrap
        }

        CutShape {
            width: allLangLabel.implicitWidth + 20
            height: 20
            fillColor: "transparent"
            strokeColor: CP.alpha(Colours.accentSecondary, 0.5)
            strokeWidth: 1
            inset: 0.5
            cutBottomRight: 6

            Text {
                id: allLangLabel
                anchors.centerIn: parent
                text: "SHOW ALL LANGUAGES"
                font.family: "Oxanium"
                font.pixelSize: 11
                font.letterSpacing: 1.5
                font.bold: true
                color: CP.alpha(Colours.accentSecondary, 0.85)
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                // An empty language array drops the filter entirely.
                onClicked: if (root.manga)
                    MangaService.fetchChapters(root.manga, [], MangaState.contentRatings)
            }
        }
    }

    ListView {
        id: chapters
        anchors.top: langTabs.visible ? langTabs.bottom : chapHead.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        model: root.groupedChapters
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 0

        delegate: Column {
            id: row
            required property var modelData
            width: chapters.width

            readonly property var items: modelData.items
            readonly property bool many: items.length > 1
            readonly property bool open: root.expandedNumber === modelData.number
            // With one version there is nothing to choose, so the row acts as
            // the chapter itself rather than as a container.
            readonly property var only: items[0]

            Item {
                id: headRow
                width: parent.width
                height: 34

                Rectangle {
                    anchors.fill: parent
                    anchors.rightMargin: 2
                    color: chapMa.containsMouse ? CP.alpha(Colours.accentSecondary, 0.1)
                                                : "transparent"
                }

                // Long titles run past the badge, so the text lives in a
                // clipped viewport and scrolls on hover — same shape as the
                // marquee in the bar's MPRIS module: two copies chasing each
                // other with a gap, so the loop has no visible seam.
                Item {
                    id: chapNum
                    anchors.left: parent.left
                    anchors.leftMargin: 5
                    anchors.top: parent.top
                    anchors.topMargin: 4
                    // Stops before the source badge when there is one: both used
                    // to anchor to the page counter, so a long title ran
                    // underneath the badge instead of being cut before it.
                    anchors.right: srcTag.visible ? srcTag.left : badge.left
                    anchors.rightMargin: 8
                    height: title1.implicitHeight
                    clip: true

                    readonly property string label: "CH " + row.modelData.number
                        + (!row.many && row.only.title ? "  ·  " + row.only.title : "")
                    property real marqueeOffset: 0
                    readonly property real marqueeGap: 40
                    // Only when it actually overflows: a short title that slid
                    // around under the cursor would be noise, not feedback.
                    readonly property bool marqueeActive:
                        chapMa.containsMouse && title1.implicitWidth > width

                    onMarqueeActiveChanged: if (!marqueeActive) marqueeOffset = 0

                    Text {
                        id: title1
                        x: chapNum.marqueeActive ? chapNum.marqueeOffset : 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: chapNum.label
                        font.family: "Oxanium"
                        font.pixelSize: 14
                        font.letterSpacing: 0.5
                        color: chapMa.containsMouse ? Colours.accentSecondary
                                                    : Colours.textPrimary
                        // Elided only while parked: mid-scroll the ellipsis
                        // would sit in the middle of the moving text.
                        elide: chapNum.marqueeActive ? Text.ElideNone : Text.ElideRight
                        width: chapNum.marqueeActive ? implicitWidth : chapNum.width
                    }

                    Text {
                        visible: chapNum.marqueeActive
                        x: chapNum.marqueeOffset + title1.implicitWidth + chapNum.marqueeGap
                        anchors.verticalCenter: parent.verticalCenter
                        text: chapNum.label
                        font: title1.font
                        color: title1.color
                    }

                    SequentialAnimation {
                        running: chapNum.marqueeActive
                        loops: Animation.Infinite
                        PropertyAction { target: chapNum; property: "marqueeOffset"; value: 0 }
                        PauseAnimation { duration: 900 }
                        NumberAnimation {
                            target: chapNum
                            property: "marqueeOffset"
                            from: 0
                            to: -(title1.implicitWidth + chapNum.marqueeGap)
                            duration: Math.max(2500, title1.implicitWidth * 18)
                            easing.type: Easing.Linear
                        }
                        PauseAnimation { duration: 600 }
                    }
                }

                Text {
                    anchors.left: chapNum.left
                    anchors.top: chapNum.bottom
                    anchors.topMargin: 1
                    anchors.right: chapNum.right
                    text: row.many
                          ? row.items.length + " VERSIONS"
                          : (row.only.group || "NO GROUP")
                            + (row.only.volume ? "   ·   VOL " + row.only.volume : "")
                    font.family: "Oxanium"
                    font.pixelSize: 10
                    font.letterSpacing: 0.5
                    color: CP.alpha(Colours.accentPrimary, 0.7)
                    elide: Text.ElideRight
                }

                CutShape {
                    id: srcTag
                    visible: !row.many && MangaState.source === "all"
                    anchors.right: badge.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property bool mw: row.only.source === "mangaworld"
                    width: srcTagLabel.implicitWidth + 8
                    height: 13
                    fillColor: CP.alpha(mw ? CP.neon : Colours.accentSecondary, 0.85)
                    strokeColor: mw ? CP.neon : Colours.accentSecondary
                    strokeWidth: 1
                    inset: 0.5
                    cutBottomRight: 4

                    Text {
                        id: srcTagLabel
                        anchors.centerIn: parent
                        text: srcTag.mw ? "MW" : "MD"
                        font.family: "Oxanium"
                        font.pixelSize: 8
                        font.letterSpacing: 0.5
                        font.bold: true
                        color: CP.void_
                    }
                }

                Text {
                    id: badge
                    anchors.right: parent.right
                    anchors.rightMargin: 7
                    anchors.verticalCenter: parent.verticalCenter
                    // A grouped row shows a chevron instead of a page count:
                    // the versions disagree on how many pages they have, so any
                    // single number there would be a lie.
                    text: row.many
                          ? String.fromCodePoint(row.open ? 0xF0143 : 0xF0140)  // chevron up/down
                          : (row.only.pages > 0 ? row.only.pages + " PAG" : "")
                    font.family: row.many ? "JetBrainsMono Nerd Font" : "Oxanium"
                    font.pixelSize: row.many ? 14 : 11
                    font.letterSpacing: 1
                    color: CP.alpha(Colours.textMuted, row.many ? 0.85 : 0.6)
                }

                MouseArea {
                    id: chapMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!row.many) root.chapterActivated(row.only)
                        else root.expandedNumber = row.open ? "" : row.modelData.number
                    }
                }
            }

            // The versions, pushed in below the row that owns them. Height goes
            // to zero when closed so the list closes back up around it.
            Item {
                width: parent.width
                clip: true
                height: row.open ? variants.implicitHeight : 0
                Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Column {
                    id: variants
                    width: parent.width

                    Repeater {
                        model: row.open ? row.items : []
                        delegate: Item {
                            id: v
                            required property var modelData
                            width: variants.width
                            height: 26

                            Rectangle {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 2
                                color: vMa.containsMouse ? CP.alpha(Colours.accentSecondary, 0.12)
                                                         : CP.alpha(CP.void_, 0.35)
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 22
                                anchors.right: vSrc.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: (v.modelData.group || "NO GROUP")
                                    + (v.modelData.volume ? "   ·   VOL " + v.modelData.volume : "")
                                font.family: "Oxanium"
                                font.pixelSize: 11
                                font.letterSpacing: 0.5
                                color: vMa.containsMouse ? Colours.accentSecondary
                                                         : CP.alpha(Colours.textPrimary, 0.85)
                                elide: Text.ElideRight
                            }

                            CutShape {
                                id: vSrc
                                visible: MangaState.source === "all"
                                anchors.right: vPages.left
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                readonly property bool mw: v.modelData.source === "mangaworld"
                                width: vSrcLabel.implicitWidth + 8
                                height: 13
                                fillColor: CP.alpha(mw ? CP.neon : Colours.accentSecondary, 0.85)
                                strokeColor: mw ? CP.neon : Colours.accentSecondary
                                strokeWidth: 1
                                inset: 0.5
                                cutBottomRight: 4

                                Text {
                                    id: vSrcLabel
                                    anchors.centerIn: parent
                                    text: vSrc.mw ? "MW" : "MD"
                                    font.family: "Oxanium"
                                    font.pixelSize: 8
                                    font.letterSpacing: 0.5
                                    font.bold: true
                                    color: CP.void_
                                }
                            }

                            Text {
                                id: vPages
                                anchors.right: parent.right
                                anchors.rightMargin: 7
                                anchors.verticalCenter: parent.verticalCenter
                                text: v.modelData.pages > 0 ? v.modelData.pages + " PAG" : ""
                                font.family: "Oxanium"
                                font.pixelSize: 10
                                font.letterSpacing: 1
                                color: CP.alpha(Colours.textMuted, 0.6)
                            }

                            MouseArea {
                                id: vMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.chapterActivated(v.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
