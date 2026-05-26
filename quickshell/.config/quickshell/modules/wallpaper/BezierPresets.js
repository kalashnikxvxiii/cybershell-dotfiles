.pragma library

var PRESETS = [
    { name: "ease",           x1: 0.25, y1:  0.10, x2: 0.25, y2:  1.00 },
    { name: "easeIn",         x1: 0.42, y1:  0.00, x2: 1.00, y2:  1.00 },
    { name: "easeOut",        x1: 0.00, y1:  0.00, x2: 0.58, y2:  1.00 },
    { name: "easeInOut",      x1: 0.42, y1:  0.00, x2: 0.58, y2:  1.00 },
    { name: "easeInSine",     x1: 0.12, y1:  0.00, x2: 0.39, y2:  0.00 },
    { name: "easeOutSine",    x1: 0.61, y1:  1.00, x2: 0.88, y2:  1.00 },
    { name: "easeInOutSine",  x1: 0.37, y1:  0.00, x2: 0.63, y2:  1.00 },
    { name: "easeInQuad",     x1: 0.11, y1:  0.00, x2: 0.50, y2:  0.00 },
    { name: "easeOutQuad",    x1: 0.50, y1:  1.00, x2: 0.89, y2:  1.00 },
    { name: "easeInOutQuad",  x1: 0.45, y1:  0.00, x2: 0.55, y2:  1.00 },
    { name: "easeInCubic",    x1: 0.32, y1:  0.00, x2: 0.67, y2:  0.00 },
    { name: "easeOutCubic",   x1: 0.33, y1:  1.00, x2: 0.68, y2:  1.00 },
    { name: "easeInOutCubic", x1: 0.65, y1:  0.00, x2: 0.35, y2:  1.00 },
    { name: "easeInExpo",     x1: 0.70, y1:  0.00, x2: 0.84, y2:  0.00 },
    { name: "easeOutExpo",    x1: 0.16, y1:  1.00, x2: 0.30, y2:  1.00 },
    { name: "easeInOutExpo",  x1: 0.87, y1:  0.00, x2: 0.13, y2:  1.00 },
    { name: "easeInBack",     x1: 0.36, y1:  0.00, x2: 0.66, y2: -0.56 },
    { name: "easeOutBack",    x1: 0.34, y1:  1.56, x2: 0.64, y2:  1.00 },
    { name: "easeInOutBack",  x1: 0.68, y1: -0.60, x2: 0.32, y2:  1.60 }
]

function tolerantMatch(bezierString, preset) {
    var p = bezierString.split(",")
    if (p.length !== 4) return false
    return Math.abs(parseFloat(p[0]) - preset.x1) < 0.012
        && Math.abs(parseFloat(p[1]) - preset.y1) < 0.012
        && Math.abs(parseFloat(p[2]) - preset.x2) < 0.012
        && Math.abs(parseFloat(p[3]) - preset.y2) < 0.012
}

function formatBezier(x1, y1, x2, y2) {
    return x1.toFixed(3) + "," + y1.toFixed(3) + "," + x2.toFixed(3) + "," + y2.toFixed(3)
}

function matchesAnyBuiltin(bezierString) {
    for (var i = 0; i < PRESETS.length; i++) {
        if (tolerantMatch(bezierString, PRESETS[i])) return true
    }
    return false
}