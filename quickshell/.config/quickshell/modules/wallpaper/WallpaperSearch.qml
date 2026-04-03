import Quickshell.Io
import QtQuick
import "../../common/Colors.js" as CP
import "../../common"

Item {
    id: root
    implicitWidth: expanded ? 360 : 44
    implicitHeight: 44
    clip: true

    property bool expanded: false
    property bool searching: false
    property int currentPage: 1
    property string currentQuery: ""
    property bool hasMore: true
    property int _pageResultCount: 0

    signal resultClicked(string thumbPath, string fullUrl)
    signal firstResultReady()

    function focusInput() {
        searchInput.forceActiveFocus()
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
            searchInput.forceActiveFocus()
        }
    }

    Row {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 6
        visible: root.expanded

        TextInput {
            id: searchInput
            width: parent.width - submitBtn.width - stopBtn.width - 18
            height: parent.height
            verticalAlignment: TextInput.AlignVCenter
            font.family: "Oxanium"
            font.pixelSize: 12
            color: Colours.textPrimary
            selectionColor: CP.alpha(CP.cyan, 0.3)

            onAccepted: {
                if (text.trim() !== "") {
                    root.currentQuery = text.trim()
                    root.currentPage = 1
                    root.hasMore = true
                    root.searching = true
                    searchResultsModel.clear()
                    searchProc.command = ["bash",
                        "/home/kalashnikxv/.config/quickshell/scripts/search-wallpapers.sh",
                        root.currentQuery, "1"]
                    searchProc.running = true
                    searchInput.focus = false
                    root.parent.forceActiveFocus()
                }
            }

            Keys.onEscapePressed: {
                root.expanded = false
                root.parent.forceActiveFocus()
            }
        }

        Text {
            id: submitBtn
            width: 20; height: parent.height
            text: "\u2192"
            font.pixelSize: 14
            color: Colours.accentSecondary
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: searchInput.accepted()
            }
        }

        Text {
            id: stopBtn
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

    Process {
        id: searchProc
        command: ["true"]
        running: false
        stdout: SplitParser {
            onRead: data => {
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
                        searchResultsModel.append({
                            fname: parts[0],
                            thumbPath: parts[1],
                            fullUrl: parts[2]
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
