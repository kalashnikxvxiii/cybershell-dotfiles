// Interactions.qml - Centralized mouse tracking for all drawer panels
// This IS THE PARENT of Panels: it receives hover events even when the mouse
// is over child panels (hovers don't require "acceptance" like clicks,
// so they always propagate up to the parent)
//
// For each new panel: add logic in onPositionChanged and
// onContainsMouseChanged using the generic helpers below

import QtQuick
import "."
import "../../common"

MouseArea {
    id: root

    required property DrawerState drawerState
    required property Panels      panels
    required property Item        bar
    required property int         windowWidth
    required property int         windowHeight

    // Tight trigger for the top panel: screen top edge only
    readonly property int topTriggerPx: 2
    // Side trigger strips (same as mask triggerPx)
    // readonly property int sideTriggerPx: 2

    // The dock item is always full width; what takes the pointer is inputX +
    // inputWidth. Reading those here is what gives the hover its hysteresis:
    // closed it needs the border hairline, open the whole blob area holds it
    function inDock(dock) {
        const absTop = bar.barHeight + dock.y
        if (mouseY < absTop - 4 || mouseY > absTop + dock.height + 4) return false
        const left = dock.x + dock.inputX
        return mouseX >= left - 4 && mouseX <= left + dock.inputWidth + 4
    }

    // Cursor position inside the dock, for the magnification wave.
    // -1 when the cursor is elsewhere, so the dock can flatten out
    readonly property real dockCursorY:
        containsMouse ? mouseY - bar.barHeight - panels.dock.y : -1

    // Geometry helpers
    // Check X: panel.x is relative to Panels (same horizontal origin as the window)
    function withinPanelX(panel) {
        const lyricsExt = panel.lyricsDrawerExtent ?? 0
        const mainLeft = panel.x
        const mainRight = panel.x + (panel.panelWidth ?? panel.childrenRect.width)
        
        // Main panel zone (no extra Y restriction)
        if (mouseX >= mainLeft - 4 && mouseX <= mainRight + 4)
            return true
        
        // Lyrics drawer zone: also verify mouseY is within the drawer bounds
        if (lyricsExt > 0 && mouseX >= mainLeft - lyricsExt - 4 && mouseX < mainLeft + 4) {
            const lyTop = bar.barHeight + panel.y + (panel.lyricsDrawerRelY ?? 0) - 4
            const lyBottom = lyTop + (panel.lyricsDrawerRelH ?? 0) + 8
            return mouseY >= lyTop && mouseY <= lyBottom
        }
        return false
    }

    // Check Y: panel.y is relative to the Panels container (starts at y=barHeight)
    function withinPanelY(panel) {
        const absTop = bar.barHeight + panel.y
        return mouseY >= absTop -4
                && mouseY <= absTop + panel.height + 4
    }

    // Top panel (dashboard): 2px trigger when closed, full area when open
    function inTopPanel(panel) {
        const panelOpen = panel.height > 0
        const threshold = panelOpen
            ? bar.barHeight + panel.y + panel.height
            : topTriggerPx
        const xCheck = panelOpen
                        ? withinPanelX(panel)
                        : (mouseX >= (windowWidth / 2 - 120) && mouseX <= (windowWidth / 2 + 120))
        return mouseY <= threshold && xCheck
    }

    // Mouse tracking logic

    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton    // non-blocking: clicks always pass through to children

    onContainsMouseChanged: {
        if (!containsMouse) {
            drawerState.dashboardOpen = false
            drawerState.dockOpen = false
            // The chat is NOT closed here, on purpose: see below
        } else {
            drawerState.dashboardOpen = inTopPanel(panels.dashboard)
            drawerState.dockOpen = inDock(panels.dock)
        }
    }

    // Continuous tracking: update visibility based on mouse position
    onPositionChanged: {
        drawerState.dashboardOpen = inTopPanel(panels.dashboard)
        drawerState.dockOpen = inDock(panels.dock)
    }
}