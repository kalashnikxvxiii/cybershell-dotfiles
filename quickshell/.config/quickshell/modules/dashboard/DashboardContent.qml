// Contenuto della dashboard con 4 tab scorrevoli
// Struttura adattata da Caelestia modules/dashboard/Content.qml:
//   DashTabs (indicatore animato + scroll wheel)
//   Flickable con RowLayout di 4 Pane (Loader con lazy-loading)

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../common/Colors.js" as CP
import "."
import "../../common"

Item {
    id: root

    implicitWidth: 8 + 4 + (view.implicitWidth > 0 ? view.implicitWidth : 830)
    implicitHeight: 6 + tabs.implicitHeight + 6 + (view.implicitHeight > 0 ? view.implicitHeight : 340) + 6

    // Nota: view.implicitWidth/Height leggono da currentItem.Layout.preferredWidth/Height,
    // che è sempre valorizzato (naturalWidth/Height) indipendentemente dal caricamento del Pane.

    required property DrawerState drawerState
    required property PersistentProperties dashState

    // Tab bar
    DashTabs {
        id: tabs

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 6
        anchors.leftMargin: 8
        anchors.rightMargin: 8

        dashState: root.dashState
    }

    // Separatore già incluso in DashTabs, aggiunge solo clip
    Item {
        id: viewWrapper

        anchors.top: tabs.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 6
        clip: true

        Flickable {
            id: view

            readonly property int currentIndex: root.dashState.currentTab
            readonly property Item currentItem: row.children[currentIndex]

            anchors.fill: parent
            flickableDirection: Flickable.HorizontalFlick
            interactive: !row.children[2]?.item?.graphInteraction

            implicitWidth: currentItem ? currentItem.Layout.preferredWidth : 830
            implicitHeight: currentItem ? currentItem.Layout.preferredHeight : 340
            contentWidth: row.implicitWidth
            contentHeight: row.implicitHeight
            contentX: currentItem ? currentItem.x : 0

            // Fine drag: snap soglia 1/10 o ripristina binding
            onDragEnded: {
                if (!currentItem) return
                const offset = contentX - currentItem.x
                if (offset > currentItem.Layout.preferredWidth / 5)
                    root.dashState.currentTab = Math.min(root.dashState.currentTab + 1, 2)
                else if (offset < -(currentItem.Layout.preferredWidth / 5))
                    root.dashState.currentTab = Math.max(root.dashState.currentTab - 1, 0)
                else
                    contentX = Qt.binding(() => view.currentItem ? view.currentItem.x : 0)
            }

            Behavior on contentX {
                Anim {}
            }

            // 4 pane affiancate
            RowLayout {
                id: row
                spacing: 0

                // Ogni Pane = Loader con lazy-loading Caelestia-style
                Pane { id: pane0; index: 0; naturalWidth: 830; naturalHeight: 410; sourceComponent: DashMainTab   { dashState: root.dashState } }
                Pane {            index: 1; naturalWidth: 400; naturalHeight: 240; sourceComponent: DashMediaTab  {  } }
                Pane {            index: 2; naturalWidth: 830; naturalHeight: 520; sourceComponent: DashPerfTab   { tabActive: view.currentIndex === 2 && root.drawerState.dashboardOpen } }
            }
        }
    }

    // Pane: Loader con lazy-loading — carica sempre il tab corrente +
    // qualsiasi pane visibile durante lo scorrimento
    component Pane: Loader {
        id: pane

        required property int index
        required property real naturalWidth
        required property real naturalHeight

        // Prima del caricamento usa naturalWidth/Height come placeholder.
        // Dopo il caricamento usa le dimensioni reali dell'item (supporta implicitHeight dinamico).
        // (Loader ha implicitWidth/Height read-only, si usa Layout.preferred* per il sizing)
        Layout.preferredWidth:  item ? item.implicitWidth  : naturalWidth
        Layout.preferredHeight: item ? item.implicitHeight : naturalHeight
        Layout.alignment: Qt.AlignTop

        Component.onCompleted: active = Qt.binding(() => {
            if (pane.index === 0) return true
            // Sempre carico se è il tab corrente
            if (pane.index === view.currentIndex) return true
            // Carica se è parzialmente visibile (durante swipe)
            const vx  = Math.floor(view.visibleArea.xPosition * view.contentWidth)
            const vex = Math.floor(vx + view.visibleArea.widthRatio * view.contentWidth)
            return vex > x && vx < x + naturalWidth
        })
    }

    Behavior on implicitWidth { Anim { duration: 260 }}
    Behavior on implicitHeight { Anim { duration: 260 }}
}
