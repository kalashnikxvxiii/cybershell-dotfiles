//@ pragma UseQApplication

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import CyberWallpaper
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

            // Wallpaper layer (background)
            PanelWindow {
                screen: modelData
                WlrLayershell.layer: WlrLayer.Bottom
                WlrLayershell.namespace: "cyberwallpaper"
                anchors { top: true; bottom: true; left: true; right: true }
                exclusiveZone: -1
                color: "transparent"

                WallpaperLayer {
                    anchors.fill: parent
                    source: WallpaperState.screenPaths[modelData.name] || ""
                    backdropBlur: true
                    backdropDarken: 0.15
                    backdropSaturation: -0.2
                    blurRadius: 40

                    // Live binding to the singleton's properties - no restart needed
                    transitionType:         TransitionConfig.transitionType
                    transitionDuration:     TransitionConfig.transitionDuration
                    transitionFps:          TransitionConfig.transitionFps
                    transitionStep:         TransitionConfig.transitionStep
                    transitionAngle:        TransitionConfig.transitionAngle
                    transitionPos:          TransitionConfig.transitionPos
                    transitionBezier:       TransitionConfig.transitionBezier
                    transitionWave:         TransitionConfig.transitionWave
                    invertY:                TransitionConfig.invertY
                }
            }

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

