// WallustColors.qml — reads wallust-colors.css and updates the colors

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property color bg:   "#050309"
    property color fg:   "#FF84AC"
    property color glow: "#E5456F"

    property var _watcher: FileView {
        id: fv
        path: "/home/kalashnikxv/.config/waybar/wallust-colors.css"
        watchChanges: true
        onLoaded:      root._parse(fv.text())
        onFileChanged: reload()
    }

    function _parse(content) {
        if (!content) return
        var bgMatch   = content.match(/@define-color\s+wb-bg\s+(#[0-9a-fA-F]+)/)
        var fgMatch   = content.match(/@define-color\s+wb-fg\s+(#[0-9a-fA-F]+)/)
        var glowMatch = content.match(/@define-color\s+wb-glow\s+(#[0-9a-fA-F]+)/)
        if (bgMatch)   root.bg   = bgMatch[1]
        if (fgMatch)   root.fg   = fgMatch[1]
        if (glowMatch) root.glow = glowMatch[1]
    }
}
