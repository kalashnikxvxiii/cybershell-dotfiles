.pragma library

var primaryMonitorName = "DP-1"

// Same signature as the old QML version — QML objects passed to
// .pragma library functions remain accessible, so screen.name works.
function isPrimary(screen) {
    return !!screen && screen.name === primaryMonitorName
}

var entriesPrimaryLeft     = [{ "name": "leftSection" }]
var entriesSecondaryLeft   = [{ "name": "leftSection" }]
var entriesPrimaryCenter   = [{ "name": "centerSection" }]
var entriesSecondaryCenter = [{ "name": "centerSection" }]
var entriesPrimaryRight    = [{ "name": "rightSection" }]
var entriesSecondaryRight  = [{ "name": "rightSection" }]
