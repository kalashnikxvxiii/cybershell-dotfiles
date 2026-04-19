.pragma library

var tabLabels = ["CYBERDECK", "MEDIA", "CYBERWARE"]

// Default apps — only used if applauncher-order.json doesn't exist yet (first launch).
var defaultApps = [
    { icon: "discord",          exec: "discord",          pinned: false },
    { icon: "steam",            exec: "steam",            pinned: false },
    { icon: "spotify-launcher", exec: "spotify-launcher", pinned: false },
    { icon: "kitty",            exec: "kitty",            pinned: false }
]
