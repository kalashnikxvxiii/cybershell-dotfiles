// WallustColors.qml -- the wallust palette, read from the JSON it writes on every run

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property color bg:   "#050309"
    property color fg:   "#FF84AC"
    property color glow: "#E5456F"

    property var _watcher: FileView {
        id: fv
        path: Quickshell.env("HOME") + "/.cache/wallust/colors.json"
        watchChanges: true
        onLoaded:      root._parse(fv.text())
        onFileChanged: reload()
    }

    function _parse(content) {
        // Wallust writes in place: a read mid-write is not JSON yet, and the next change event retries
        try {
            const palette = JSON.parse(content)
            root.bg = palette.special.background
            root.fg = palette.special.foreground
            root.glow = palette.colors.color6
        } catch (e) {
            console.warn("WallustColors:", e)
        }
    }
}
