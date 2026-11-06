// media.qml - the standalone Radioport (MediaPanel) as its own Quickshell
// process: a crash in it (cyberaudio level/scope providers, MPRIS, cover
// decode) no longer takes the whole shell down. Run by systemd:
// qs@media.service (systemctl --user restart qs@media).
// The main shell forwards `qs ipc call mediapanel ...` here; the picked player
// and the EQ state are shared through files (Players, AudioControlState).
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import "common"
import "modules/media"

ShellRoot {
    IpcHandler {
        target: "mediapanel"
        function toggle(): void { LauncherState.toggleMedia() }
        function open(): void { LauncherState.openMedia() }
        function close(): void { LauncherState.closeMedia() }
    }

    // The main shell already follows the player for per-station EQ
    Component.onCompleted: AudioControlState.stationSync = false

    // Hyprland's state loads lazily, on first use: touch it at startup or the
    // first open finds no focused monitor and stays invisible. Not with
    // Hyprland.refreshMonitors(), which at startup leaves focusedMonitor null
    // for good (verified)
    readonly property var _focusedMonitor: Hyprland.focusedMonitor

    Variants {
        model: Quickshell.screens

        MediaPanel {
            required property var modelData
            screen: modelData
        }
    }
}
