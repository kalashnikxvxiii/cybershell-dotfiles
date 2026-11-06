// DockConfig.qml - what the edge dock contains, and what each slot does
//
// Slot metadata is static data; "is this panel open?" is a separate binding,
// because a plain JS array cannot hold bindings. Anything that needs to react
// reads activeMap, which re-evaluates whenever one of the states changes
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "Colors.js" as CP

Singleton {
    id: root

    // Order is top-to-bottom. Glyphs follow the bar's taste: geometric Unicode,
    // not Nerd Font icons (WallpaperBarModule.qml:9 uses the same ▣)
    readonly property var entries: [
        { id: "ai", glyph: "\u25c8", accent: Theme.magenta, label: "NETRUNNER" },
        { id: "wallpaper", glyph: "\u25a3", accent: Theme.cyan, label: "WALLPAPER" },
        { id: "sonar", glyph: "\u25c9", accent: Theme.neon, label: "SONAR" },
        { id: "manga", glyph: "\u25a4", accent: Theme.amber, label: "MANGA" }
    ]

    // Open state per slot. A binding, so slots light up when a panel is opened
    // from its keybind too, not only from the dock
    readonly property var activeMap: ({
        "ai": AiState.open,
        "wallpaper": root._wallpaperOpen.text().trim() === "1",
        "sonar": SonarState.open,
        "manga": root._mangaOpen.text().trim() === "1"
    })

    // Every target already owns its toggle logic, so the dock calls the
    // singletons directly instead of going through the shell scripts: the
    // scripts exist for the keybinds, which have no QML context
    function activate(id, screenName) {
        switch (id) {
            case "ai": AiState.toggleFrom(screenName); break
            case "wallpaper": root.toggleFile("/tmp/qs-wallpicker-toggle", screenName); break
            case "sonar": SonarState.toggleFrom(screenName, "net"); break
            case "manga": root.toggleFile("/tmp/qs-manga-toggle", screenName); break
        }
    }

    // Manga and wallpaper run in their own processes (manga.qml, wallpaper.qml),
    // so their singletons are out of reach here and must never be referenced
    // (that would create a second copy answering the same toggles). Toggle
    // through the file each one watches, read the state from the file it
    // writes. Same payload as the keybinds: screen_nanoseconds.
    property FileView _mangaOpen: FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/qs-manga-open"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
    property FileView _wallpaperOpen: FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/qs-wallpaper-open"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
    function toggleFile(file, screenName) {
        Quickshell.execDetached(["sh", "-c", 'printf "%s_%s" "$1" "$(date +%s%N)" > "$2"', "sh", screenName, file])
    }
}
