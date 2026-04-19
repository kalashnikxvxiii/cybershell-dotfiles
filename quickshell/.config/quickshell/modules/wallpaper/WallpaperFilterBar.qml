import "../../common/Colors.js" as CP
import "../../common"
import QtQuick.Layouts
import QtQuick

Item {
    id: root
    implicitHeight: 44
    implicitWidth: layout.implicitWidth + 24

    readonly property alias searchInputFocused: wallpaperSearch.inputFocused
    readonly property alias searchExpanded:     wallpaperSearch.expanded
    readonly property alias isLocalFilter:      wallpaperSearch.isLocalFilter
    readonly property alias resultsModel:       wallpaperSearch.resultsModel
    readonly property alias searching:          wallpaperSearch.searching

    property alias  currentSort:                wallpaperSearch.currentSort

    property bool   favoritesOnly:  false
    property int    favCount:       0
    
    signal searchResultClicked(string thumbPath, string fullUrl)
    signal localFilterChanged(string keywords)
    signal searchFirstResult()

    function resubmit() { wallpaperSearch.resubmit() }

    function activateSearch() {
        wallpaperSearch.expanded = true
        wallpaperSearch.focusInput()
    }

    function loadMoreResults() {
        wallpaperSearch.loadMore()
    }

    function closeSearch() {
        wallpaperSearch.closeSearch()
    }

    CutShape {
        anchors.fill: parent
        fillColor: CP.moduleBg
        strokeColor: CP.alpha(CP.cyan, 0.3)
        strokeWidth: 1
        inset: 0.5
        cutTopLeft: 8
        cutTopRight: 8
    }

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 6

        // ── Favorites filter ──────────────────────────────────────────
        Item {
            Layout.preferredWidth: favFilterVisible ? favLabel.implicitWidth + 20 : 0
            Layout.preferredHeight: 28
            Layout.rightMargin: favFilterVisible ? 0 : -6
            opacity: favFilterVisible ? 1 : 0
            clip: true

            property bool favFilterVisible: root.favCount > 0 || root.favoritesOnly

            readonly property bool active: root.favoritesOnly

            Behavior on Layout.preferredWidth   { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on Layout.rightMargin      { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on opacity                 { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            CutShape {
                anchors.fill: parent
                fillColor: parent.active ? CP.alpha(CP.red, 0.2) : "transparent"
                strokeColor: parent.active ? CP.red : CP.alpha(CP.red, 0.3)
                strokeWidth: 1
                inset: 0.5
                cutTopLeft: 4
                cutBottomRight: 4
            }

            Text {
                id: favLabel
                anchors.centerIn: parent
                text: "\u2665"
                font.pixelSize: 12
                color: parent.active ? CP.red : Colours.textMuted
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.favoritesOnly = !root.favoritesOnly
            }
        }

        // ── Macro filters ──────────────────────────────────────────
        Repeater {
            model: ["all", "awww", "wpe"]
            delegate: Item {
                Layout.preferredWidth: macroLabel.implicitWidth + 20
                Layout.preferredHeight: 28

                required property string modelData
                required property int index

                readonly property bool active: WallpaperState.macroFilter === modelData

                CutShape {
                    anchors.fill: parent
                    fillColor: parent.active ? CP.alpha(CP.cyan, 0.2) : "transparent"
                    strokeColor: parent.active ? Colours.accentSecondary : CP.alpha(CP.cyan, 0.2)
                    strokeWidth: 1
                    inset: 0.5
                    cutTopLeft: 4
                    cutBottomRight: 4
                }

                Text {
                    id: macroLabel
                    anchors.centerIn: parent
                    text: modelData.toUpperCase()
                    font.family: "Oxanium"
                    font.pixelSize: 11
                    font.letterSpacing: 2
                    font.bold: parent.active
                    color: parent.active ? Colours.accentSecondary : Colours.textMuted
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: WallpaperState.macroFilter = modelData
                }
            }
        }

        // ── Sub-Filters (animated expand) ────────────────────────────────────────────────────────────
        Repeater {
            id: subRepeater
            model: {
                if (WallpaperState.macroFilter === "awww") return ["image", "gif"]
                if (WallpaperState.macroFilter === "wpe") return ["scene", "video"]
                return []
            }
            delegate: Item {
                required property string modelData
                Layout.preferredWidth: subVisible ? subLabel.implicitWidth + 16 : 0
                Layout.preferredHeight: 24
                opacity: subVisible ? 1 : 0
                clip: true

                property bool subVisible : WallpaperState.macroFilter !== "all"
                readonly property bool active: WallpaperState.subFilter === modelData

                Behavior on Layout.preferredWidth { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                CutShape {
                    anchors.fill: parent
                    fillColor: parent.active ? CP.alpha(CP.yellow, 0.15) : "transparent"
                    strokeColor: parent.active
                                ? Colours.accentPrimary
                                : CP.alpha(CP.yellow, 0.2)
                    strokeWidth: 1
                    inset: 0.5
                    cutTopLeft: 3
                    cutBottomRight: 3
                }

                Text {
                    id: subLabel
                    anchors.centerIn: parent
                    text: modelData.toUpperCase()
                    font.family: "Oxanium"
                    font.pixelSize: 10
                    font.letterSpacing: 1
                    color: parent.active ? Colours.accentPrimary : Colours.textMuted
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        WallpaperState.subFilter =
                            WallpaperState.subFilter === modelData ? "" : modelData
                    }
                }
            }
        }

        // ── Separator ────────────────────────────────────────────────
        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 28
            Layout.alignment: Qt.AlignVCenter
            color: CP.alpha(CP.cyan, 0.25)
        }

        // ── Color circles ──────────────────────────────────────────────
        Repeater {
            model: [
                "#ff0000", "#ff8800", "#ffff00", "#00ff00",
                "#0088ff", "#8800ff", "#ff00ff", "#888888"
            ]
            delegate: Item {
                required property string modelData
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                readonly property bool active: WallpaperState.colorFilter === modelData

                CutShape {
                    anchors.centerIn: parent
                    width: 12; height: 12
                    cutBottomRight: 3
                    fillColor: modelData
                    strokeColor: parent.active ? "#ffffff" : "transparent"
                    strokeWidth: 2
                    inset: 0.5
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        WallpaperState.colorFilter =
                            WallpaperState.colorFilter === modelData ? "" : modelData
                    }
                }
            }
        }

        // ── Clear color filter ────────────────────────────────────────────────
        Item {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            visible: WallpaperState.colorFilter !== ""

            Text {
                anchors.centerIn: parent
                text: "\u2715"      // x
                font.pixelSize: 12
                color: Colours.textMuted
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: WallpaperState.colorFilter = ""
            }
        }

        // ── Separator before search ─────────────────────────────────
        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 28
            Layout.alignment: Qt.AlignVCenter
            color: CP.alpha(CP.cyan, 0.25)
        }

        WallpaperSearch {
            id: wallpaperSearch
            Layout.preferredHeight: 32
            onFirstResultReady: root.searchFirstResult()
            onLocalFilterChanged: keywords => root.localFilterChanged(keywords)
        }
    }
}