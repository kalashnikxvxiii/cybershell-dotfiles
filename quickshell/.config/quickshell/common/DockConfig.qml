// DockConfig.qml - what the edge dock contains, and what each slot does
//
// Slot metadata is static data; "is this panel open?" is a separate binding,
// because a plain JS array cannot hold bindings. Anything that needs to react
// reads activeMap, which re-evaluates whenever one of the states changes
pragma Singleton

import Quickshell
import QtQuick
import "Colors.js" as CP

Singleton {
    id: root

    // Order is top-to-bottom. Glyphs follow the bar's taste: geometric Unicode,
    // not Nerd Font icons (WallpaperBarModule.qml:9 uses the same ▣)
    readonly property var entries: [
        { id: "ai", glyph: "\u25c8", accent: CP.magenta, label: "NETRUNNER" },
        { id: "wallpaper", glyph: "\u25a3", accent: CP.cyan, label: "WALLPAPER" },
        { id: "sonar", glyph: "\u25c9", accent: CP.neon, label: "SONAR" },
        { id: "manga", glyph: "\u25a4", accent: CP.amber, label: "MANGA" }
    ]

    // Open state per slot. A binding, so slots light up when a panel is opened
    // from its keybind too, not only from the dock
    readonly property var activeMap: ({
        "ai": AiState.open,
        "wallpaper": WallpaperState.pickerOpen,
        "sonar": SonarState.open,
        "manga": MangaState.panelOpen
    })

    // Every target already owns its toggle logic, so the dock calls the
    // singletons directly instead of going through the shell scripts: the
    // scripts exist for the keybinds, which have no QML context
    function activate(id, screenName) {
        switch (id) {
            case "ai": AiState.toggleFrom(screenName); break
            case "wallpaper": WallpaperState.togglePicker(screenName); break
            case "sonar": SonarState.toggleFrom(screenName, "net"); break
            case "manga": MangaState.togglePanel(screenName); break
        }
    }
}