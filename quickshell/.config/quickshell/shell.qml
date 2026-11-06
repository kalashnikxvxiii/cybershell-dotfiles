//@ pragma UseQApplication

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "modules/core"
import "common"
import "modules/sonar"
import "modules/snip"
import "modules/kill"
import "modules/notifications"
import "modules/toasts"
import "modules/launcher"
import "modules/media"
import "modules/wheel"
import "modules/cheatsheet"
import "modules/hud"
import "modules/lock"

ShellRoot {
    // Quick action wheel, shown over the Hyprland menus
    QuickWheel {}

    // Keymap, SUPER + /
    Cheatsheet {}
    
    // The shell's own feedback channel. Scripts reach it with
    //   qs ipc call toaster success "WALLPAPER" "Applicato" "image"
    // Every parameter is required by `qs ipc call`, so callers that do not care
    // about the icon pass "".
    Lock {}
    IpcHandler {
        target: "lock"
        function lock(): void { LockState.lock() }
    }

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

    // Menu (SUPER+SPACE) and standalone radioport, on the focused monitor
    IpcHandler {
        target: "sounds"
        function toggle(category: string): void { Sounds.toggle(category) }
        function test(category: string, file: string): void { Sounds.play(category, file) }
    }
    IpcHandler {
        target: "notifications"
        function toggle(): void { NotifState.togglePanel() }
        function toggleDnd(): void { NotifState.toggleDnd() }
        function clear(): void { NotifState.clear() }
    }
    IpcHandler {
        target: "launcher"
        function toggle(): void { LauncherState.toggleMenu() }
        function open(): void { LauncherState.openMenu() }
        function close(): void { LauncherState.closeMenu() }
        function cancelCapture(): void { LauncherState.captureCancelled() }
    }
    IpcHandler {
        target: "mediapanel"
        function toggle(): void { LauncherState.toggleMedia() }
        function open(): void { LauncherState.openMedia() }
        function close(): void { LauncherState.closeMedia() }
    }
    // Desktop HUD: on/off and above/below the windows (SUPER+ALT+L, then H or J)
    IpcHandler {
        target: "hud"
        function toggle(): void { HudState.toggle() }
        function toggleLayer(): void { HudState.toggleLayer() }
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

            Exclusions {                
                screen: modelData
                barHeight: 24
            }

            Drawers {
                screen: modelData
                drawerState: ds
            }

            SonarPanel {
                screen: modelData
            }

            SnipOverlay {
                screen: modelData
            }

            SnipBanner {
                screen: modelData
            }

            SnipRecordFrame {
                screen: modelData
            }

            KillOverlay {
                screen: modelData
            }

            HoloCall {
                screen: modelData
            }

            MessagesPanel {
                screen: modelData
            }

            ToastOverlay {
                screen: modelData
            }

            LauncherPanel {
                screen: modelData
            }

            MediaPanel {
                screen: modelData
            }

            HudOverlay {
                screen: modelData
            }
        }
    }
}

