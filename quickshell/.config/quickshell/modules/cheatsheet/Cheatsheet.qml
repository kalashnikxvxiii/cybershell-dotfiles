// Cheatsheet.qml -- the keymap: every Hyprland bind, read live from `hyprctl binds`.
//
// Full screen by default, with keyboard focus for the search. Minimized, it turns
// into a resizable card pinned to the bottom right corner that takes no focus and
// lets clicks through around it, so it can stay up while working. Opening, closing
// and switching between the two use the same GlitchReveal as the launcher.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../common"
import "../../common/effects"
import "../../common/Colors.js" as CP
import "CheatsheetModel.js" as Model

Scope {
    id: root

    property string screenName: ""
    property var sections: []
    property bool shown: false
    property bool mini: false
    // Set while the glitch runs out, so the new mode comes in with a glitch of its own
    property var pendingMini: null
    property string query: ""
    property string modFilter: ""

    // Size of the minimized card; resets with the shell
    property real miniWidth: 440
    property real miniHeight: 440
    readonly property int miniMargin: 14
    readonly property int minSize: 300

    readonly property int rowCount: {
        var n = 0
        for (var i = 0; i < sections.length; i++) n += sections[i].rows.length
        return n
    }
    readonly property int matchCount: {
        var n = 0
        for (var i = 0; i < sections.length; i++)
            for (var j = 0; j < sections[i].rows.length; j++)
                if (Model.matches(sections[i].rows[j], query, modFilter)) n++
        return n
    }

    function open(screen) {
        screenName = screen
        clearFilters()
        pendingMini = null
        mini = false
        bindsReader.running = true
    }

    function clearFilters() {
        search.text = ""
        modFilter = ""
    }

    function finishSwap() {
        if (pendingMini === null) return
        mini = pendingMini
        pendingMini = null
        shown = true
    }

    function close() {
        pendingMini = null
        shown = false
    }

    // Glitch out, swap the mode once it is over, glitch back in
    function setMini(value) {
        if (mini === value || pendingMini !== null) return
        pendingMini = value
        shown = false
    }

    IpcHandler {
        target: "cheatsheet"

        function toggle(screen: string): void {
            if (root.shown) root.close()
            else root.open(screen)
        }

        function minimize(): void { root.setMini(true) }
        function maximize(): void { root.setMini(false) }
    }

    Process {
        id: bindsReader
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.sections = Model.build(JSON.parse(text))
                root.shown = true
            }
        }
    }

    PanelWindow {
        id: win

        screen: Quickshell.screens.find(s => s.name === root.screenName) || null
        visible: root.shown || fx.visible || root.pendingMini !== null
        color: "transparent"

        WlrLayershell.namespace: "qs-cheatsheet"
        // Overlay, so it also reaches a fullscreen window
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: root.shown && !root.mini ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors { top: true; bottom: true; left: true; right: true }

        // Only the card takes the pointer: in the minimized form everything
        // around it stays clickable
        mask: Region { item: card }

        GlitchReveal {
            id: fx
            anchors.fill: parent
            shown: root.shown

            // Later, not here: `shown` feeds this very `visible`
            onVisibleChanged: if (!visible) Qt.callLater(root.finishSwap)

            Item {
                id: card
                x: root.mini ? parent.width - width - root.miniMargin : 0
                y: root.mini ? parent.height - height - root.miniMargin : 0
                width: root.mini ? Math.min(root.miniWidth, parent.width - 2 * root.miniMargin) : parent.width
                height: root.mini ? Math.min(root.miniHeight, parent.height - 2 * root.miniMargin) : parent.height

                // Full screen: a dark veil over the blurred desktop, with the mesh
                Rectangle {
                    anchors.fill: parent
                    visible: !root.mini
                    color: Qt.rgba(0, 6/255, 14/255, 0.9)
                }

                NeuralBackdrop {
                    anchors.fill: parent
                    visible: !root.mini
                    // Off when minimized: a card left up while working costs nothing
                    live: root.shown && !root.mini
                }

                // Minimized: the usual panel, fill plus border
                CutShape {
                    anchors.fill: parent
                    visible: root.mini
                    cutTopRight: 18
                    cutBottomLeft: 18
                    inset: 0.5
                    fillColor: Qt.rgba(0.03, 0.045, 0.08, 0.96)
                    strokeColor: CP.alpha(CP.cyan, 0.55)
                }

                ScanlineOverlay {
                    opacity: 0.06
                }

                // Swallows clicks on the card itself
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onClicked: search.forceActiveFocus()
                }

                // ── Header ───────────────────────────────────────────────
                Item {
                    id: header
                    x: root.mini ? 14 : 28
                    y: root.mini ? 12 : 22
                    width: parent.width - 2 * x
                    height: root.mini ? 28 : 62

                    HeaderButton {
                        id: minButton
                        anchors.left: parent.left
                        anchors.top: parent.top
                        glyph: root.mini ? "◤" : "◢"
                        tone: CP.cyan
                        onClicked: root.setMini(!root.mini)
                    }

                    HeaderButton {
                        id: closeButton
                        anchors.right: parent.right
                        anchors.top: parent.top
                        glyph: "✕"
                        tone: CP.red
                        onClicked: root.close()
                    }

                    // Accent bar + hero title + status line
                    Rectangle {
                        visible: !root.mini
                        x: minButton.width + 16
                        width: 5
                        height: parent.height
                        color: CP.yellow
                    }

                    Column {
                        visible: !root.mini
                        x: minButton.width + 31
                        spacing: 1

                        Text {
                            text: "KEYMAP"
                            font.family: "Oxanium"
                            font.pixelSize: 38
                            font.letterSpacing: 8
                            color: CP.yellow
                        }

                        Text {
                            text: "· " + (root.query !== "" || root.modFilter !== ""
                                    ? root.matchCount + " OF " + root.rowCount + " BINDS"
                                    : root.rowCount + " BINDS") + " · LIVE FROM HYPRLAND"
                            font.family: "Oxanium"
                            font.pixelSize: 10
                            font.letterSpacing: 2
                            color: CP.alpha(CP.yellow, 0.65)
                        }
                    }

                    Text {
                        visible: root.mini
                        x: minButton.width + 10
                        height: parent.height
                        verticalAlignment: Text.AlignVCenter
                        text: "◢ KEYMAP"
                        font.family: "Oxanium"
                        font.pixelSize: 15
                        font.bold: true
                        font.letterSpacing: 3
                        color: CP.yellow
                    }

                    // Search: typing goes here straight away
                    Item {
                        visible: !root.mini
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        width: 420
                        height: 30

                        CutShape {
                            anchors.fill: parent
                            cutTopRight: 8
                            cutBottomLeft: 8
                            inset: 0.5
                            fillColor: Qt.rgba(0.03, 0.045, 0.08, 0.9)
                            strokeColor: CP.alpha(CP.cyan, search.text !== "" ? 1 : 0.45)
                        }

                        TextInput {
                            id: search
                            x: 12
                            width: parent.width - 24
                            height: parent.height
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: "Oxanium"
                            font.pixelSize: 13
                            font.letterSpacing: 1
                            color: "#e8f2f4"
                            selectByMouse: true
                            onTextChanged: root.query = text

                            Keys.onEscapePressed: {
                                if (root.query !== "" || root.modFilter !== "") root.clearFilters()
                                else root.close()
                            }
                        }

                        Text {
                            x: 12
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            visible: search.text === ""
                            text: "TYPE TO SEARCH · ESC CLOSES"
                            font.family: "Oxanium"
                            font.pixelSize: 11
                            font.letterSpacing: 2
                            color: "#7f9296"
                        }
                    }

                    // The grammar of the binds, doubling as a filter
                    Row {
                        visible: !root.mini
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        spacing: 8

                        Repeater {
                            model: [
                                { mod: "SUPER", verb: "OPEN, GO" },
                                { mod: "SHIFT", verb: "SEND THERE" },
                                { mod: "CTRL", verb: "VARIANT" },
                                { mod: "ALT", verb: "TUNE" }
                            ]

                            Item {
                                id: legend
                                required property var modelData
                                readonly property bool on: root.modFilter === modelData.mod
                                width: legendRow.width + 12
                                height: 24
                                opacity: root.modFilter === "" || on ? 1 : 0.4

                                Rectangle {
                                    anchors.fill: parent
                                    color: legend.on ? CP.alpha(CP.yellow, 0.14)
                                        : legendHover.containsMouse ? CP.alpha(CP.cyan, 0.1) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                Row {
                                    id: legendRow
                                    x: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    KeyChips {
                                        mods: [legend.modelData.mod]
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: legend.modelData.verb
                                        font.family: "Oxanium"
                                        font.pixelSize: 10
                                        font.letterSpacing: 1.5
                                        color: "#93a6aa"
                                    }
                                }

                                MouseArea {
                                    id: legendHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.modFilter = legend.on ? "" : legend.modelData.mod
                                        search.forceActiveFocus()
                                    }
                                }
                            }
                        }
                    }
                }

                CheatsheetBoard {
                    x: root.mini ? 14 : 28
                    y: header.y + header.height + (root.mini ? 6 : 10)
                    width: parent.width - 2 * x
                    height: parent.height - y - (root.mini ? 16 : 18)
                    sections: root.sections
                    query: root.query
                    modFilter: root.modFilter
                }

                CornerAccents {
                    visible: !root.mini
                    accentColor: CP.alpha(CP.yellow, 0.7)
                    size: 22
                }

                // ── Resize handles: the card is pinned bottom right, so only
                // its top and left edges move ──────────────────────────────
                ResizeHandle {
                    x: 0
                    y: 24
                    width: 6
                    height: parent.height - 24
                    cursorShape: Qt.SizeHorCursor
                    resizeWidth: true
                }

                ResizeHandle {
                    x: 24
                    y: 0
                    width: parent.width - 24 - closeButton.width - 30
                    height: 6
                    cursorShape: Qt.SizeVerCursor
                    resizeHeight: true
                }

                ResizeHandle {
                    x: 0
                    y: 0
                    width: 12
                    height: 12
                    cursorShape: Qt.SizeFDiagCursor
                    resizeWidth: true
                    resizeHeight: true
                }
            }
        }
    }

    onShownChanged: if (shown && !mini) search.forceActiveFocus()

    component HeaderButton: Item {
        id: button
        property string glyph: ""
        property color tone: CP.cyan
        signal clicked()

        width: 28
        height: 28

        CutShape {
            anchors.fill: parent
            cutBottomRight: 7
            inset: 0.5
            fillColor: Qt.rgba(button.tone.r, button.tone.g, button.tone.b, buttonHover.containsMouse ? 0.3 : 0.08)
            strokeColor: Qt.rgba(button.tone.r, button.tone.g, button.tone.b, buttonHover.containsMouse ? 1 : 0.55)

            Behavior on fillColor { ColorAnimation { duration: 120 } }
        }

        Text {
            anchors.centerIn: parent
            text: button.glyph
            font.family: "Oxanium"
            font.pixelSize: 13
            font.bold: true
            color: button.tone
        }

        MouseArea {
            id: buttonHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    component ResizeHandle: MouseArea {
        id: handle
        property bool resizeWidth: false
        property bool resizeHeight: false
        property real grabX: 0
        property real grabY: 0
        property real grabW: 0
        property real grabH: 0

        enabled: root.mini
        visible: root.mini
        preventStealing: true

        onPressed: mouse => {
            var p = mapToItem(null, mouse.x, mouse.y)
            grabX = p.x
            grabY = p.y
            grabW = root.miniWidth
            grabH = root.miniHeight
        }
        onPositionChanged: mouse => {
            if (!pressed) return
            var p = mapToItem(null, mouse.x, mouse.y)
            if (resizeWidth) root.miniWidth = Math.max(root.minSize, grabW + grabX - p.x)
            if (resizeHeight) root.miniHeight = Math.max(root.minSize, grabH + grabY - p.y)
        }
    }
}
