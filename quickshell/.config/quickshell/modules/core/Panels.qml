// Panels.qml - Container di tutti i pannelli drawer
// Ogni pannello e' esposto come alias: Intersections.qml vi accede per la
// logica hover, la mask Variants li legge tramite panels.children
// Per aggiungere un pannello: aggiungilo qui come Item figlio + alias

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
    anchors.topMargin: bar.barHeight    // pannelli inziano SOTTO la barra

    DashboardPanel {
        id: dashboard
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        drawerState: root.drawerState
    }
}