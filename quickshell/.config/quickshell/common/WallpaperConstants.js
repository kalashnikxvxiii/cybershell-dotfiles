.pragma library

// Hue-bucket ranges for color filter matching.
// Key: hex string shown in the FilterBar color row.
// Value: [hueMin, hueMax] in degrees (0-360).
// [-1, -1] = monochrome bucket - matched by saturation < 15%, not hue.
var colorBuckets = {
    "#ff0000": [0,    30],
    "#ff8800": [30,   55],
    "#ffff00": [55,   80],
    "#00ff00": [80,  160],
    "#0088ff": [160, 250],
    "#8800ff": [250, 290],
    "#ff00ff": [290, 330],
    "#888888": [-1,   -1]
}
