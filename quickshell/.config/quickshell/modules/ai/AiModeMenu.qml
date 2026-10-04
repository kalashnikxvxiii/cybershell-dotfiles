// AiModeMenu.qml - execution mode and effort, in one popup
//
// Shaped after the Cursor modes menu: each mode gets its glyph, its name and the
// one sentence that stays what it will do without asking, with a check on the one
// in force. Effort sits below a rule because it is a different axis: the mode
// says what Claude may do, the effort says how hard it works on it
import QtQuick
import "../../common"
import "../../common/Colors.js" as CP

Item {
    id: root

    property var modes: []      // ids, in display order
    property var info: ({})     // id -> { label, glyph, accent, desc }
    property string currentMode: ""
    property var effortLevels: []
    property string currentEffort: ""
    property bool enabled: true

    signal modePicked(string mode)
    signal effortPicked(string level)
    signal dismissed()

    readonly property color fg: "#d8e0e8"
    readonly property int rowH: 46
    readonly property int headerH: 22
    readonly property int effortH: 30

    implicitWidth: 300
    implicitHeight: root.headerH + root.modes.length * root.rowH
        + 1 + root.effortH + 12
    width: implicitWidth
    height: implicitHeight

    CutShape {
        anchors.fill: parent
        fillColor: CP.alpha(CP.void2, 0.97)
        strokeColor: CP.alpha(CP.magenta, 0.45)
        strokeWidth: 1
        inset: 0.5
        cutTopRight: 12
        cutBottomLeft: 12
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) { root.dismissed(); event.accepted = true }
    }

    // -- Header -----------------------------------
    Item {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.topMargin: 6
        height: root.headerH

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: "MODES"
            font.family: "Oxanium"
            font.pixelSize: 8
            font.letterSpacing: 2
            font.bold: true
            color: CP.alpha(root.fg, 0.38)
        }

        // The shortcut the composer binds, spelled the way the keyboard is
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\u21e7 + tab"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 9
                color: CP.alpha(CP.cyan, 0.55)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "to switch"
                font.family: "Oxanium"
                font.pixelSize: 9
                color: CP.alpha(root.fg, 0.30)
            }
        }
    }

    // -- Modes ------------------------------------------
    Column {
        id: list
        anchors { top: header.bottom; left: parent.left; right: parent.right }

        Repeater {
            model: root.modes

            delegate: Item {
                required property var modelData

                readonly property var meta: root.info[modelData] ?? ({})
                readonly property bool active: modelData === root.currentMode

                width: list.width
                height: root.rowH

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    color: CP.alpha(meta.accent ?? CP.cyan,
                        ma.containsMouse ? 0.11 : (active ? 0.07 : 0))
                    Behavior on color { ColorAnimation { duration: 110 } }
                }

                Text {
                    id: icon
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.top: parent.top
                    anchors.topMargin: 9
                    text: meta.glyph ?? ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: active ? (meta.accent ?? CP.cyan)
                        : CP.alpha(meta.accent ?? CP.cyan, 0.50)
                    Behavior on color { ColorAnimation { duration: 110 } }
                }

                Text {
                    id: title
                    anchors.left: icon.right
                    anchors.leftMargin: 11
                    anchors.right: check.left
                    anchors.rightMargin: 8
                    anchors.top: parent.top
                    anchors.topMargin: 7
                    text: meta.label ?? modelData
                    elide: Text.ElideRight
                    font.family: "Oxanium"
                    font.pixelSize: 12
                    font.bold: true
                    color: active ? root.fg : CP.alpha(root.fg, 0.80)
                }

                Text {
                    anchors.left: title.left
                    anchors.right: check.left
                    anchors.rightMargin: 8
                    anchors.top: title.bottom
                    anchors.topMargin: 2
                    text: meta.desc ?? ""
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    font.family: "Oxanium"
                    font.pixelSize: 10
                    lineHeight: 1.15
                    color: CP.alpha(root.fg, 0.40)
                }

                Text {
                    id: check
                    anchors.right: parent.right
                    anchors.rightMargin: 13
                    anchors.verticalCenter: parent.verticalCenter
                    visible: active
                    text: "\u2713"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: meta.accent ?? CP.cyan
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.enabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.modePicked(modelData)
                }
            }
        }
    }

    Rectangle {
        id: rule
        anchors { top: list.bottom; left: parent.left; right: parent.right }
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        height: 1
        color: CP.alpha(CP.magenta, 0.20)
    }

    // -- Effort ----------------------------------------
    AiEffortRow {
        id: effortRow
        anchors { top: rule.bottom; left: parent.left; right: parent.right }
        levels: root.effortLevels
        current: root.currentEffort
        enabled: root.enabled
        fg: root.fg
        onPicked: l => root.effortPicked(l)
    }
}