//@ pragma UseQApplication

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import CyberWallpaper
import QtQuick
import "modules/core"
import "common"
import "modules/wallpaper"
import "modules/logout"
import "modules/manga"
import "modules/sonar"
import "modules/snip"
import "modules/toasts"

ShellRoot {
    // The shell's own feedback channel. Scripts reach it with
    //   qs ipc call toaster success "WALLPAPER" "Applicato" "image"
    // Every parameter is required by `qs ipc call`, so callers that do not care
    // about the icon pass "".
    IpcHandler {
        target: "toaster"

        function info(title: string, message: string, icon: string): void {
            Toaster.info(title, message, icon);
        }
        function success(title: string, message: string, icon: string): void {
            Toaster.success(title, message, icon);
        }
        function warn(title: string, message: string, icon: string): void {
            Toaster.warn(title, message, icon);
        }
        function error(title: string, message: string, icon: string): void {
            Toaster.error(title, message, icon);
        }
    }

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

            // Own layer surface above the wallpaper and below every window:
            // keeps text in self-translucent windows (Zen) readable on bright
            // wallpapers.
            ContrastScrim {
                screenObj: modelData
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

            LogoutOverlay {
                screen: modelData
            }

            MangaPanel {
                screen: modelData
            }

            SonarPanel {
                screen: modelData
            }

            SnipOverlay {
                screen: modelData
            }

            ToastOverlay {
                screen: modelData
            }
        }
    }
}

