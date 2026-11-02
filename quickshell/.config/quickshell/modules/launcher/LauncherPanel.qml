// LauncherPanel.qml — the menu, ported from AndreaNec/Cyberpunk-quickshell
// (launcher/Launcher.qml). One per screen; shows on the monitor that was
// focused when it was opened (LauncherState). Data lives in common/LauncherMenus.qml.
//
//   qs ipc call launcher toggle | open | close      (bound to SUPER+SPACE)
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
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
    // The item waiting for a second activation: reboot and power off don't go on one slip
    property string armedId: ""
    // The keybind being edited; while set, the form takes the list's place
    property var bindDraft: null
    // The palette being edited, same idea
    property var paletteDraft: null

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
        armedId = "";
        bindDraft = null;
        paletteDraft = null;
        search.text = "";
        query = "";
        list.currentIndex = 0;
    }
    function push(node) {
        if (node.onEnter)
            node.onEnter();
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
        if (item.draft) {
            root.bindDraft = item.draft;
            return;
        }
        if (item.paletteDraft) {
            root.paletteDraft = item.paletteDraft;
            return;
        }
        if (item.confirm && root.armedId !== item.id) {
            root.armedId = item.id;
            return;
        }
        root.armedId = "";

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

    Connections {
        target: root
        function onShownChanged() { Sounds.play("menu", root.shown ? "kiroshi_on.ogg" : "kiroshi_off.ogg") }
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

        // Frosted glass (blur from the qs-launcher layer rule);
        // click anywhere outside the card to close
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 6/255, 14/255, 0.35)
            // Gone while a palette is edited: the desktop shows the preview
            opacity: root.shown && root.paletteDraft === null ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            Image {
                anchors.fill: parent
                source: "file:///home/kalashnikxv/.config/wlogout/grain.png"
                fillMode: Image.Tile
                opacity: 0.07
            }

            ScanlineOverlay {
                opacity: 0
            }

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
                // The palette editor takes its place, as a window of its own
                visible: root.paletteDraft === null
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
                        font.family: Theme.font
                    }

                    // Title + search
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: root.title
                            color: Theme.cyan
                            font.bold: true
                            font.pixelSize: 20
                            font.family: Theme.font
                        }

                        TextInput {
                            id: search
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            verticalAlignment: TextInput.AlignVCenter
                            color: "#e6f7ff"
                            font.pixelSize: 14
                            font.family: Theme.font
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
                                color: CP.alpha(Theme.cyan, 0.5)
                                font: search.font
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Separator
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: CP.alpha(Theme.cyan, 0.4)
                    }

                    // ---------- Results ----------
                    BindEditor {
                        Layout.fillWidth: true
                        visible: root.bindDraft !== null
                        draft: root.bindDraft
                        onClosed: {
                            root.bindDraft = null;
                            LauncherMenus.reloadUserBinds();
                            search.forceActiveFocus();
                        }
                    }

                    ListView {
                        id: list
                        visible: root.bindDraft === null && root.paletteDraft === null

                        onCurrentIndexChanged: {
                            root.armedId = "";
                            if (root.shown)
                                Sounds.beep();
                        }

                        // The highlight range depends on the height: created at height 0, the list
                        // would stay scrolled by half a row
                        onHeightChanged: positionViewAtIndex(currentIndex, ListView.Center)

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
                        visible: list.count === 0 && root.bindDraft === null
                        text: "// NO MATCH"
                        color: CP.alpha(Theme.cyan, 0.5)
                        font.pixelSize: 12
                        font.family: Theme.font
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 8
                        Layout.bottomMargin: 8
                    }

                    // Key hints
                    Text {
                        text: "[ TYPE ] SEARCH   [ ↑↓ ] NAVIGATE   [ ENTER ] SELECT   [ ESC ] BACK"
                        color: CP.redDark
                        font.pixelSize: 9
                        font.family: Theme.font
                    }
                }
            }
        }

        // ---------- Palette editor ----------
        // Floats over the desktop on the phone view's veil; dragged by its header, fixed size
        Item {
            id: paletteBox
            // Also gone with the menu: the content of a hidden window stays `visible`, and the
            // editor drops its preview only when it stops being visible
            visible: root.paletteDraft !== null && root.shown
            width: 488
            height: editor.y + editor.implicitHeight + 30

            Connections {
                target: root
                // Every edit starts where the menu was
                function onPaletteDraftChanged() {
                    if (root.paletteDraft) {
                        paletteBox.x = 46;
                        paletteBox.y = win.height * 0.18 - 14;
                    }
                }
            }

            // Clicks inside don't reach the backdrop, which would close the menu
            MouseArea {
                anchors.fill: parent
            }

            // The phone's blood-dark veil, fading out on every side
            Rectangle {
                anchors.fill: parent
                anchors.margins: 14
                color: Qt.rgba(0.07, 0, 0.012, 0.86)
                layer.enabled: true
                layer.effect: MultiEffect {
                    autoPaddingEnabled: true
                    blurEnabled: true
                    blur: 1
                    blurMax: 48
                }
            }

            Item {
                id: header
                x: 30
                y: 26
                width: parent.width - 60
                height: 30

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.paletteDraft && !root.paletteDraft.isNew ? "EDIT " + root.paletteDraft.name.toUpperCase() : "NEW PALETTE"
                    color: Theme.cyan
                    font.bold: true
                    font.pixelSize: 20
                    font.family: Theme.font
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf047  DRAG"
                    color: CP.alpha(Theme.cyan, 0.5)
                    font.pixelSize: 10
                    font.family: "JetBrainsMono Nerd Font"
                }
                Rectangle {
                    anchors.top: parent.bottom
                    width: parent.width
                    height: 1
                    color: CP.alpha(Theme.cyan, 0.4)
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target: paletteBox
                    drag.threshold: 0
                    // Kept whole on screen
                    drag.minimumX: 0
                    drag.maximumX: win.width - paletteBox.width
                    drag.minimumY: 0
                    drag.maximumY: win.height - paletteBox.height
                }
            }

            PaletteEditor {
                id: editor
                x: 30
                y: header.y + header.height + 12
                width: parent.width - 60
                draft: root.paletteDraft
                onClosed: {
                    root.paletteDraft = null;
                    search.forceActiveFocus();
                }
            }
        }
    }
}
