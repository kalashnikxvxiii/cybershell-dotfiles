// Toast.qml -- a single shell-side toast. Instantiated only by Toaster.
//
// Lifetime: the autoclose Timer is armed on `resolvedTimeout`, never on the raw
// `timeout` argument. A toast asking for its type default passes 0, and a timer
// armed on 0 fires on the next event loop turn.
//
// Locks: close() only marks the toast closed, it does not destroy it. The object
// dies when the last lock is released, so the card can play its exit animation
// while the model still holds the toast. The card locks itself on completion and
// unlocks when that animation ends -- without it the card would vanish mid-fade.
import QtQuick

QtObject {
    id: root

    enum Type {
        Info,
        Success,
        Warning,
        Error
    }

    property string title: ""
    property string message: ""
    property string icon: ""                // "" = the type picks one
    property int type: Toast.Info
    property int timeout: 0                 // <= 0 = the type picks one

    // Errors outlive confirmations: you get time to read what broke.
    readonly property int resolvedTimeout: timeout > 0 ? timeout
        : type === Toast.Error   ? 10000
        : type === Toast.Warning ?  7000
        :                           5000

    readonly property string resolvedIcon: icon !== "" ? icon
        : type === Toast.Success ? "ok"
        : type === Toast.Warning ? "warn"
        : type === Toast.Error   ? "error"
        :                          "info"

    property bool closed: false
    property int locks: 0

    // Emitted when the toast is closed AND nothing holds a lock on it anymore.
    signal finishedClose

    function close(): void {
        if (!closed)
            closed = true
        if (locks === 0)
            finishedClose()
    }

    function lock(): void {
        locks++
    }

    function unlock(): void {
        if (locks > 0)
            locks--
        if (locks === 0 && closed)
            finishedClose()
    }

    property Timer _life: Timer {
        interval: root.resolvedTimeout
        repeat: false
        running: true
        onTriggered: root.close()
    }
}
