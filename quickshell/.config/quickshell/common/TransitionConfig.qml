pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: root

    // ── Dialog state ──────────────────────────────
    property bool editorOpen: false

    // ── Transition properties ─────────────────────────
    // (awww-compatible names; defaults overridden by JSON on load)
    property string transitionBezier:   "0.54,0,0.34,0.99"
    property string transitionWave:     "20,20"
    property string transitionType:     "fade"
    property string transitionPos:      "center"
    property bool   invertY:            false
    property real   transitionDuration: 3.0
    property real   transitionAngle:    45.0
    property int    transitionStep:     90
    property int    transitionFps:      30

    // ── User custom bezier presets ────────────────────
    // Each entry: { name: "...", x1, y1, x2, y2 }
    property var userPresets: []

    // ── Dirty state tracking ──────────────────────────
    // Snapshot of various values "saved" - runtime confrontation determines if isDirty
    property string _savedUserPresetsJson:  ""
    property string _savedBezier:           ""
    property string _savedType:             ""
    property string _savedWave:             ""
    property string _savedPos:              ""
    property bool   _savedInvertY:          false
    property real   _savedDuration:         0
    property real   _savedAngle:            0
    property int    _savedStep:             0
    property int    _savedFps:              0

    readonly property bool isDirty:
        _savedType                  !== transitionType
        || _savedDuration           !== transitionDuration
        || _savedFps                !== transitionFps
        || _savedStep               !== transitionStep
        || _savedAngle              !== transitionAngle
        || _savedPos                !== transitionPos
        || _savedBezier             !== transitionBezier
        || _savedWave               !== transitionWave
        || _savedInvertY            !== invertY
        || _savedUserPresetsJson    !== JSON.stringify(userPresets)

    function _takeSnapshot() {
        _savedType              = transitionType
        _savedDuration          = transitionDuration
        _savedFps               = transitionFps
        _savedStep              = transitionStep
        _savedAngle             = transitionAngle
        _savedPos               = transitionPos
        _savedBezier            = transitionBezier
        _savedWave              = transitionWave
        _savedInvertY           = invertY
        _savedUserPresetsJson   = JSON.stringify(userPresets)
    }

    signal saved()
    signal reverted()

    // ── Type cycle ────────────────────────────────────
    readonly property var _allTypes: [
        "none", "fade",                             // BASIC
        "left", "right", "top", "bottom", "wipe",   // WIPE
        "grow", "outer",                            // RADIAL
        "wave", "rand-wipe", "random"               // SPECIAL
    ]

    function nextType() {
        var idx = _allTypes.indexOf(transitionType)
        if (idx < 0) idx = 0
        transitionType = _allTypes[(idx + 1) % _allTypes.length]
    }

    function prevType() {
        var idx = _allTypes.indexOf(transitionType)
        if (idx < 0) idx = 0
        transitionType = _allTypes[(idx - 1 + _allTypes.length) % _allTypes.length]
    }

    // ── Preview replay (triggered by shortcut, listened by PreviewPane) ────────────────────────────────────
    signal previewReplayRequested()

    // ── Persistence ────────────────────────────────────
    readonly property string _path: "/home/kalashnikxv/.config/quickshell/transitions.json"

    function saveCurrentAsPreset(name) {
        name = (name || "").trim()
        if (name === "") return
        var p = transitionBezier.split(",")
        if (p.length !== 4) return
        var x1 = parseFloat(p[0]), y1 = parseFloat(p[1])
        var x2 = parseFloat(p[2]), y2 = parseFloat(p[3])
        if (isNaN(x1) || isNaN(y1) || isNaN(x2) || isNaN(y2)) return

        var arr = userPresets.slice()
        var entry = { name: name, x1: x1, y1: y1, x2: x2, y2: y2 }
        // Replace if name exists; else append
        var replaced = false
        for (var i = 0; i < arr.length; i++) {
            if (arr[i].name === name) {
                arr[i] = entry
                replaced = true
                break
            }
        }
        if (!replaced) arr.push(entry)
        userPresets = arr
        save()
    }

    function deleteUserPreset(name) {
        userPresets = userPresets.filter(function(p) { return p.name !== name })
        save()
    }

    function resetBezier() {
        transitionBezier = "0.54,0.000,0.34,0.99"       // awww default
    }

    function mirrorBezier() {
        var p = transitionBezier.split(",")
        if (p.length !== 4) return
        var x1 = parseFloat(p[0]), y1 = parseFloat(p[1])
        var x2 = parseFloat(p[2]), y2 = parseFloat(p[3])
        if (isNaN(x1) || isNaN(y1) || isNaN(x2) || isNaN(y2)) return
        // Reflect across (0.5, 0.5): swap control points and invert
        // (x1,y1,x2,y2) -> (1-x2, 1-y2, 1-x1, 1-y1)
        // easIn <-> easeOut, easeInBack <-> easeOutBack, ecc.
        transitionBezier = (1 - x2).toFixed(3) + "," + (1 - y2).toFixed(3) + ","
                        + (1 - x1).toFixed(3) + "," + (1 - y1).toFixed(3)
    }

    function save() {
        var d = {
            type:           transitionType,
            duration:       transitionDuration,
            fps:            transitionFps,
            step:           transitionStep,
            angle:          transitionAngle,
            pos:            transitionPos,
            bezier:         transitionBezier,
            wave:           transitionWave,
            invertY:        invertY,
            userPresets:    userPresets
        }
        _saveProc.command = ["python3", "-c",
            "import sys, os, json; os.makedirs(os.path.dirname(sys.argv[1]), exist_ok=True); open(sys.argv[1], 'w').write(sys.argv[2])",
            _path,
            JSON.stringify(d, null, 2)]
        _saveProc.running = false
        _saveProc.running = true
        _takeSnapshot()
        saved()
    }

    function revert() {
        transitionType = _savedType
        transitionDuration = _savedDuration
        transitionFps = _savedFps
        transitionStep = _savedStep
        transitionAngle = _savedAngle
        transitionPos = _savedPos
        transitionBezier = _savedBezier
        transitionWave = _savedWave
        invertY = _savedInvertY
        try {
            userPresets = JSON.parse(_savedUserPresetsJson)
        } catch (e) {
            userPresets = []
        }
        reverted()
    }

    property var _saveProc: Process {
        command: ["true"]
        running: false
    }

    property var _loadFile: FileView {
        path: root._path
        onLoaded: {
            try {
                var d = JSON.parse(text())
                if (d.type !== undefined) {
                    if (d.type === "simple") d.type = "fade"
                    if (d.type === "center") d.type = "grow"
                    if (d.type === "any")    d.type = "rand-wipe"
                    root.transitionType = d.type
                }
                if (d.duration !== undefined)       root.transitionDuration = d.duration
                if (d.fps !== undefined)            root.transitionFps = d.fps
                if (d.step !== undefined)           root.transitionStep = d.step
                if (d.angle !== undefined)          root.transitionAngle = d.angle
                if (d.pos !== undefined)            root.transitionPos = d.pos
                if (d.bezier !== undefined)         root.transitionBezier = d.bezier
                if (d.wave !== undefined)           root.transitionWave = d.wave
                if (d.invertY !== undefined)        root.invertY = d.invertY
                if (Array.isArray(d.userPresets))   root.userPresets = d.userPresets
            } catch (e) {}
            root._takeSnapshot()
        }
        onLoadFailed: {
            root._takeSnapshot()
        }
    }

    Component.onCompleted: _loadFile.reload()
}