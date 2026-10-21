// Dashboard content with scrollable tabs
// Structure adapted from Caelestia modules/dashboard/Content.qml:
//   DashTabs (animated indicator + scroll wheel)
//   Flickable with RowLayout of tab Panes (Loader with lazy-loading)

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

    // Note: view.implicitWidth/Height read from currentItem.Layout.preferredWidth/Height,
    // which is always populated (naturalWidth/Height) regardless of whether the Pane is loaded.

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

    // Separator already included in DashTabs, just adds clip
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

            // End drag: snap at 1/5 threshold or restore binding
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

            // Side-by-side tab panes
            RowLayout {
                id: row
                spacing: 0

                // Each Pane = Loader with Caelestia-style lazy-loading
                Pane { id: pane0; index: 0; naturalWidth: 830; naturalHeight: 410; sourceComponent: DashMainTab   { dashState: root.dashState } }
                Pane {            index: 1; naturalWidth: 400; naturalHeight: 240; sourceComponent: DashMediaTab  {  } }
                Pane {            index: 2; naturalWidth: 830; naturalHeight: 520; sourceComponent: DashPerfTab   { tabActive: view.currentIndex === 2 && root.drawerState.dashboardOpen } }
            }
        }
    }

    // Pane: Loader with lazy-loading — always loads the current tab +
    // any pane visible during swipe
    component Pane: Loader {
        id: pane

        required property int index
        required property real naturalWidth
        required property real naturalHeight

        // Before loading, uses naturalWidth/Height as placeholder.
        // After loading, uses the item's real dimensions (supports dynamic implicitHeight).
        // (Loader's implicitWidth/Height are read-only, so Layout.preferred* is used for sizing)
        Layout.preferredWidth:  item ? item.implicitWidth  : naturalWidth
        Layout.preferredHeight: item ? item.implicitHeight : naturalHeight
        Layout.alignment: Qt.AlignTop

        // Any part of the pane inside the viewport, mid-swipe included
        readonly property bool inView: {
            if (pane.index === view.currentIndex) return true
            const vx  = Math.floor(view.visibleArea.xPosition * view.contentWidth)
            const vex = Math.floor(vx + view.visibleArea.widthRatio * view.contentWidth)
            return vex > x && vx < x + naturalWidth
        }

        Component.onCompleted: active = Qt.binding(() => {
            if (pane.index === 0) return true
            // Always loaded if it's the current tab
            if (pane.index === view.currentIndex) return true
            // Load if partially visible (during swipe)
            return pane.inView
        })

        // A tab stays loaded once it has been shown, but while it is out of
        // sight it is hidden: the Flickable only clips it, so its animations,
        // GIFs and pollers (all gated on `visible`) would keep going and keep
        // the whole window rendering. The Loader itself stays visible, because
        // the RowLayout skips invisible children and the tabs would shift.
        Binding {
            target: pane.item
            property: "visible"
            value: pane.inView
            when: pane.item !== null
        }
    }

    Behavior on implicitWidth { Anim { duration: 260 }}
    Behavior on implicitHeight { Anim { duration: 260 }}
}
