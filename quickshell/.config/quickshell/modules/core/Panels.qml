// Panels.qml - Container for all drawer panels
// Each panel is exposed as an alias: Interactions.qml accesses them for
// hover logic, the mask Variants reads them via panels.children
// To add a panel: add it here as a child Item + alias

import QtQuick
import "."
import "../../common"
import "../dashboard"
import "../ai"
import "../dock"
import "../../common/Colors.js" as CP

Item {
    id: root

    required property DrawerState drawerState
    required property Item bar

    readonly property alias dashboard: dashboard
    readonly property alias dock: dock
    readonly property alias aiPanel: aiPanel

    // DP-1 puts the dock on the right, HDMI-A-1 on the left
    readonly property bool dockRight: bar.screen.name !== "HDMI-A-1"

    anchors.fill: parent
    anchors.topMargin: bar.barHeight    // panels start BELOW the bar

    DashboardPanel {
        id: dashboard
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        drawerState: root.drawerState
    }

    Dock {
        id: dock
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: root.dockRight ? parent.right : undefined
        anchors.left:  root.dockRight ? undefined : parent.left
        rightSide: root.dockRight
        screenName: root.bar.screen.name
        drawerState: root.drawerState
        pinnedOpen: AiState.open && AiState.screenName === root.bar.screen.name
        cursorY: root.parent.dockCursorY      // Interactions is Panels' parent
    }

    // Dock name plate. Outside the Dock because the Dock clips itself to unroll,
    // and the plate has to sit beyond its edge.
    //
    // inputWidth: 0 is mandatory. Every child of Panels becomes a mask region in
    // Drawers.qml, so any decoration added here would silently start eating
    // pointer events across its whole rectangle
    Item {
        id: namePlate
        readonly property real inputWidth: 0
        readonly property real inputHeight: 0

        // One letter per line. Written horizontally, as long label ran over the
        // wave and over the icon sitting inside it; stacked, its width is one
        // character whatever the label says
        readonly property string stacked: {
            const s = dock.focusedLabel
            let out = ""
            for (let i = 0; i < s.length; i++) {
                if (s[i] === " ") continue
                out += (out.length ? "\n" : "") + s[i]
            }
            return out
        }

        implicitWidth: plate.implicitWidth
        implicitHeight: plate.implicitHeight
        visible: dock.focusedIndex >= 0
        opacity: visible ? 1 : 0
        Behavior on opacity { Anim { duration: 120 } }

        // Flush with the screen border the dock grows out of: the plate sits
        // between the icon and the edge, on whichever side the dock is
        x: root.dockRight
            ? dock.x + dock.width - width - 1
            : dock.x
        y: dock.y + dock.apexY - height / 2

        Text {
            id: plate
            text: namePlate.stacked
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 0.95
            font.family: "Oxanium"
            font.pixelSize: 9
            font.letterSpacing: 0
            font.bold: true
            color: CP.alpha(dock.focusedAccent, 0.85)
        }
    }

    AiPanel {
        id: aiPanel
        screenName: root.bar.screen.name
        rightSide: root.dockRight
        // Docked, it opens sideways from the dock, centred on the AI icon.
        // AiPanel places itself from these: detached, it ignores them
        dockedX: root.dockRight ? dock.x - aiPanel.panelWidth - 8 : dock.x + dock.width + 8
        dockedY: dock.y + dock.aiSlotCenterY - aiPanel.panelHeight / 2
    }
}