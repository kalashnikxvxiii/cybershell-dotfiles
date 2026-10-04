import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../common"
import "../../common/effects"


Scope {
    id: root

    required property var screen

    // Fallback: se il query non ha ancora risposto (focusedScreen == ""), mostro sul primo
    readonly property bool isFocused:
        LogoutState.focusedScreen === ""
        ? true   // fallback safe: mostra su tutti finché non abbiamo l'info
        : screen.name === LogoutState.focusedScreen

    PanelWindow {
        id: panel
        screen: root.screen
        visible: LogoutState.visible

        color: "transparent"

        WlrLayershell.layer:         WlrLayer.Overlay
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: root.isFocused ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace:     "qs-logout"

        anchors { top: true; bottom: true; left: true; right: true }

        // -- Layer 1: base tint (leggera, per lasciar respirare il blur) -------
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 6/255, 14/255, 0.35)
        }

        // -- Layer 2: grain ----------------------
        Image {
            anchors.fill: parent
            source:   "file:///home/kalashnikxv/.config/wlogout/grain.png"
            fillMode: Image.Tile
            opacity:  0.15
        }

        // -- Layer 3: scanline ------------------------
        ScanlineOverlay {
            anchors.fill: parent
            opacity: 0.35
        }

        // -- Layer 4: Grid - solo su focused screen ---------------
        Grid {
            anchors.centerIn: parent
            visible:       root.isFocused
            columns:       3
            rowSpacing:    28
            columnSpacing: 28

            Repeater {
                model: LogoutState.actions
                delegate: LogoutActionTile {
                    required property var modelData
                    required property int index

                    action:   modelData
                    selected: LogoutState.activeIndex === index

                    onTriggered: LogoutState.invokeIndex(index)
                }
            }
        }

        // -- Layer 5: dim quando confirming (solo focused) -----------
        Rectangle {
            anchors.fill: parent
            visible: root.isFocused && LogoutState.pendingAction >= 0
            color: Qt.rgba(0, 0, 0, 0.45)
        }

        // -- Layer 6: confirm dialog (solo focused) ---------------
        LogoutConfirmDialog {
            anchors.centerIn: parent
            visible: root.isFocused && LogoutState.pendingAction >= 0
            action:  (LogoutState.pendingAction >= 0)
                    ? LogoutState.actions[LogoutState.pendingAction]
                    : ({ label: "" })
            onConfirmed: LogoutState.confirmPending()
            onCancelled: LogoutState.cancelPending()
        }

        // -- Layer 7: mini dashboard (solo NON-focused) ----------
        LogoutMiniDashboard {
            anchors.centerIn: parent
            visible: !root.isFocused
        }

        // -- Keyboard handler — solo sul focused screen ---------
        Item {
            anchors.fill: parent
            focus: LogoutState.visible && root.isFocused

            Keys.onEscapePressed: {
                if (LogoutState.pendingAction >= 0) LogoutState.cancelPending()
                else                                LogoutState.close()
            }

            Keys.onLeftPressed:  if (LogoutState.pendingAction < 0) LogoutState.activeIndex = (LogoutState.activeIndex + 5) % 6
            Keys.onRightPressed: if (LogoutState.pendingAction < 0) LogoutState.activeIndex = (LogoutState.activeIndex + 1) % 6
            Keys.onUpPressed:    if (LogoutState.pendingAction < 0) LogoutState.activeIndex = (LogoutState.activeIndex + 3) % 6
            Keys.onDownPressed:  if (LogoutState.pendingAction < 0) LogoutState.activeIndex = (LogoutState.activeIndex + 3) % 6

            Keys.onReturnPressed: {
                if (LogoutState.pendingAction >= 0) LogoutState.confirmPending()
                else                                LogoutState.invokeIndex(LogoutState.activeIndex)
            }
            Keys.onEnterPressed: {
                if (LogoutState.pendingAction >= 0) LogoutState.confirmPending()
                else                                LogoutState.invokeIndex(LogoutState.activeIndex)
            }

            Keys.onPressed: (event) => {
                var key = event.text.toUpperCase()

                if (LogoutState.pendingAction >= 0) {
                    if (key === "Y") { LogoutState.confirmPending(); event.accepted = true; return }
                    if (key === "N") { LogoutState.cancelPending();  event.accepted = true; return }
                    event.accepted = true
                    return
                }

                for (var i = 0; i < LogoutState.actions.length; i++) {
                    if (LogoutState.actions[i].shortcut === key) {
                        LogoutState.invokeIndex(i)
                        event.accepted = true
                        return
                    }
                }
            }
        }
    }
}
