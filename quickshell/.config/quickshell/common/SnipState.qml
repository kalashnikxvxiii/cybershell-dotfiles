// SnipState.qml — session state for the snip overlay, plus the keybind channel.
//
// Split from SnipAction on purpose: SnipAction knows how to turn a rectangle
// into a command and nothing else, this knows which screen we are snipping,
// which frozen PNG we are snipping from and which action is armed. The overlay
// is then a pure view over this.
//
// The freeze is captured by scripts/snip.sh BEFORE this ever becomes active.
// That ordering is the whole point: grim runs while the desktop still shows the
// menu or tooltip being captured, and the overlay -- which appears afterwards --
// can never end up inside the image.
//
// Coordinates: the overlay reports its own window-local logical coordinates.
// commit() adds the monitor origin to get the global logical rectangle that
// SnipAction expects, and passes the scale along for the pixel conversion.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ── Session ──────────────────────────────────────────────────────────
    property bool   active: false
    property string screenName: ""
    property string frozenPath: ""
    property real   monitorX: 0
    property real   monitorY: 0
    property real   monitorScale: 1
    property int    action: SnipAction.Action.Screenshot

    // Phase 3 will drive the window-outline picker from here.
    property bool   windowOutlines: false

    // ── Toolbar model ────────────────────────────────────────────────────
    // Order is the tab order and the 1-4 shortcut order. Accents are the
    // semantic ones: yellow = capture/corpo, cyan = network lookup,
    // magenta = text/memory, red = recording/danger.
    readonly property var tabs: [
        { action: SnipAction.Action.Screenshot, label: "SCREENSHOT", accent: Colours.accentPrimary },
        { action: SnipAction.Action.Search,     label: "SEARCH",    accent: Colours.accentSecondary },
        { action: SnipAction.Action.Ocr,        label: "OCR",        accent: Colours.accentMem },
        { action: SnipAction.Action.Record,     label: "RECORD",     accent: Colours.accentDanger }
    ]

    readonly property int currentTab: {
        for (var i = 0; i < root.tabs.length; i++)
            if (root.tabs[i].action === root.action)
                return i;
        return 0;
    }

    readonly property color currentAccent: root.tabs[root.currentTab].accent

    function setTab(i) {
        if (i >= 0 && i < root.tabs.length)
            root.action = root.tabs[i].action;
    }

    function cycleTab(delta) {
        const n = root.tabs.length;
        root.setTab((root.currentTab + delta + n) % n);
    }

    // ── Lifecycle ────────────────────────────────────────────────────────
    // One session at a time. A second keybind press while a selector is up must
    // not stack another one: it re-arms the action of the session already open,
    // which is the same thing the toolbar does. Anything else leaves orphaned
    // freezes behind and swaps the image out from under a selection in progress.
    function open(act, screen, path, mx, my, scale) {
        if (root.active) {
            // The freeze that just arrived has no owner -- no action script will
            // ever consume it -- so it is ours to remove.
            if (path && path !== root.frozenPath)
                Quickshell.execDetached(["rm", "-f", path]);
            root.action = act;
            return;
        }
        root.action = act;
        root.screenName = screen;
        root.frozenPath = path;
        root.monitorX = mx;
        root.monitorY = my;
        root.monitorScale = scale || 1;
        root.active = true;
    }

    function rearm(act) {
        if (root.active)
            root.action = act;
    }

    function _close() {
        root.active = false;
        root.screenName = "";
        root.frozenPath = "";
    }

    // ── Session lock ─────────────────────────────────────────────────────
    // Lets scripts/snip.sh know a selector is already up, so it can re-arm it
    // instead of paying for another grim capture. It holds quickshell's pid, so
    // a shell that dies mid-session cannot wedge the keybind forever: the script
    // checks the pid is alive before trusting the lock.
    readonly property string _lockPath:
        (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-snip/session.lock"

    onActiveChanged: {
        if (root.active)
            Quickshell.execDetached(["bash", "-c",
                "mkdir -p \"$(dirname '" + root._lockPath + "')\" && printf '%s' "
                + Quickshell.processId + " > '" + root._lockPath + "'"]);
        else
            Quickshell.execDetached(["rm", "-f", root._lockPath]);
    }

    // Cancelling is the overlay's half of the two cleanup paths: no action
    // script will run, so nobody else will ever remove the frozen PNG.
    function cancel() {
        if (root.frozenPath)
            Quickshell.execDetached(["rm", "-f", root.frozenPath]);
        root._close();
    }

    // Confirming is the other half: the file is handed to the action script,
    // which deletes it once magick is done with it. Deleting it here would
    // pull it out from under the crop.
    function commit(localX, localY, w, h) {
        if (w < 1 || h < 1) {
            root.cancel();
            return;
        }
        SnipAction.run({
            x: localX + root.monitorX,
            y: localY + root.monitorY,
            w: w,
            h: h
        }, {
            action: root.action,
            source: root.frozenPath,
            monitorX: root.monitorX,
            monitorY: root.monitorY,
            scale: root.monitorScale
        });
        root._close();
    }

    // Right button at release overrides the armed action with the annotator,
    // without disturbing which tab is selected for the next snip.
    function commitAnnotate(localX, localY, w, h) {
        const armed = root.action;
        root.action = SnipAction.Action.Annotate;
        root.commit(localX, localY, w, h);
        root.action = armed;
    }

    // ── Keybind channel ──────────────────────────────────────────────────
    // Written by scripts/snip.sh. Two verbs:
    //   overlay|<action>|<screen>|<src>|<monX>|<monY>|<scale>|<nanos>
    //   direct |<action>|<x>|<y>|<w>|<h>|<src>|<monX>|<monY>|<scale>|<nanos>
    // "direct" keeps the slurp path alive for debugging and for anything that
    // wants to drive a snip without the overlay.
    property string _lastTrigger: ""

    // The trigger file outlives the shell, and its freeze has usually already
    // been consumed by the action script. Replaying it on startup would open the
    // overlay over a missing PNG -- with an exclusive keyboard grab, and nothing
    // on screen to explain it. So anything written before this shell started is
    // read once and discarded; that is what the nanosecond field is for.
    readonly property real _startupMs: Date.now()

    readonly property FileView _triggerReader: FileView {
        path: "/tmp/qs-snip-trigger"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const content = text().trim();
            if (content === "" || content === root._lastTrigger)
                return;
            root._lastTrigger = content;

            const f = content.split("|");

            const stampMs = parseFloat(f[f.length - 1]) / 1e6;
            if (!isFinite(stampMs) || stampMs < root._startupMs)
                return;
            const act = SnipAction.actionFromName(f[1]);
            if (act < 0)
                return;

            if (f[0] === "rearm") {
                root.rearm(act);
            } else if (f[0] === "overlay" && f.length >= 7) {
                root.open(act, f[2], f[3],
                          parseFloat(f[4]), parseFloat(f[5]), parseFloat(f[6]) || 1);
            } else if (f[0] === "direct" && f.length >= 10) {
                SnipAction.run({
                    x: parseFloat(f[2]), y: parseFloat(f[3]),
                    w: parseFloat(f[4]), h: parseFloat(f[5])
                }, {
                    action: act, source: f[6],
                    monitorX: parseFloat(f[7]), monitorY: parseFloat(f[8]),
                    scale: parseFloat(f[9]) || 1
                });
            }
        }
    }
}
