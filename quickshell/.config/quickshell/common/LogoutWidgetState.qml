pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick


QtObject {
    id: root

    // ── Registry: tutti i widget disponibili ────────────────
    // Aggiungere widget: crea file in modules/logout/widgets/ + entry qui.
    readonly property var availableWidgets: [
        { id: "avatar", label: "USER AVATAR", defaultEnabled: true, componentPath: "widgets/AvatarWidget.qml" },
        { id: "clock",  label: "CLOCK",       defaultEnabled: true, componentPath: "widgets/ClockWidget.qml" },
        { id: "uptime", label: "UPTIME",      defaultEnabled: true, componentPath: "widgets/UptimeWidget.qml" }
    ]


    // ── User config (JSON persistence) ──────────────────────
    property var _widgets: []

    readonly property var enabledOrdered: {
        // Filter: widget deve essere in availableWidgets attualmente (esclude orphaned dal config vecchio)
        var validIds = availableWidgets.map(w => w.id)
        var arr = _widgets.filter(w => w.enabled && validIds.indexOf(w.id) >= 0)
        arr.sort((a, b) => a.order - b.order)
        return arr
    }

    // ── Public actions (for future management UI) ───────────
    function toggle(id) {
        for (var i = 0; i < _widgets.length; i++) {
            if (_widgets[i].id === id) {
                _widgets[i].enabled = !_widgets[i].enabled
                _widgets = _widgets.slice()
                save()
                return
            }
        }
        _widgets = _widgets.concat([{ id: id, enabled: true, order: _widgets.length }])
        save()
    }

    function moveUp(id) {
        var idx = _widgets.findIndex(w => w.id === id)
        if (idx > 0) {
            var arr = _widgets.slice()
            var tmp = arr[idx].order
            arr[idx].order = arr[idx-1].order
            arr[idx-1].order = tmp
            var swap = arr[idx]; arr[idx] = arr[idx-1]; arr[idx-1] = swap
            _widgets = arr
            save()
        }
    }

    function moveDown(id) {
        var idx = _widgets.findIndex(w => w.id === id)
        if (idx >= 0 && idx < _widgets.length - 1) {
            var arr = _widgets.slice()
            var tmp = arr[idx].order
            arr[idx].order = arr[idx+1].order
            arr[idx+1].order = tmp
            var swap = arr[idx]; arr[idx] = arr[idx+1]; arr[idx+1] = swap
            _widgets = arr
            save()
        }
    }

    function resetDefaults() {
        var seed = []
        for (var i = 0; i < availableWidgets.length; i++) {
            seed.push({
                id: availableWidgets[i].id,
                enabled: availableWidgets[i].defaultEnabled,
                order: i
            })
        }
        _widgets = seed
        save()
    }

    // Se availableWidgets ha nuovi id non presenti in _widgets, li aggiunge in coda
    function _seedMissing() {
        var existingIds = _widgets.map(w => w.id)
        var added = false
        for (var i = 0; i < availableWidgets.length; i++) {
            if (existingIds.indexOf(availableWidgets[i].id) < 0) {
                _widgets = _widgets.concat([{
                    id: availableWidgets[i].id,
                    enabled: availableWidgets[i].defaultEnabled,
                    order: _widgets.length
                }])
                added = true
            }
        }
        if (added) save()
    }

    // ── Persistence ─────────────────────────────────────────
    readonly property string _stateFile: (Quickshell.env("HOME") || "/tmp") + "/.cache/quickshell/logout-widgets.json"

    function save() {
        var json = JSON.stringify(_widgets)
        _saveProc.command = ["bash", "-c",
            "mkdir -p \"$(dirname '" + _stateFile + "')\" && cat > '" + _stateFile + "' <<'JSON'\n" + json + "\nJSON"]
        _saveProc.running = true
    }

    property Process _saveProc: Process { command: ["true"] }

    property Process _loadProc: Process {
        running: true
        command: ["bash", "-c", "[ -f '" + _stateFile + "' ] && cat '" + _stateFile + "' || echo '[]'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(this.text)
                    if (Array.isArray(parsed) && parsed.length > 0) {
                        root._widgets = parsed
                        root._seedMissing()
                        return
                    }
                } catch (e) {
                    console.warn("WidgetState: JSON parse failed:", e)
                }
                root.resetDefaults()
            }
        }
    }
}
