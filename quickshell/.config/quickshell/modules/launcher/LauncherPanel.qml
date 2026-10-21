// LauncherPanel.qml — the menu, ported from AndreaNec/Cyberpunk-quickshell
// (launcher/Launcher.qml). One per screen; shows on the monitor that was
// focused when it was opened (LauncherState). Data lives in common/LauncherMenus.qml.
//
//   qs ipc call launcher toggle | open | close      (bound to SUPER+SPACE)
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../common/Colors.js" as CP
import "../../common"
import "../../common/effects"

Scope {
    id: root

    required property var screen

    readonly property bool shown: LauncherState.open && LauncherState.screenName === root.screen.name

    // ---------- State ----------
    property var stack: [LauncherMenus.rootNode]
    readonly property var current: stack[stack.length - 1]
    property string query: ""

    readonly property var results: {
        const q = query.trim().toLowerCase();
        const items = LauncherMenus.childrenOf(current);
        if (q === "")
            return items;
        // root: search the whole tree; inside a submenu: only that submenu
        const pool = stack.length > 1 ? items : LauncherMenus.flat;
        return LauncherMenus.search(pool, q);
    }

    readonly property string title: stack.length > 1 ? stack.slice(1).map(n => n.name).join(" › ").toUpperCase() : "MENU"

    // Wi-Fi scan / BT discovery only while their submenu is on screen
    readonly property string _sonarView: shown ? (current.id === "network" ? "net" : current.id === "bluetooth" ? "bt" : "") : ""
    on_SonarViewChanged: SonarState.menuView = _sonarView

    // ---------- Navigation ----------
    function close() {
        LauncherState.closeMenu();
    }
    function clearQuery() {
        search.text = "";
        query = "";
        list.currentIndex = 0;
    }
    function push(node) {
        stack = stack.concat([node]);
        clearQuery();
    }
    function pop() {
        stack = stack.slice(0, -1);
        clearQuery();
    }

    // Esc: clear the query first, then go up a level, then close
    function back() {
        if (query !== "")
            clearQuery();
        else if (stack.length > 1)
            pop();
        else
            close();
    }

    function activate(item) {
        if (!item)
            return;
        if (item.children) {
            push(item);
            return;
        }

        const keep = !!item.keepOpen;
        const idx = list.currentIndex;
        item.run();
        if (keep)
            Qt.callLater(() => {
                list.currentIndex = Math.max(0, Math.min(idx, list.count - 1));
            });
        else
            close();
    }

    onShownChanged: if (shown) {
        stack = [LauncherMenus.rootNode];
        clearQuery();
        Qt.callLater(() => search.forceActiveFocus());
    }

    // ---------- Window ----------
    PanelWindow {
        id: win
        screen: root.screen
        visible: root.shown || fx.visible
        color: "transparent"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "qs-launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Dim background, click anywhere outside the card to close
        Rectangle {
            anchors.fill: parent
            color: "#cc000000"
            opacity: root.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }
        }

        GlitchReveal {
            id: fx
            width: card.width
            height: card.height
            shown: root.shown
            anchors.left: parent.left
            anchors.leftMargin: 60
            y: parent.height * 0.18

            // ---------- Left-side column ----------
            Item {
                id: card
                width: 460
                implicitHeight: content.implicitHeight + 32
                height: implicitHeight

                MouseArea {
                    anchors.fill: parent
                }   // swallow clicks inside the card

                ColumnLayout {
                    id: content
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 16
                    spacing: 10

                    // Status line
                    Text {
                        text: "// LAUNCHER — RUNNING"
                        color: CP.redDark
                        font.pixelSize: 10
                        font.family: "Oxanium"
                    }

                    // Title + search
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: root.title
                            color: CP.cyan
                            font.bold: true
                            font.pixelSize: 20
                            font.family: "Oxanium"
                        }

                        TextInput {
                            id: search
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            verticalAlignment: TextInput.AlignVCenter
                            color: "#e6f7ff"
                            font.pixelSize: 14
                            font.family: "Oxanium"
                            clip: true
                            selectByMouse: true

                            onTextChanged: {
                                root.query = text;
                                list.currentIndex = 0;
                            }

                            Keys.onEscapePressed: root.back()
                            Keys.onDownPressed: list.incrementCurrentIndex()
                            Keys.onUpPressed: list.decrementCurrentIndex()
                            Keys.onReturnPressed: root.activate(list.currentItem ? list.currentItem.modelData : null)
                            Keys.onEnterPressed: root.activate(list.currentItem ? list.currentItem.modelData : null)
                            Keys.onPressed: e => {
                                if (e.key === Qt.Key_Backspace && text === "" && root.stack.length > 1) {
                                    root.pop();
                                    e.accepted = true;
                                } else if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_J) {
                                    list.incrementCurrentIndex();
                                    e.accepted = true;
                                } else if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_K) {
                                    list.decrementCurrentIndex();
                                    e.accepted = true;
                                }
                            }

                            Text {
                                visible: search.text === ""
                                text: "› SEARCH…"
                                color: CP.alpha(CP.cyan, 0.5)
                                font: search.font
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Separator
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: CP.alpha(CP.cyan, 0.4)
                    }

                    // ---------- Results ----------
                    ListView {
                        id: list

                        readonly property int rowHeight: 50
                        readonly property int maxVisible: 9

                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(count, maxVisible) * rowHeight
                        clip: true
                        interactive: false             // selection drives scrolling (keys, wheel, hover)
                        keyNavigationWraps: true

                        // Keep the selection near the center when there are many rows,
                        // but don't scroll past the ends, so short lists stay top-aligned
                        highlightRangeMode: ListView.ApplyRange
                        preferredHighlightBegin: height / 2 - rowHeight / 2
                        preferredHighlightEnd: height / 2 + rowHeight / 2
                        highlightMoveDuration: 120

                        model: ScriptModel {
                            values: root.results
                            objectProp: "id"      // rows with the same id are the same row
                        }

                        WheelHandler {
                            onWheel: e => {
                                if (e.angleDelta.y > 0)
                                    list.decrementCurrentIndex();
                                else
                                    list.incrementCurrentIndex();
                            }
                        }

                        delegate: LauncherEntry {
                            launcher: root
                        }
                    }

                    // Empty state
                    Text {
                        visible: list.count === 0
                        text: "// NO MATCH"
                        color: CP.alpha(CP.cyan, 0.5)
                        font.pixelSize: 12
                        font.family: "Oxanium"
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 8
                        Layout.bottomMargin: 8
                    }

                    // Key hints
                    Text {
                        text: "[ TYPE ] SEARCH   [ ↑↓ ] NAVIGATE   [ ENTER ] SELECT   [ ESC ] BACK"
                        color: CP.redDark
                        font.pixelSize: 9
                        font.family: "Oxanium"
                    }
                }
            }
        }
    }
}
