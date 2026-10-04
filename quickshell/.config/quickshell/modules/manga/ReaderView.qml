// ReaderView.qml — centered reading surface. Deliberately plain: this sits
// fullscreen for minutes at a time, so no scanlines, grain or glitch here —
// every per-frame effect would be constant GPU cost for as long as you read.
// The decoration belongs to the side panel, which you look at for seconds.
import "../../common/Colors.js" as CP
import "../../common"
import QtQuick

FocusScope {
    id: root

    property var    pages: []
    property string chapterLabel: ""
    property bool   dataSaver: true
    // Identifies the chapter, so a node refresh — which replaces the URLs but
    // not the images — keeps the measured ratios instead of throwing them away.
    property string chapterKey: ""
    property alias  contentY: list.contentY

    signal closeRequested()
    signal pageReached(int index)
    signal needsFreshNode()

    readonly property int pageCount: pages.length

    // ListView.currentIndex does not follow scrolling — it only moves on
    // explicit navigation — so the visible page is derived from what sits at
    // the centre of the viewport.
    property int pageIndex: 0
    readonly property int currentPage: Math.min(pageCount, pageIndex + 1)

    // Where a resume should land. Consumed once and cleared, so scrolling away
    // afterwards is not undone by a later relayout.
    property int startPage: 0
    onPagesChanged: if (root.startPage > 0 && root.pages.length > 0) _seekTimer.restart()

    Timer {
        id: _seekTimer
        // One tick after the pages arrive: the delegates need to exist before
        // the list can be positioned on one of them.
        interval: 60
        onTriggered: {
            var i = Math.min(root.startPage, root.pages.length - 1)
            list.positionViewAtIndex(i, ListView.Beginning)
            root.pageIndex = i
            root.startPage = 0
        }
    }

    readonly property int baseW: Math.min(940, root.width - 96)
    property real zoom: 1.0
    property real panX: 0
    readonly property int stageW: Math.round(baseW * zoom)
    // How far the page can slide sideways once it is wider than the viewport.
    readonly property real maxPan: Math.max(0, (stageW - root.width) / 2)

    // Measured aspect ratios, keyed by page index. With cacheBuffer: 0 an
    // off-screen delegate is destroyed, and on the way back up it would be
    // rebuilt with the crude estimate instead of its real height. Measured on
    // a real long-strip page: 722x9835, ratio 13.6 against an estimate of 1.4
    // — the pages above the viewport collapse by thousands of pixels and the
    // view snaps back down. Remembering the ratio keeps them stable.
    property var _ratios: ({})

    function _remember(idx, ratio) {
        if (!(ratio > 0) || root._ratios[idx] === ratio) return
        var m = ({})
        for (var k in root._ratios) m[k] = root._ratios[k]
        m[idx] = ratio
        root._ratios = m
    }

    function _estimate(idx) {
        var r = root._ratios[idx]
        return r > 0 ? r : 1.4
    }

    onChapterKeyChanged: root._ratios = ({})

    function setZoom(z) {
        root.zoom = Math.max(0.6, Math.min(3.0, z))
        root.panX = Math.max(-root.maxPan, Math.min(root.maxPan, root.panX))
    }

    focus: true
    // Zoomed past 1.0 the page is wider than this surface, and without a clip
    // it would paint over the drawer beside it.
    clip: true

    Rectangle {
        anchors.fill: parent
        color: CP.alpha(CP.void_, 0.97)
    }

    // Same reason: clicks on the reading surface must not reach whatever sits
    // behind it.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }

    // The chapter is pulled in one go before anything can be shown, so the wait
    // needs saying out loud — a few seconds of blank surface reads as a hang.
    Text {
        anchors.centerIn: parent
        visible: root.pages.length === 0
        text: MangaService.downloadingPages ? "◢ DOWNLOADING CHAPTER…"
            : MangaService.pagesError        ? "◢ " + MangaService.pagesError.toUpperCase()
            : "◢ WAITING…"
        font.family: "Oxanium"
        font.pixelSize: 14
        font.letterSpacing: 3
        font.bold: true
        color: MangaService.pagesError ? CP.red : CP.alpha(Colours.accentSecondary, 0.8)
    }

    ListView {
        id: list
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: root.panX
        anchors.top: parent.top
        anchors.bottom: bar.top
        width: root.stageW
        clip: true
        model: root.pages
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 4000
        maximumFlickVelocity: 6000

        // The single most important line for memory. A long-strip page decodes
        // to ~30 MB regardless of dataSaver — that only shrinks the download.
        // With no buffer, ListView destroys off-screen delegates and the pages
        // go with them; a whole chapter held live would be ~550 MB.
        cacheBuffer: 0

        // Ctrl+wheel zooms, Shift+wheel slides sideways once zoomed. Both sit
        // on the ListView so they take the event before Flickable scrolls.
        WheelHandler {
            acceptedModifiers: Qt.ControlModifier
            onWheel: event => {
                root.setZoom(root.zoom + (event.angleDelta.y > 0 ? 0.12 : -0.12))
                event.accepted = true
            }
        }
        WheelHandler {
            acceptedModifiers: Qt.ShiftModifier
            onWheel: event => {
                root.panX = Math.max(-root.maxPan,
                            Math.min(root.maxPan, root.panX + event.angleDelta.y / 3))
                event.accepted = true
            }
        }

        onContentYChanged: {
            var i = list.indexAt(list.width / 2, list.contentY + list.height / 2)
            if (i >= 0 && i !== root.pageIndex) { root.pageIndex = i; root.pageReached(i) }
        }

        delegate: Item {
            id: cell
            required property int index
            required property string modelData

            width: list.width
            // Until the image reports its size the height is a guess, so the
            // scrollbar shifts as pages resolve. Unavoidable without a
            // dimensions endpoint, and 1.4 is close for standard pages.
            height: img.status === Image.Ready && img.implicitWidth > 0
                    ? img.implicitHeight * (list.width / img.implicitWidth)
                    : list.width * root._estimate(cell.index)

            Image {
                id: img
                anchors.fill: parent
                source: cell.modelData
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                // Not cached on purpose: reading is linear, and Qt's pixmap
                // cache would keep decoded pages alive after their delegate is
                // gone, defeating cacheBuffer: 0.
                cache: false
                // Quantised on purpose: bound straight to list.width the page
                // would be decoded again at every wheel notch — a dozen full
                // re-decodes to go from 100% to 200%. Steps of 200px keep it
                // sharp while decoding a handful of times.
                sourceSize.width: Math.ceil(list.width / 200) * 200
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 140 } }
                // MangaDex at-home nodes fail intermittently: the same URL that
                // 404s now answers 200 a second later, verified with curl. So
                // a failed page is retried rather than declared missing.
                property int _retries: 0

                onStatusChanged: {
                    if (status === Image.Ready) {
                        img._retries = 0
                        if (implicitWidth > 0)
                            root._remember(cell.index, implicitHeight / implicitWidth)
                    } else if (status === Image.Error) {
                        // Pages are local files now, so a failure here means the
                        // download did not produce that page. Retry locally
                        // first, then ask for a refetch: the helper script only
                        // pulls what is missing, so it is a cheap repair.
                        if (img._retries < 2) retryTimer.restart()
                        else root.needsFreshNode()
                    }
                }

                Timer {
                    id: retryTimer
                    // Backing off a little: an immediate retry tends to hit the
                    // same failing node in the same state.
                    interval: 400 + img._retries * 600
                    onTriggered: {
                        img._retries++
                        // Re-assigning the same string is a no-op, so the source
                        // is cleared first to force a fresh request.
                        var s = cell.modelData
                        img.source = ""
                        img.source = s
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: img.status !== Image.Ready
                text: img.status === Image.Error
                    ? (img._retries < 2 ? "RETRYING PAGE " + (cell.index + 1) + "…"
                                        : "PAGE " + (cell.index + 1) + " NOT AVAILABLE")
                    : "LOADING " + (cell.index + 1)
                font.family: "Oxanium"
                font.pixelSize: 16
                font.letterSpacing: 3
                color: CP.alpha(Colours.textMuted, 0.6)
            }
        }
    }

    // ── Bottom bar: label, counter, progress ─────────────────────
    Item {
        id: bar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 26

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: root.chapterLabel + "      ↑↓←→  MOVE · + / −  ZOOM · 0  RESET · PGUP/PGDN  PAGE"
            font.family: "Oxanium"
            font.pixelSize: 13
            font.letterSpacing: 2
            font.bold: true
            color: Colours.accentSecondary
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(root.zoom * 100) + "%   ·   "
                + root.currentPage + " / " + root.pageCount
                + (root.dataSaver ? "   ·   DATA-SAVER" : "   ·   FULL")
            font.family: "Oxanium"
            font.pixelSize: 13
            font.letterSpacing: 2
            color: CP.alpha(Colours.textMuted, 0.85)
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            height: 2
            width: root.pageCount > 0 ? parent.width * (root.currentPage / root.pageCount) : 0
            color: Colours.accentSecondary
            Behavior on width { NumberAnimation { duration: 120 } }
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) { root.closeRequested(); event.accepted = true }
        // Arrows nudge the page; PageUp/PageDown and Space keep the big jump.
        else if (event.key === Qt.Key_Down) {
            list.contentY = Math.min(Math.max(0, list.contentHeight - list.height), list.contentY + 90)
            event.accepted = true
        }
        else if (event.key === Qt.Key_Up) {
            list.contentY = Math.max(0, list.contentY - 90)
            event.accepted = true
        }
        // Horizontal arrows pan only while the page is wider than the viewport:
        // with maxPan at 0 the clamp collapses both branches to a no-op, so
        // they stay harmless at 100%.
        else if (event.key === Qt.Key_Left) {
            root.panX = Math.min(root.maxPan, root.panX + 90)
            event.accepted = true
        }
        else if (event.key === Qt.Key_Right) {
            root.panX = Math.max(-root.maxPan, root.panX - 90)
            event.accepted = true
        }
        else if (event.key === Qt.Key_PageDown || event.key === Qt.Key_Space) {
            list.contentY = Math.min(Math.max(0, list.contentHeight - list.height), list.contentY + list.height * 0.9)
            event.accepted = true
        }
        else if (event.key === Qt.Key_PageUp) {
            list.contentY = Math.max(0, list.contentY - list.height * 0.9)
            event.accepted = true
        }
        else if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) { root.setZoom(root.zoom + 0.15); event.accepted = true }
        else if (event.key === Qt.Key_Minus) { root.setZoom(root.zoom - 0.15); event.accepted = true }
        else if (event.key === Qt.Key_0) { root.zoom = 1.0; root.panX = 0; event.accepted = true }
        else if (event.key === Qt.Key_Home) { list.positionViewAtBeginning(); event.accepted = true }
        else if (event.key === Qt.Key_End)  { list.positionViewAtEnd();       event.accepted = true }
    }

    function scrollBy(px) {
        list.contentY = Math.max(0, Math.min(list.contentHeight - list.height, list.contentY + px))
    }
}
