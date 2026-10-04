import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import "../../common/Colors.js" as CP
import "."
import "../../common"
import "../bar"

Scope {
    id: root
    required property var screen
    required property DrawerState drawerState

    // Single fullscreen PanelWindow per screen
    PanelWindow {
        id: win

        screen: root.screen
        WlrLayershell.namespace: "drawers"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: (drawerState.dashboardOpen
                                    || AudioControlState.popupOpen
                                    || (AiState.open && AiState.screenName === root.screen.name)) 
                                    ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        color: "transparent"
        aboveWindows: true

        readonly property int barHeight: 24

        // Mask: top strip (bar, always active) + left/right/bottom strips
        // The XOR rectangle starts at y=barHeight (BELOW the bar)
        mask: Region {
            x: 0
            y: win.barHeight
            width: win.width
            height: win.height - win.barHeight
            intersection: Intersection.Xor
            regions: maskRegions.instances
        }

        // Dynamic regions: one per open panel
        // absolute y = barHeight + panel.y (panel.y is relative to Panels container)
        Variants {
            id: maskRegions
            model: panels.children

            Region {
                required property Item modelData
                readonly property real leftExt: modelData.lyricsDrawerExtent ?? 0

                // Each child decides how much of itself takes the pointer. The
                // fallbacks keep the dashboard behaving exactly as before: it gates on
                // inputHeight and lets its width through
                readonly property real iw: modelData.inputWidth ?? modelData.width
                readonly property real ih: modelData.inputHeight ?? modelData.height
                // Lets a child expose a strip of itself instead of its left edge:
                // the dock is always full width, but closed it only takes the
                // pointer on the border hairline
                readonly property real ix: modelData.inputX ?? 0

                x: modelData.x - leftExt + ix
                y: win.barHeight + modelData.y
                width: iw + leftExt
                height: ih
                intersection: Intersection.Subtract
            }
        }

        // Interactions is the parent of Panels: receives hover across the whole screen
        // panels id is accessible from the Variants above thanks to QML file scope
        Interactions {
            id: interactions
            drawerState: root.drawerState
            panels: panels
            bar: bar
            windowWidth: win.width
            windowHeight: win.height

            Panels {
                id: panels
                drawerState: root.drawerState
                bar: bar
                // the wave follows the same MouseArea the drawers already use
                dock.cursorY: interactions.dockCursorY
            }

            Bar {
                id: bar
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: win.barHeight
                screen: win.screen
                parentWindow: win
            }
        }
    }
}