pragma Singleton
// LockState.qml -- the shell's lock screen (modules/lock). Locking takes a still of every output
// first, used as the background; the password goes through PAM with /etc/pam.d/hyprlock, so the
// rules are hyprlock's own, faillock included. hyprlock stays installed as the fallback:
// if the shell dies while locked, `hyprctl --instance 0 dispatch exec hyprlock` from a TTY
// takes over (misc.allow_session_lock_restore).
//
//   qs ipc call lock lock
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

Singleton {
    id: root

    property bool locked: false
    property bool _arming: false
    // When the lock started, for the recording timer
    property double since: 0
    // Typed on any screen, shown on all of them
    property string buffer: ""
    property int failures: 0
    // "", "verifying", "denied", "lockout", "error"
    property string status: ""

    readonly property string shotDir: Quickshell.env("XDG_RUNTIME_DIR") + "/qs-lock"
    readonly property bool busy: pam.active

    function lock() {
        if (root.locked || root._arming)
            return
        root._arming = true
        shots.running = true
    }

    function submit() {
        if (root.buffer === "" || pam.active)
            return
        root.status = "verifying"
        pam.start()
    }

    Process {
        id: shots
        // Before locking: once locked there's nothing left to capture. A failed shot still locks
        command: ["sh", "-c", 'd="$1"; mkdir -p "$d" && chmod 700 "$d" && for o in $(hyprctl monitors -j | jq -r ".[].name"); do grim -o "$o" "$d/$o.png"; done', "sh", root.shotDir]
        onExited: {
            root._arming = false
            root.buffer = ""
            root.failures = 0
            root.status = ""
            root.since = Date.now()
            root.locked = true
        }
    }

    PamContext {
        id: pam
        config: "hyprlock"
        onPamMessage: {
            if (this.responseRequired)
                this.respond(root.buffer)
        }
        onCompleted: result => {
            root.buffer = ""
            if (result === PamResult.Success) {
                root.status = ""
                root.locked = false
                // The stills show whatever was on screen: they don't outlive the lock
                Quickshell.execDetached(["rm", "-rf", root.shotDir])
            } else {
                root.failures++
                root.status = result === PamResult.MaxTries ? "lockout" : "denied"
            }
        }
        onError: {
            root.buffer = ""
            root.status = "error"
        }
    }
}
