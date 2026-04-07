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
    readonly property int sideTriggerPx: 2

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

    // Mouse leaves the window -> close all hover-based panels
    onContainsMouseChanged: {
        if (!containsMouse) {
            drawerState.dashboardOpen = false
            // Future: add other hover-based panels here
            // e.g.: drawerState.launcherOpen = false
        } else {
            // Check entry immediately, don't wait for the first onPositionChanged
            drawerState.dashboardOpen = inTopPanel(panels.dashboard)
        }
    }

    // Continuous tracking: update visibility based on mouse position
    onPositionChanged: {
        if (drawerState.dashboardOpen) {
            // const _p = panels.dashboard
            // console.log("[Interactions]",
            //     "mouseX:", mouseX,
            //     "panel.x:", _p.x,
            //     "panelWidth:", _p.panelWidth,
            //     "lyricsExt:", _p.lyricsDrawerExtent,
            //     "left:", _p.x - (_p.lyricsDrawerExtent),
            //     "right:", _p.x + (_p.panelWidth ?? 0),
            //     "withinX:", withinPanelX(_p),
            //     "inTop:", inTopPanel(_p))
        }
        drawerState.dashboardOpen = inTopPanel(panels.dashboard)
        // Future: one line per new hover-based panel
        // e.g.: drawerState.launcherOpen = inBottomPanel(panels.launcher)
        //       drawerState.sidebarOpen  = inRightPanel(panels.sidebar)
    }
}