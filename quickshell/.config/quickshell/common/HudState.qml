pragma Singleton
// HudState.qml -- switches, palette and live data of the desktop HUD (modules/hud).
// Sampling runs only while the HUD is enabled.

import Quickshell
import Quickshell.Io
import QtQuick
import "Colors.js" as CP

Singleton {
    id: root

    property bool enabled: true
    // Below the windows like a wallpaper, or above them without taking the pointer
    property bool onTop: false
    // By screen name: how far the Sonar card has grown to the left, in pixels
    property var sonarShift: ({})

    // What the HUD shows. A profile is a preset of these; changing one by hand makes it "custom"
    readonly property var profiles: ({
        minimal: ["status", "updates"],
        balanced: ["vitals", "status", "updates", "dock"],
        cinematic: ["vitals", "status", "updates", "dock", "launcher"]
    })
    property string profile: "cinematic"
    property var show: ({ vitals: true, status: true, updates: true, dock: true, launcher: true })

    function setProfile(name) {
        const s = {}
        for (const k in root.show)
            s[k] = root.profiles[name].indexOf(k) >= 0
        root.show = s
        root.profile = name
        root._save()
    }
    function toggleElement(k) {
        const s = Object.assign({}, root.show)
        s[k] = !s[k]
        root.show = s
        root.profile = "custom"
        root._save()
    }

    function toggle() { root.enabled = !root.enabled; root._save() }
    function toggleLayer() { root.onTop = !root.onTop; root._save() }
    function _save() { store.setText(JSON.stringify({ enabled: root.enabled, onTop: root.onTop, profile: root.profile, show: root.show })) }

    // The two switches survive a restart. Read blocking at creation: onLoaded comes too late,
    // and the HUD would flash on before a saved "off"
    FileView {
        id: store
        path: Quickshell.env("HOME") + "/.cache/qs-hud.json"
        blockLoading: true
    }
    Component.onCompleted: {
        try {
            const d = JSON.parse(store.text())
            root.enabled = d.enabled !== false
            root.onTop = d.onTop === true
            if (d.show)
                root.show = Object.assign({}, root.show, d.show)
            if (d.profile)
                root.profile = d.profile
        } catch (e) {}
    }

    // -- Palette ---------------------------------
    readonly property color danger: Colours.accentDanger
    readonly property color dangerSoft: CP.lighten(Theme.red, 0.25)
    readonly property color tech: Colours.accentSecondary
    readonly property color power: Colours.accentPrimary
    readonly property color ok: Colours.accentOk
    readonly property color mem: Colours.accentMem
    readonly property color paper: CP.white
    // Follows the wallpaper: the sonar and the corner buttons only
    readonly property color wallust: CP.neonize(Colours.glow, Theme.cyan)

    readonly property string font: Qt.fontFamilies().indexOf("Quantico") >= 0 ? "Quantico" : "Oxanium"
    readonly property string icons: "JetBrainsMono Nerd Font"

    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    // Empty part of a bar: its own hue, darkened so it holds on a bright wallpaper
    function track(c) { return Qt.rgba(c.r * 0.35, c.g * 0.35, c.b * 0.35, 0.55) }
    // Everyday traffic stays well under 1 Mbps: in Mbps it would always read 0.0
    function rate(mbps) { return mbps < 1 ? Math.round(mbps * 1000) + " Kbps" : mbps.toFixed(1) + " Mbps" }

    // -- System --------------------------
    property real cpu: 0
    property real memUsedGb: 0
    property real memTotalGb: 1
    property real diskUsedGb: 0
    property real diskTotalGb: 1
    property string iface: "-"
    property real rxMbps: 0
    property real txMbps: 0
    property real gpu: 0
    property real gpuTemp: 0

    property real _prevIdle: 0
    property real _prevTotal: 0
    property real _prevRx: -1
    property real _prevTx: 0
    property double _prevT: 0

    function _parse(text) {
        for (const line of text.split("\n")) {
            const p = line.trim().split(/\s+/)
            if (p[0] === "cpu") {
                const n = p.slice(1).map(Number)
                const idle = n[3] + (n[4] || 0)
                let total = 0
                for (const v of n) total += v || 0
                if (total > root._prevTotal && root._prevTotal > 0)
                    root.cpu = 1 - (idle - root._prevIdle) / (total - root._prevTotal)
                root._prevIdle = idle
                root._prevTotal = total
            } else if (p[0] === "MEM") {
                root.memUsedGb = p[1] / 1048576
                root.memTotalGb = p[2] / 1048576
            } else if (p[0] === "DISK") {
                root.diskUsedGb = p[1] / 1e9
                root.diskTotalGb = p[2] / 1e9
            } else if (p[0] === "NET") {
                root.iface = p[1]
                const now = Date.now()
                if (root._prevRx >= 0 && now > root._prevT) {
                    const dt = (now - root._prevT) / 1000
                    root.rxMbps = Math.max(0, (p[2] - root._prevRx) * 8 / 1e6 / dt)
                    root.txMbps = Math.max(0, (p[3] - root._prevTx) * 8 / 1e6 / dt)
                }
                root._prevRx = Number(p[2])
                root._prevTx = Number(p[3])
                root._prevT = now
            } else if (p[0] === "GPU" && p.length >= 3) {
                root.gpu = p[1] / 100
                root.gpuTemp = Number(p[2])
            }
        }
    }

    Process {
        id: snapshot
        command: [Quickshell.shellPath("scripts/hud-snapshot.sh")]
        stdout: StdioCollector { onStreamFinished: root._parse(text) }
    }
    Timer {
        interval: 2000
        repeat: true
        running: root.enabled
        triggeredOnStart: true
        onTriggered: snapshot.running = true
    }
}