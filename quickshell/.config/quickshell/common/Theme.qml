pragma Singleton
// Theme.qml -- the shell's palette: the accent colors every component paints with. Two fixed
// palettes (cp2077, the colors of Colors.js; netwatch, CyberArch's) plus the user's own, kept in
// ~/.config/quickshell/palettes.json. Backgrounds and the wallust-driven parts are not palettes.
import QtQuick
import Quickshell
import Quickshell.Io
import "Colors.js" as CP

Singleton {
    id: root

    // The roles a palette sets
    readonly property var roles: ["cyan", "yellow", "red", "magenta", "neon", "amber"]

    readonly property var builtin: ({
        cp2077: { cyan: CP.cyan, yellow: CP.yellow, red: CP.red, magenta: CP.magenta, neon: CP.neon, amber: CP.amber },
        netwatch: { cyan: "#5ef4f8", yellow: "#ffd62e", red: "#ff2a3a", magenta: "#e432c8", neon: "#50f096", amber: "#ffb224" }
    })
    // Name -> roles
    property var custom: ({})
    property string current: "cp2077"

    readonly property var active: root.builtin[root.current] || root.custom[root.current] || root.builtin.cp2077

    readonly property color cyan: root.active.cyan
    readonly property color yellow: root.active.yellow
    readonly property color red: root.active.red
    readonly property color magenta: root.active.magenta
    readonly property color neon: root.active.neon
    readonly property color amber: root.active.amber

    function isBuiltin(name) { return root.builtin[name] !== undefined }
    function names() { return Object.keys(root.builtin).concat(Object.keys(root.custom)) }

    function use(name) {
        if (!root.builtin[name] && !root.custom[name])
            return
        root.current = name
        root._save()
    }

    // A new palette starts as a copy of an existing one
    function duplicate(from, name) {
        const src = root.builtin[from] || root.custom[from]
        if (!src || !name || root.builtin[name] || root.custom[name])
            return false
        const c = Object.assign({}, root.custom)
        c[name] = Object.assign({}, src)
        root.custom = c
        root._save()
        return true
    }

    function setRole(name, role, color) {
        if (!root.custom[name] || root.roles.indexOf(role) < 0)
            return
        const c = Object.assign({}, root.custom)
        c[name] = Object.assign({}, c[name])
        c[name][role] = String(color)
        root.custom = c
        root._save()
    }

    // The fixed palettes can't go
    function remove(name) {
        if (!root.custom[name])
            return
        const c = Object.assign({}, root.custom)
        delete c[name]
        root.custom = c
        if (root.current === name)
            root.current = "cp2077"
        root._save()
    }

    function _save() { store.setText(JSON.stringify({ current: root.current, custom: root.custom }, null, 2)) }

    // Read blocking at creation, like HudState: otherwise the shell paints once in the default
    FileView {
        id: store
        path: Quickshell.env("HOME") + "/.config/quickshell/palettes.json"
        blockLoading: true
    }
    Component.onCompleted: {
        try {
            const d = JSON.parse(store.text())
            const ok = {}
            // Only complete palettes: a missing role would paint black
            for (const n in (d.custom || {}))
                if (root.roles.every(r => typeof d.custom[n][r] === "string"))
                    ok[n] = d.custom[n]
            root.custom = ok
            if (d.current && (root.builtin[d.current] || ok[d.current]))
                root.current = d.current
        } catch (e) {}
    }
}
