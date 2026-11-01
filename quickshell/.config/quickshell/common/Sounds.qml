pragma Singleton
// Sounds.qml -- the shell's sound effects, by category, each with its own switch. The files live
// outside the dotfiles, in ~/.local/share/qs-hud-assets/sounds: without them the shell is silent.
//
//   qs ipc call sounds toggle menu
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.local/share/qs-hud-assets/sounds/"
    // Sound: menu (open, close, move), notify (toasts, street cred), capture, kill
    property var enabled: ({ menu: true, notify: true, capture: true, kill: true })
    property double _lastBeep: 0

    function play(category, file) {
        if (root.enabled[category] === false)
            return
        Quickshell.execDetached(["pw-play", root.dir + file])
    }

    // Holding an arrow fires it faster than it can be heard
    function beep() {
        const now = Date.now()
        if (now - root._lastBeep < 35)
            return
        root._lastBeep = now
        root.play("menu", "kiroshi_beep.ogg")
    }

    function toggle(category) {
        const e = Object.assign({}, root.enabled)
        e[category] = e[category] === false
        root.enabled = e
        settings.setText(JSON.stringify(e))
    }

    FileView {
        id: settings
        path: Quickshell.env("HOME") + "/.cache/qs-sounds.json"
        onLoaded: {
            try {
                root.enabled = Object.assign({}, root.enabled, JSON.parse(text()))
            } catch (e) {}
        }
    }
}
