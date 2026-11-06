// wallpaper.qml - the desktop wallpaper, the contrast scrim and the picker
// (playlist, transition editor) as their own Quickshell process: a crash in the
// wallpaper plugin, video decode or WPE preview no longer takes the whole shell
// down. Run by systemd: qs@wallpaper.service (systemctl --user restart qs@wallpaper).
// While it restarts awww-daemon, on the Background layer, stays visible.
// The main shell reaches it only through files: /tmp/qs-wallpicker-toggle in,
// $XDG_RUNTIME_DIR/qs-wallpaper-open out (see WallpaperState and DockConfig).
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import CyberWallpaper
import QtQuick
import "common"
import "modules/wallpaper"

ShellRoot {
    // Dim behind Zen (SUPER+ALT+L, then Z)
    IpcHandler {
        target: "contrast-scrim"
        function toggle(): void { WallpaperState.scrimEnabled = !WallpaperState.scrimEnabled }
    }

    Variants {
        model: Quickshell.screens

        Scope {
            required property var modelData

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

            WallpaperPicker {
                screen: modelData
            }
        }
    }
}
