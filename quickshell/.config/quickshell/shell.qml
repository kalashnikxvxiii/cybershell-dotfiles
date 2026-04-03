//@ pragma UseQApplication

import Quickshell
import Quickshell.Io
import QtQuick
import "modules/core"
import "common"
import "modules/wallpaper"

ShellRoot {
    // Server lyrics: vive solo finché Spotify è aperto
    Process {
        id: lyricsServer
        command: ["python3", "/home/kalashnikxv/.config/quickshell/scripts/lyrics-server.py"]
        running: !!Players.spotifyPlayer
    }

    Variants {
        model: Quickshell.screens

        Scope {
            required property var modelData

            DrawerState { id: ds }

            Exclusions {                
                screen: modelData
                barHeight: 24
            }

            Drawers {
                screen: modelData
                drawerState: ds
            }

            WallpaperPicker {
                screen: modelData
            }
        }
    }
}

