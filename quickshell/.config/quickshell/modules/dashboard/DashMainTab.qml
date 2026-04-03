// Struttura:
// 6 colonne, 2 righe
//   Row 0: [App Launcher: 0-1] [User: 2-4] [Media: 5, rowSpan 2]
//   Row 1: [Clock: 0] [Calendar: 1-3] [Resources: 4] [Media span]

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../common/Colors.js" as CP
import "."
import "../../common"
import "../../common/widgets"

Item {
    id: root

    required property PersistentProperties dashState

    // Dimensioni celle:
    readonly property int appLauncherCellWidth: 180
    readonly property int clockCellWidth: clock.implicitWidth
    readonly property int resourcesCellWidth: 92
    readonly property int mediaCellWidth: 250
    readonly property int userCellWidth: 360
    readonly property int topRowHeight: 172
    // bottomRowHeight e' guidato da calendar.implicitHeight

    implicitWidth: 830
    // implicitHeight dinamico: segue l'altezza reale della griglia (dipende da calendar.implicitHeight)
    implicitHeight: grid.implicitHeight + grid.anchors.margins * 2

    GridLayout {
        id: grid
        // Solo top/left/right ancorati — la griglia determina liberamente la propria altezza
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 6
        rowSpacing: 6
        columnSpacing: 6

        // AppLauncher (row 0, col 0-1, colSpan 2)
        ModuleCard {
            Layout.row: 0; Layout.column: 0; Layout.columnSpan: 2
            Layout.preferredWidth: root.appLauncherCellWidth
            Layout.preferredHeight: root.topRowHeight
            cutTopLeft: 24

            DashAppLauncher { anchors.fill: parent }
        }

        // User (row 0, col 2-4, colSpan 3)
        ModuleCard {
            Layout.row: 0; Layout.column: 2; Layout.columnSpan: 3
            Layout.fillWidth: true
            Layout.preferredHeight: root.topRowHeight

            DashUser { anchors.fill: parent }
        }

        // Media (row 0-1, col 5, rowSpan 2)
        ModuleCard {
            Layout.row: 0; Layout.column: 5; Layout.rowSpan: 2
            Layout.preferredWidth: root.mediaCellWidth
            Layout.fillHeight: true
            cutBottomLeft: 24; cutTopRight: 24

            DashMediaMini { anchors.fill: parent }
        }

        // Clock (row 1, col 0)
        ModuleCard {
            Layout.row: 1; Layout.column: 0
            Layout.preferredWidth: root.clockCellWidth
            Layout.fillHeight: true
            cutBottomLeft: 24

            DashClock { id: clock; anchors.fill: parent }
        }

        // Calendar (row 1, col 1-3, colSpan 3)
        ModuleCard {
            Layout.row: 1; Layout.column: 1; Layout.columnSpan: 3
            Layout.fillWidth: true
            Layout.preferredHeight: calendar.implicitHeight + 25
            cutBottomLeft: 24

            DashCalendar { id: calendar; anchors.fill: parent; state: root.dashState }
        }

        // Resources (row 1, col 4)
        ModuleCard {
            Layout.row: 1; Layout.column: 4
            Layout.preferredWidth: root.resourcesCellWidth
            Layout.fillHeight: true
            cutBottomLeft: 24

            DashResources { anchors.centerIn: parent }
        }
    }
}
