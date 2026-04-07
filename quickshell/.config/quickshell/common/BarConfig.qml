pragma Singleton

import QtQuick

QtObject {
    // Primary monitor name (gets the full taskbar)
    readonly property string primaryMonitorName: "DP-1"

    function isPrimary(screen): bool {
        return !!screen && screen.name === primaryMonitorName;
    }

    // Modular layout a la Caelestia's Config.bar
    //
    // Each entry is a plain JS object with at least:
    //  - name: logical module identifier
    //
    // The name -> concrete component mapping lives in Bar.qml
    // via Repeater + DelegateChooser.

    // LEFT section (workspaces, title, submap)
    readonly property var entriesPrimaryLeft: [
        { "name": "leftSection" }
    ]

    readonly property var entriesSecondaryLeft: [
        { "name": "leftSection" }
    ]

    readonly property var entriesPrimaryCenter: [
        { "name": "centerSection" }
    ]

    readonly property var entriesSecondaryCenter: [
        { "name": "centerSection" }
    ]

    // RIGHT section, primary monitor (DP-1): tray + audio + visualizer + mpris
    readonly property var entriesPrimaryRight: [
        { "name": "rightSection" }
    ]

    // RIGHT section, secondary monitor: system stats + power
    readonly property var entriesSecondaryRight: [
        { "name": "rightSection" }
    ]
}

