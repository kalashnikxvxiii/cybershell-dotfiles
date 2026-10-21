// MediaPanel.qml — standalone RADIOPORT overlay, as in AndreaNec/Cyberpunk-quickshell
// (mediaplayer/MediaPanel.qml). Hosts the same component as the dashboard's
// media tab. Opened from the menu ("Media") or:
//   qs ipc call mediapanel toggle | open | close
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../common"
import "../../common/effects"
import "../dashboard"

Scope {
    id: root

    required property var screen

    readonly property bool shown: LauncherState.mediaOpen && LauncherState.mediaScreen === root.screen.name

    PanelWindow {
        screen: root.screen
        visible: root.shown || fx.visible
        color: "transparent"
        anchors {
            top: true
            left: true
            bottom: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "qs-mediapanel"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent
            color: "#cc000000"
            opacity: root.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }

            MouseArea {
                anchors.fill: parent
                onClicked: LauncherState.closeMedia()
            }
        }

        GlitchReveal {
            id: fx
            anchors.centerIn: parent
            width: radioport.implicitWidth
            height: radioport.implicitHeight
            shown: root.shown

            DashMediaTab {
                id: radioport
                anchors.fill: parent
                // A/D/Enter come from the tab itself; Esc closes the overlay
                Keys.onEscapePressed: LauncherState.closeMedia()

                MouseArea {
                    anchors.fill: parent
                    z: -1
                }   // swallow clicks inside the card
            }
        }
    }
}
