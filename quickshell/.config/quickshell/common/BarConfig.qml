pragma Singleton

import QtQuick

QtObject {
    // Nome del monitor principale (taskbar completa)
    readonly property string primaryMonitorName: "DP-1"

    function isPrimary(screen): bool {
        return !!screen && screen.name === primaryMonitorName;
    }

    // Layout modulare in stile Config.bar di Caelestia
    //
    // Ogni voce è un semplice oggetto JS con almeno:
    //  - name: identificatore logico del modulo
    //
    // Il mapping name -> componente concreto è implementato in Bar.qml
    // tramite Repeater + DelegateChooser.

    // Sezione LEFT (workspaces, title, submap)
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

    // Sezione RIGHT monitor principale (DP-1): tray + audio + visualizer + mpris
    readonly property var entriesPrimaryRight: [
        { "name": "rightSection" }
    ]

    // Sezione RIGHT monitor secondario: system stats + power
    readonly property var entriesSecondaryRight: [
        { "name": "rightSection" }
    ]
}

