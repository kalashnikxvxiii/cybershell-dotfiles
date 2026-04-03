// Interactions.qml - Centralized mouse tracking per tutti i pannelli drawer
// E' IL PARENT di Panels: riceve hover events anche quando il mouse e' sui
// pannelli figli (gli hover non richiedono "accettazione" come i click,
// quindi si propagano sempre verso il parent)
//
// Per ogni nuovo pannello: aggiungi la logica in onPositionChanged e
// onContainsMouseChanged usando gli helper generici qui sotto

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

    // Trigger stretto per panel top: solo bordo superiore schermo
    readonly property int topTriggerPx: 2
    // Trigger strip laterali (uguale a mask triggerPx)
    readonly property int sideTriggerPx: 2

    // Helper geometrici

    // Verifica X: panel.x e' relativo a Panels (stesso origine orizzontale della finestra)
    function withinPanelX(panel) {
        const lyricsExt = panel.lyricsDrawerExtent ?? 0
        const mainLeft = panel.x
        const mainRight = panel.x + (panel.panelWidth ?? panel.childrenRect.width)
        
        // Zona pannello principale (nessuna restrizione Y extra)
        if (mouseX >= mainLeft - 4 && mouseX <= mainRight + 4)
            return true
        
        // Zona lyricsDrawer: verifica anche che mouseY sia dentro i bordi del drawer
        if (lyricsExt > 0 && mouseX >= mainLeft - lyricsExt - 4 && mouseX < mainLeft + 4) {
            const lyTop = bar.barHeight + panel.y + (panel.lyricsDrawerRelY ?? 0) - 4
            const lyBottom = lyTop + (panel.lyricsDrawerRelH ?? 0) + 8
            return mouseY >= lyTop && mouseY <= lyBottom
        }
        return false
    }

    // Verifica Y: panel.y e' relativo a Panels container (che parte a y=barHeight)
    function withinPanelY(panel) {
        const absTop = bar.barHeight + panel.y
        return mouseY >= absTop -4
                && mouseY <= absTop + panel.height + 4
    }

    // Panel top (dashboard): trigger 2 px quando chiuso, area completa quando aperto
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

    // Mouse tracking

    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton    // non-blocking: i click passano sempre ai figli

    // Mouse esce dalla finestra -> chiudi tutti i pannelli hover-based
    onContainsMouseChanged: {
        if (!containsMouse) {
            drawerState.dashboardOpen = false
            // In futuro: aggiungi qui gli altri pannelli hover-based
            // es: drawerState.launcherOpen = false
        } else {
            // Controlla subito l'entrata, senza aspettare il primo onPositionChanged
            drawerState.dashboardOpen = inTopPanel(panels.dashboard)
        }
    }

    // Tracking continuo: aggiorna visibilita' in base alla posizione
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
        // In futuro: una riga per ogni nuovo pannello hover-based
        // es: drawerState.;auncherOpen = inBottomPanel(panels.launcher)
        //     drawerState.sidebarOpen  = inRightPanel(panels.sidebar)
    }
}