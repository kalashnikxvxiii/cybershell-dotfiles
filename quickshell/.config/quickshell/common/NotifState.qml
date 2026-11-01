pragma Singleton
// NotifState.qml -- the shell as the desktop's notification daemon: a queue of popups shown one
// at a time, the history, do not disturb. Do not disturb also holds while a window is fullscreen.
//
//   qs ipc call notifications toggle | toggleDnd | clear
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications

Singleton {
    id: root

    property bool dnd: false
    property bool fullscreen: false
    readonly property bool quiet: dnd || fullscreen

    property bool panelOpen: false
    property string panelScreen: ""

    property var current: null
    property var _queue: []
    // Arrival times by notification id: the protocol doesn't carry them
    property var times: ({})
    // Ids of the messages opened
    property var read: ({})

    readonly property var history: server.trackedNotifications.values.slice().reverse()

    function toggleDnd() { root.dnd = !root.dnd }

    function togglePanel() {
        root.panelScreen = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        root.panelOpen = !root.panelOpen
    }

    function clear() {
        for (const n of root.history)
            n.dismiss()
    }

    function picture(n) {
        return n ? (n.image || (n.appIcon ? Quickshell.iconPath(n.appIcon, true) : "")) : ""
    }

    // What a left click means: the notification's own default action, or a look at the history
    function open(n) {
        const r = Object.assign({}, root.read)
        r[n.id] = true
        root.read = r
        const wasCurrent = root.current === n
        const a = n.actions.find(x => x.identifier === "default")
        if (a)
            a.invoke()
        else if (!root.panelOpen)
            root.togglePanel()
        // The invoke may already have closed it and moved the queue on
        if (wasCurrent && root.current === n)
            root._next()
    }

    function _next() {
        expiry.stop()
        root.current = root._queue.length > 0 ? root._queue[0] : null
        root._queue = root._queue.slice(1)
        if (!root.current)
            return
        const c = root.current
        Sounds.play("notify", "notif.mp3")
        // In milliseconds; the callers that set one (Snip) wait for the answer
        const own = c.expireTimeout > 0 ? c.expireTimeout : 0
        if (own > 0 || c.urgency !== NotificationUrgency.Critical) {
            expiry.interval = own > 0 ? own : c.urgency === NotificationUrgency.Low ? 5000 : 18000
            expiry.start()
        }
    }

    function _arrive(n) {
        n.tracked = true
        const t = Object.assign({}, root.times)
        t[n.id] = new Date()
        root.times = t
        n.closed.connect(() => root._gone(n))
        if (root.quiet && n.urgency !== NotificationUrgency.Critical)
            return
        root._queue = root._queue.concat([n])
        if (!root.current)
            root._next()
    }

    function _gone(n) {
        root._queue = root._queue.filter(x => x !== n)
        if (root.current === n)
            root._next()
    }

    Timer {
        id: expiry
        onTriggered: {
            const c = root.current
            // Whoever passed a timeout or actions may be blocked on the outcome
            if (c.transient || c.expireTimeout > 0)
                c.expire()
            else
                root._next()
        }
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true
        bodySupported: true
        onNotification: n => root._arrive(n)
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "fullscreen")
                root.fullscreen = event.data === "1"
        }
    }
}
