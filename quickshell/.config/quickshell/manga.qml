// manga.qml - the manga panel as its own Quickshell process, so a crash in it
// (network, image decode) takes down only this panel and not the whole shell.
// Run by systemd: qs@manga.service (systemctl --user restart qs@manga).
// The main shell talks to it only through files: /tmp/qs-manga-toggle in,
// $XDG_RUNTIME_DIR/qs-manga-open out (see MangaState and DockConfig).
import Quickshell
import QtQuick
import "modules/manga"

ShellRoot {
    Variants {
        model: Quickshell.screens

        MangaPanel {
            required property var modelData
            screen: modelData
        }
    }
}
