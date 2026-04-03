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

    // unico PanelWindow fullscreen per schermo
    PanelWindow {
        id: win

        screen: root.screen
        WlrLayershell.namespace: "drawers"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: drawerState.dashboardOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        color: "transparent"
        aboveWindows: true

        readonly property int barHeight: 24

        // Mask: strip top (barra, sempre attiva) + strip sinistra/destra/bottom
        // Il rettangolo XOR parte da y=barHeight (SOTTO la barra)
        mask: Region {
            x: 0
            y: win.barHeight
            width: win.width
            height: win.height - win.barHeight
            intersection: Intersection.Xor
            regions: maskRegions.instances
        }

        // Regions dinamiche: una per ogni pannello aperto
        // y assoluta = barHeight + panel.y (panel.y e' relativo a Panels container)
        Variants {
            id: maskRegions
            model: panels.children

            Region {
                required property Item modelData
                readonly property real leftExt: modelData.lyricsDrawerExtent ?? 0

                x: modelData.x - leftExt
                y: win.barHeight + modelData.y
                width: modelData.width + leftExt
                height: modelData.inputHeight ?? 0
                intersection: Intersection.Subtract
            }
        }

        // Intersections e' parent di Panels: riceve hover su tutto lo schermo
        // panels id e' accessibile da Variants sopra grazie alla scope QML del file
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