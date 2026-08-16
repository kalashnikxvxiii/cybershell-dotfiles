// Singleton: shared state + reactive PipeWire helpers + EQ state for Audio Control Center
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

QtObject {
    id: root

    // ── UI state (persisted) ──────────────────────────────────────
    property bool   expanded:  false
    property string activeTab: "outputs"  // "outputs" | "inputs" | "apps" | "eq"

    onExpandedChanged:  _saveUiStateDebounced.restart()
    onActiveTabChanged: _saveUiStateDebounced.restart()

    // ── PipeWire bindings (reactive) ──────────────────────────────
    readonly property var defaultSink:   Pipewire.preferredDefaultAudioSink
    readonly property var defaultSource: Pipewire.preferredDefaultAudioSource

    // Filtered node lists (recomputed reactively when Pipewire.nodes.values changes)
    readonly property var outputNodes: {
        var arr = []
        var nodes = Pipewire.nodes.values
        for (var i = 0; i < nodes.length; i++) {
            var n = nodes[i]
            if (n && n.isSink && !n.isStream && n.audio !== null)
                arr.push(n)
        }
        return arr
    }
    readonly property var inputNodes: {
        var arr = []
        var nodes = Pipewire.nodes.values
        for (var i = 0; i < nodes.length; i++) {
            var n = nodes[i]
            if (n && !n.isSink && !n.isStream && n.audio !== null)
                arr.push(n)
        }
        return arr
    }
    readonly property var streamNodes: {
        var arr = []
        var nodes = Pipewire.nodes.values
        for (var i = 0; i < nodes.length; i++) {
            var n = nodes[i]
            if (n && n.isStream && n.audio !== null)
                arr.push(n)
        }
        return arr
    }

    // PwObjectTracker keeps audio properties live for all tracked nodes
    property var _tracker: PwObjectTracker {
        objects: {
            var arr = []
            if (defaultSink)   arr.push(defaultSink)
            if (defaultSource) arr.push(defaultSource)
            for (var i = 0; i < outputNodes.length; i++) arr.push(outputNodes[i])
            for (var i = 0; i < inputNodes.length;  i++) arr.push(inputNodes[i])
            for (var i = 0; i < streamNodes.length; i++) arr.push(streamNodes[i])
            return arr
        }
    }

    // ── PipeWire mutating helpers ─────────────────────────────────
    function setVolume(node, val) {
        if (!node || !node.audio) return
        var v = Number(val)
        if (!isFinite(v)) return
        node.audio.volume = Math.max(0, Math.min(1.5, v))
    }

    function toggleMute(node) {
        if (!node || !node.audio) return
        node.audio.muted = !node.audio.muted
    }

    function setDefaultSink(node) {
        if (!node) return
        console.log("[audio] setDefaultSink id=" + node.id + " name=" + node.name)
        Quickshell.execDetached(["wpctl", "set-default", String(node.id)])
    }

    function setDefaultSource(node) {
        if (!node) return
        console.log("[audio] setDefaultSource id=" + node.id + " name=" + node.name)
        Quickshell.execDetached(["wpctl", "set-default", String(node.id)])
    }

    // ── EQ state (read from ~/.cache/qs-audio/eq_state.json) ──────
    property var eqBands: [0,0,0,0,0,0,0,0,0,0]  // -12..+12 dB per band
    property string eqPreset:  "Flat"
    property bool   eqPending: false
    property bool eqAvailable: false   // flipped by _eqCheckProc if easyeffects exists
    property int    eqSelectedBand: -1   // -1 = none, 0..9 = index of band displayed in CURRENT BAND detail
    property int _eqLoadFailCount: 0

    readonly property string _eqScript: Qt.resolvedUrl("../scripts/audio-eq.sh").toString().replace("file://", "")

    function applyEqPreset(name) {
        console.log("[audio] applyEqPreset name=" + name)
        Quickshell.execDetached([_eqScript, "preset", name])
        _eqReloadTimer.restart()
    }

    function setEqBand(idx, val) {
        // idx is 1-based; val is integer dB
        Quickshell.execDetached([_eqScript, "set_band", String(idx), String(Math.round(val))])
        _eqReloadTimer.restart()
    }

    function applyEqCustom() {
        console.log("[audio] applyEqCustom")
        Quickshell.execDetached([_eqScript, "apply"])
        _eqReloadTimer.restart()
    }

    // Debounce reload of EQ state file (script writes are slightly async)
    property var _eqReloadTimer: Timer {
        interval: 150
        repeat: false
        onTriggered: _eqFile.reload()
    }

    property var _eqFile: FileView {
        path: Quickshell.env("HOME") + "/.cache/qs-audio/eq_state.json"
        onLoaded: {
            root._eqLoadFailCount = 0
            try {
                var d = JSON.parse(text())
                var arr = []
                for (var i = 1; i <= 10; i++) arr.push(Number(d["b" + i]) || 0)
                root.eqBands  = arr
                root.eqPreset = d.preset || "Flat"
                root.eqPending = d.pending === true
            } catch(e) {
                console.log("[audio] EQ state parse error:", e)
            }
        }
        onLoadFailed: {
            if (root._eqLoadFailCount++ > 2) {
                console.log("[audio] EQ state file unreadable after retries, giving up")
                return
            }
            // First run: file doesn't exist yet — trigger the script to create it
            Quickshell.execDetached([root._eqScript, "get"])
            _eqReloadTimer.restart()
        }
    }

    // Check if easyeffects is installed (runs once at startup)
    property var _eqCheckProc: Process {
        command: ["bash", "-c", "command -v easyeffects >/dev/null 2>&1 && echo yes || echo no"]
        running: true
        stdout: SplitParser {
            onRead: data => { root.eqAvailable = (data.trim() === "yes") }
        }
    }

    // ── UI state persistence ──────────────────────────────────────
    readonly property string _uiStatePath: Quickshell.env("HOME") + "/.cache/qs-audio/ui_state.json"

    property var _saveUiStateDebounced: Timer {
        interval: 500
        repeat: false
        onTriggered: _saveUiState()
    }

    function _saveUiState() {
        var d = { expanded: expanded, activeTab: activeTab }
        _saveUiProc.command = [
            "python3", "-c",
            "import sys,os,json; os.makedirs(os.path.dirname(sys.argv[1]), exist_ok=True); open(sys.argv[1], 'w').write(sys.argv[2])",
            _uiStatePath,
            JSON.stringify(d)
        ]
        _saveUiProc.running = false
        _saveUiProc.running = true
    }

    property var _saveUiProc: Process {
        command: ["true"]
        running: false
    }

    property var _uiStateFile: FileView {
        path: root._uiStatePath
        onLoaded: {
            try {
                var d = JSON.parse(text())
                if (typeof d.expanded === "boolean")    root.expanded  = d.expanded
                if (typeof d.activeTab === "string")    root.activeTab = d.activeTab
            } catch(e) {}
        }
    }

    Component.onCompleted: {
        _eqFile.reload()
        _uiStateFile.reload()
    }
}
