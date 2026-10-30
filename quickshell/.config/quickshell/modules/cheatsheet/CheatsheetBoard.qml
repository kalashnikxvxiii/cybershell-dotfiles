// CheatsheetBoard.qml -- the sections in columns with dividers. Rows shrink to
// fit, so at full screen the whole keymap shows without scrolling; only a window
// too small for that scrolls.
pragma ComponentBehavior: Bound

import QtQuick
import "CheatsheetModel.js" as Model
import "../../common/Colors.js" as CP

Item {
    id: root

    property var sections: []
    property string query: ""
    property string modFilter: ""

    readonly property int columnCount: Math.max(1, Math.floor(width / 340))
    readonly property var columns: Model.pack(sections, columnCount)
    readonly property int headerHeight: 44
    readonly property int minRowHeight: 34
    readonly property int maxRowHeight: 42
    readonly property int columnGap: 18
    readonly property bool searching: query !== "" || modFilter !== ""

    readonly property int rowHeight: {
        var fit = maxRowHeight
        for (var i = 0; i < columns.length; i++) {
            var rows = 0
            for (var j = 0; j < columns[i].length; j++) rows += columns[i][j].rows.length
            if (rows > 0)
                fit = Math.min(fit, (height - columns[i].length * headerHeight) / rows)
        }
        return Math.max(minRowHeight, Math.floor(fit))
    }

    function accentFor(title) {
        if (title === "APPS" || title === "TOOLS") return CP.yellow
        if (title === "WINDOWS" || title === "WALLPAPER" || title === "CAPTURE") return CP.cyan
        if (title === "WORKSPACES" || title === "LOOK") return CP.magenta
        if (title === "SYSTEM") return CP.red
        if (title === "MEDIA") return CP.amber
        return CP.neon
    }

    Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: strip.height
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        Row {
            id: strip
            spacing: root.columnGap

            Repeater {
                model: root.columns

                Column {
                    id: column
                    required property var modelData
                    required property int index
                    width: (root.width - (root.columns.length - 1) * root.columnGap) / root.columns.length

                    Repeater {
                        model: column.modelData

                        Column {
                            id: block
                            required property var modelData
                            readonly property color accent: root.accentFor(modelData.title)
                            width: column.width

                            // Section header: "◢ TITLE", accent bar, and the bind
                            // that opens the menu when the section is a menu
                            Item {
                                width: parent.width
                                height: root.headerHeight

                                Rectangle {
                                    y: 12
                                    width: 5
                                    height: 20
                                    color: block.accent
                                }

                                Text {
                                    x: 13
                                    y: 12
                                    height: 20
                                    verticalAlignment: Text.AlignVCenter
                                    text: "◢ " + block.modelData.title
                                    font.family: "Oxanium"
                                    font.pixelSize: 15
                                    font.bold: true
                                    font.letterSpacing: 3
                                    color: block.accent
                                }

                                KeyChips {
                                    visible: block.modelData.entry !== null
                                    anchors.right: parent.right
                                    anchors.rightMargin: 4
                                    y: 13
                                    mods: block.modelData.entry ? block.modelData.entry.mods : []
                                    keys: block.modelData.entry ? block.modelData.entry.keys : []
                                }

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 6
                                    width: parent.width
                                    height: 1
                                    color: block.accent
                                    opacity: 0.25
                                }
                            }

                            Repeater {
                                model: block.modelData.rows

                                CheatsheetRow {
                                    required property var modelData
                                    row: modelData
                                    width: block.width
                                    height: root.rowHeight
                                    accent: block.accent
                                    searching: root.searching
                                    matched: Model.matches(modelData, root.query, root.modFilter)
                                }
                            }
                        }
                    }
                }
            }
        }

        // Column dividers
        Repeater {
            model: Math.max(0, root.columns.length - 1)

            Rectangle {
                required property int index
                x: (index + 1) * (root.width + root.columnGap) / root.columns.length - root.columnGap / 2
                width: 1
                height: Math.max(strip.height, flick.height)
                color: CP.alpha(CP.cyan, 0.2)
            }
        }
    }

    // Scroll position, only in a window too small for the whole keymap
    Rectangle {
        visible: flick.interactive
        anchors.right: parent.right
        y: flick.visibleArea.yPosition * parent.height
        width: 2
        height: flick.visibleArea.heightRatio * parent.height
        color: CP.cyan
        opacity: 0.6
    }
}
