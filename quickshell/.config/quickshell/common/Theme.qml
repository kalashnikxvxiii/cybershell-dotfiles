pragma Singleton
// Theme.qml -- the shell's palette: the accent and background colors every component paints with. Two fixed
// palettes (netwatch, the colors of Colors.js; cp2077, CyberArch's) plus the user's own, kept in
// ~/.config/quickshell/palettes.json. The wallust-driven parts are not palettes.
import QtQuick
import Quickshell
import Quickshell.Io
import "Colors.js" as CP

Singleton {
    id: root

    // The roles a palette sets
    readonly property var roles: ["cyan", "yellow", "red", "magenta", "neon", "amber", "void_", "void2", "moduleBg", "moduleBgAlt"]

    readonly property var builtin: ({
        netwatch: { cyan: CP.cyan, yellow: CP.yellow, red: CP.red, magenta: CP.magenta, neon: CP.neon, amber: CP.amber, void_: CP.void_, void2: CP.void2, moduleBg: String(CP.moduleBg), moduleBgAlt: String(CP.moduleBgAlt) },
        // CyberArch's: red where netwatch has yellow, and its maroon backgrounds
        cp2077: { cyan: "#5ef4f8", yellow: "#ff2a3a", red: "#ff2a3a", magenta: "#e432c8", neon: "#2adc83", amber: "#ffb224", void_: "#14050a", void2: "#120307", moduleBg: "#eb1a060b", moduleBgAlt: "#d91f070e" }
    })
    // Name -> roles
    property var custom: ({})
    property string current: "netwatch"

    readonly property var active: root.builtin[root.current] || root.custom[root.current] || root.builtin.netwatch

    readonly property color cyan: root.active.cyan
    readonly property color yellow: root.active.yellow
    readonly property color red: root.active.red
    readonly property color magenta: root.active.magenta
    readonly property color neon: root.active.neon
    readonly property color amber: root.active.amber
    readonly property color void_: root.active.void_
    readonly property color void2: root.active.void2
    readonly property color moduleBg: root.active.moduleBg
    readonly property color moduleBgAlt: root.active.moduleBgAlt

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
            root.current = "netwatch"
        root._save()
    }

    // -- Fonts: one for the HUD, one for everything else. Only those installed ------
    readonly property var fonts: ["Oxanium", "Quantico", "Tektur"].filter(f => Qt.fontFamilies().indexOf(f) >= 0)
    property string font: "Oxanium"
    property string hudFont: root.fonts.indexOf("Quantico") >= 0 ? "Quantico" : "Oxanium"

    // role: "font" or "hudFont"
    function setFont(role, family) {
        if (root.fonts.indexOf(family) < 0 || (role !== "font" && role !== "hudFont"))
            return
        root[role] = family
        root._save()
    }

    function _save() { store.setText(JSON.stringify({ current: root.current, custom: root.custom, font: root.font, hudFont: root.hudFont }, null, 2)) }

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
            if (root.fonts.indexOf(d.font) >= 0)
                root.font = d.font
            if (root.fonts.indexOf(d.hudFont) >= 0)
                root.hudFont = d.hudFont
        } catch (e) {}
    }
}
