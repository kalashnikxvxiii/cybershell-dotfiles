//@ pragma UseQApplication

import Quickshell
import Quickshell.Io
import QtQuick
import "modules/core"
import "common"
import "modules/wallpaper"

ShellRoot {
    // Lyrics server: only alive while Spotify is running
    Process {
        id: lyricsServer
        command: ["python3", "/home/kalashnikxv/.config/quickshell/scripts/lyrics-server.py"]
        running: false
    }

    Timer {
        id: _lyricsRestartDelay
        interval: 300; repeat: false
        onTriggered: lyricsServer.running = true
    }

    Connections {
        target: Players
        function onSpotifyPlayerChanged() {
            if (Players.spotifyPlayer) {
                _lyricsRestartDelay.restart()
            } else {
                _lyricsRestartDelay.stop()
                lyricsServer.running = false
            }
        }
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

