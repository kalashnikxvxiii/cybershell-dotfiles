// Toaster.qml -- the shell's own feedback channel, separate from swaync.
//
// For events that belong to the shell (wallust ran, wallpaper applied, WPE died,
// EQ preset armed, process killed): they are not system notifications, they do
// not belong in a notification centre and they do not belong in its history.
//
// Call it from anywhere:
//   Toaster.toast("WALLUST", "Palette rigenerata", "palette", Toast.Success)
//   Toaster.success("WALLUST", "Palette rigenerata")
//
// Scripts go through the IpcHandler in shell.qml:
//   qs ipc call toaster success WALLPAPER Applicato image
pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // Fullscreen behaviour: what still gets through while a fullscreen window
    // owns the monitor. Read per screen by ToastOverlay.
    enum FullscreenPolicy {
        All,        // show everything
        Important,  // only Warning and Error
        None        // show nothing
    }

    property int fullscreenPolicy: Toaster.Important

    // Beyond this many the cards still exist but stay hidden, so they scale in
    // as the ones in front leave.
    property int maxToasts: 4

    // Newest first (push_front): the card closest to the screen corner -- the
    // point they enter from -- is the one that just arrived.
    property var toasts: []

    function toast(title, message, icon, type, timeout): var {
        const t = _toastComponent.createObject(root, {
            title: title || "",
            message: message || "",
            icon: icon || "",
            type: type === undefined ? Toast.Info : type,
            timeout: timeout === undefined ? 0 : timeout
        });
        t.finishedClose.connect(() => root._remove(t));
        toasts = [t].concat(toasts);
        return t;
    }

    function info(title, message, icon): var {
        return toast(title, message, icon, Toast.Info);
    }
    function success(title, message, icon): var {
        return toast(title, message, icon, Toast.Success);
    }
    function warn(title, message, icon): var {
        return toast(title, message, icon, Toast.Warning);
    }
    function error(title, message, icon): var {
        return toast(title, message, icon, Toast.Error);
    }

    // Closes everything: the cards still animate out, the locks still apply.
    function clear(): void {
        for (const t of toasts)
            t.close();
    }

    function _remove(t): void {
        const next = toasts.filter(x => x !== t);
        if (next.length === toasts.length)
            return;
        toasts = next;
        t.destroy();
    }

    property Component _toastComponent: Component {
        Toast {}
    }
}
