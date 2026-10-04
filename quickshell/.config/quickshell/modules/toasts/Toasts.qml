// Toasts.qml -- the stack. One per screen, lives inside ToastOverlay.
//
// Stacking is computed by hand: every card sums the heights of the ones below it
// into its own bottomMargin, with a Behavior on top, so when one leaves the rest
// slide down. Closed and hidden cards contribute nothing.
//
// Past maxToasts the cards are built but kept hidden rather than dropped, so they
// scale in as the ones in front of them go away.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../common"

Item {
    id: root

    // True while a fullscreen window owns this screen -- set by ToastOverlay.
    property bool fullscreen: false

    readonly property int spacing: 8
    // Touched by the model to force the bottomMargin sums to recompute: they read
    // sibling heights, which QML cannot track as a dependency.
    property bool flag

    function shouldShow(toast): bool {
        if (!root.fullscreen)
            return true;
        if (Toaster.fullscreenPolicy === Toaster.All)
            return true;
        if (Toaster.fullscreenPolicy === Toaster.Important)
            return toast.type === Toast.Warning || toast.type === Toast.Error;
        return false;
    }

    implicitHeight: {
        let h = -spacing;
        for (let i = 0; i < repeater.count; i++) {
            const item = repeater.itemAt(i);
            if (item && !item.modelData.closed && !item.previewHidden)
                h += item.implicitHeight + spacing;
        }
        return Math.max(0, h);
    }

    Repeater {
        id: repeater

        model: ScriptModel {
            id: toastModel
            values: {
                const shown = [];
                let live = 0;
                for (const toast of Toaster.toasts) {
                    if (!root.shouldShow(toast))
                        continue;
                    shown.push(toast);
                    if (!toast.closed) {
                        live++;
                        if (live > Toaster.maxToasts)
                            break;
                    }
                }
                return shown;
            }
            onValuesChanged: root.flagChanged()
        }

        ToastWrapper {}
    }

    component ToastWrapper: MouseArea {
        id: wrapper

        required property int index
        required property Toast modelData

        // Only the first maxToasts *live* cards are on screen; a closed card
        // still on its way out does not count against the budget. Counted on
        // the filtered model, not on Toaster.toasts: with the fullscreen policy
        // dropping cards the two lists no longer share indices.
        readonly property bool previewHidden: {
            const shown = toastModel.values;
            let closedAbove = 0;
            for (let i = 0; i < index; i++)
                if (shown[i] && shown[i].closed)
                    closedAbove++;
            return index >= Toaster.maxToasts + closedAbove;
        }

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: {
            root.flag; // force update: sibling heights are not a tracked dependency
            let y = 0;
            for (let i = 0; i < index; i++) {
                const item = repeater.itemAt(i);
                if (item && !item.modelData.closed && !item.previewHidden)
                    y += item.implicitHeight + root.spacing;
            }
            return y;
        }
        implicitHeight: card.implicitHeight

        opacity: modelData.closed || previewHidden ? 0 : 1
        visible: opacity > 0

        // Any button closes it.
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: modelData.close()

        // The lock keeps the object (and this delegate) alive until the exit
        // animation has finished.
        Component.onCompleted: {
            modelData.lock();
            if (!previewHidden)
                card.enterAnim.start();
        }

        onPreviewHiddenChanged: {
            if (card.enterAnim.running && previewHidden)
                card.enterAnim.stop();
            else if (!previewHidden && !modelData.closed && !card.enterAnim.running && card.opacity === 0)
                card.enterAnim.start();
        }

        ToastItem {
            id: card
            modelData: wrapper.modelData
        }

        // Exit: accelerates out to the right and hands the lock back. The fade
        // itself is the opacity binding above plus its Behavior -- animating
        // opacity here too would break that binding.
        NumberAnimation {
            target: exitShift
            property: "x"
            to: 32
            duration: 200
            easing.type: Easing.InCubic
            running: wrapper.modelData.closed
            onFinished: wrapper.modelData.unlock()
        }

        transform: Translate { id: exitShift }

        Behavior on opacity {
            Anim { duration: 200; easing.type: Easing.InCubic }
        }
        Behavior on anchors.bottomMargin {
            Anim {}
        }
    }
}
