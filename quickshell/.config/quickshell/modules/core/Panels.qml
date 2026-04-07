// Panels.qml - Container for all drawer panels
// Each panel is exposed as an alias: Interactions.qml accesses them for
// hover logic, the mask Variants reads them via panels.children
// To add a panel: add it here as a child Item + alias

import QtQuick
import "."
import "../../common"
import "../dashboard"

Item {
    id: root

    required property DrawerState drawerState
    required property Item bar

    readonly property alias dashboard: dashboard

    anchors.fill: parent
    anchors.topMargin: bar.barHeight    // panels start BELOW the bar

    DashboardPanel {
        id: dashboard
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        drawerState: root.drawerState
    }
}