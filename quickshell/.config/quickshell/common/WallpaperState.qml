pragma Singleton

import Quickshell.Io
import QtQuick
import "WallpaperConstants.js" as WC


QtObject {
    id: root

    // ── Picker visibility ───────────────────────────────────
    property string activeScreen:   ""
    property bool   pickerOpen:     false

    function togglePicker(screen) {
        if (pickerOpen) {
            pickerOpen = false
        } else {
            activeScreen = screen
            pickerOpen = true
        }
    }

    function closePicker() {
        pickerOpen = false
    }

    // ── Filter state ───────────────────────────────────────
    // macro: "all" | "awww" | "wpe"
    property string macroFilter: "all"
    // sub: "" (none) | "image"| "gif" | "scene" | "video"
    property string subFilter: ""
    // color: "" (none) | "#hex"
    property string colorFilter: ""

    function resetFilters() {
        macroFilter = "all"
        subFilter = ""
        colorFilter = ""
    }

    function cycleMacro() {
        if (macroFilter === "all") macroFilter = "awww"
        else if (macroFilter === "awww") macroFilter = "wpe"
        else macroFilter = "all"
        subFilter = ""
    }

    function cycleSub() {
        if (macroFilter === "awww") {
            if (subFilter === "") subFilter = "image"
            else if (subFilter === "image") subFilter = "gif"
            else subFilter = ""
        } else if (macroFilter === "wpe") {
            if (subFilter === "") subFilter = "scene"
            else if (subFilter === "scene") subFilter = "video"
            else subFilter = ""
        }
    }

    // ── Filter matching ─────────────────────────────────────
    function matchesFilter(entry) {
        // Macro
        if (macroFilter === "awww" && entry.source !== "awww") return false
        if (macroFilter === "wpe" && entry.source !== "wpe") return false
        // Sub
        if (subFilter !== "" && entry.type !== subFilter) return false
        // Color 
        if (colorFilter !== "" && !_colorMatches(entry.color, colorFilter)) return false
        return true
    }

    // ── Color matching (hue bucket) ──────────────────────────────────
    function _hexToHsl(hex) {
        hex = hex.replace("#", "")
        var r = parseInt(hex.substr(0, 2), 16) / 255
        var g = parseInt(hex.substr(2, 2), 16) / 255
        var b = parseInt(hex.substr(4, 2), 16) / 255
        var max = Math.max(r, g, b), min = Math.min(r, g, b)
        var h = 0, s = 0, l = (max + min) / 2
        if (max !== min) {
            var d = max - min
            s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
            if (max === r) h = ((g - b) / d + (g < b ? 6 : 0)) * 60
            else if (max === g) h = ((b - r) / d + 2) * 60
            else h = ((r - g) / d + 4) * 60
        }
        return { h: h, s: s * 100, l: l * 100 }
    }

    function _colorMatches(entryColor, filterColor) {
        var bucket = WC.colorBuckets[filterColor]
        if (!bucket) return true
        var hsl = _hexToHsl(entryColor)
        // Monochrome check
        if (bucket[0] === -1) return hsl.s < 15
        // Hue range check (non-monochrome only)
        if (hsl.s < 15) return false
        var h = hsl.h
        if (bucket[0] <= bucket[1]) return h >= bucket[0] && h < bucket[1]
        return h >= bucket[0] || h < bucket[1]      // wrap-around (red)
    }

    // ── Ensure toggle file exists before watcher starts ────────────────
    property string _lastToggleContent: ""

    Component.onCompleted: {
        _toggleInitProc.running = true
    }

    property var _toggleInitProc: Process {
        command: ["bash", "-c", "echo -n '' > /tmp/qs-wallpicker-toggle"]
        running: false
        onRunningChanged: {
            if (!running) {
                _toggleReader.reload()
                root._lastToggleContent = _toggleReader.text()
            }
        }
    }

    property var _toggleReader: FileView {
        path: "/tmp/qs-wallpicker-toggle"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            var content = text().trim()
            if (content !== "" && content !==root._lastToggleContent) {
                root._lastToggleContent = content
                root.togglePicker(content.split("_")[0])
            }
        }
    }
}