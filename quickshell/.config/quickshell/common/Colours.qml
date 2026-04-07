pragma Singleton

import QtQuick
import "Colors.js" as CP

// Colours.qml — cyberpunk color service (Wallust + CP2077)
// Based on Caelestia Colours.qml, extended with full CP2077 semantic colors.
//
// Access: import ".." (or import "." if at the same root level)
// All properties are readonly — reactively updated by Wallust.

QtObject {
    id: root

    // ── Wallust (colors extracted from wallpaper) ─────────────────────────
    property WallustColors wallust: WallustColors { }

    readonly property color bg:   wallust.bg
    readonly property color fg:   wallust.fg
    readonly property color glow: wallust.glow

    // ── CP2077 accents (static) ────────────────────────────────────────────
    // Follow the module color convention:
    //   cyan=CPU/Network, magenta=Memory, yellow=Disk/Volume, red=Exit/Alert

    readonly property color accentPrimary:   CP.yellow    // #fcec0c — corpo/warning/money
    readonly property color accentSecondary: CP.cyan      // #00ffd2 — netrunner/tech
    readonly property color accentDanger:    CP.red       // #ff003c — danger/critical
    readonly property color accentOk:        CP.neon      // #39ff14 — ok/connected
    readonly property color accentWarn:      CP.amber     // #f78b04 — warm warning (not critical yet)
    readonly property color accentMem:       CP.magenta   // #ea00d9 — memory

    // ── Modular backgrounds ───────────────────────────────────────────────
    readonly property color moduleBg:    layer(colorFromRgba(CP.moduleBg), 0)
    readonly property color moduleBgAlt: layer(colorFromRgba(CP.moduleBgAlt), 1)

    // ── Canonical opacities ────────────────────────────────────────────────
    readonly property real baseOpacity:  0.92   // active panel
    readonly property real layerOpacity: 0.45   // overlay layer
    readonly property real glowOpacity:  0.45   // MultiEffect shadowOpacity default
    readonly property real glowBlur:     0.75   // MultiEffect shadowBlur default

    // ── Scanline ──────────────────────────────────────────────────────────
    // Color for scanline overlays (dark, evokes that CRT feel)
    readonly property color scanlineColor: Qt.rgba(0, 0, 0, 1)

    // ── Bar ───────────────────────────────────────────────────────────────
    readonly property color barBg:         layer(bg, 0)
    readonly property color barBorder:     Qt.rgba(accentSecondary.r, accentSecondary.g, accentSecondary.b, 0.35)
    readonly property color barGlowLeft:   Qt.rgba(accentSecondary.r, accentSecondary.g, accentSecondary.b, 0.15)
    readonly property color barGlowCenter: Qt.rgba(accentPrimary.r, accentPrimary.g, accentPrimary.b, 0.50)
    readonly property color barGlowRight:  Qt.rgba(accentSecondary.r, accentSecondary.g, accentSecondary.b, 0.15)

    // ── Text ──────────────────────────────────────────────────────────────
    readonly property color textPrimary:   fg
    readonly property color textSecondary: Qt.rgba(fg.r, fg.g, fg.b, 0.70)
    readonly property color textMuted:     Qt.rgba(fg.r, fg.g, fg.b, 0.45)

    // ── Utility functions ─────────────────────────────────────────────────

    // Converts a Qt.rgba JS value into a pure QML color
    function colorFromRgba(c) {
        return Qt.rgba(c.r, c.g, c.b, c.a)
    }

    // Perceptual luminance (0..1)
    function luminance(c) {
        return Math.sqrt(0.299 * (c.r * c.r) + 0.587 * (c.g * c.g) + 0.114 * (c.b * c.b))
    }

    // Adaptive color layer based on background luminance.
    // depth 0 = surface (opacity = baseOpacity)
    // depth > 0 = overlay layer (opacity = layerOpacity), slightly lighter on dark bg
    function layer(c, depth) {
        if (depth === undefined) depth = 1
        var bgLum = luminance(wallust.bg)
        var factor = bgLum < 0.25
            ? 1.0 + 0.12 * depth   // dark bg → lighten the layers
            : 1.0 - 0.08 * depth   // light bg → darken for contrast
        var r = Math.max(0, Math.min(1, c.r * factor))
        var g = Math.max(0, Math.min(1, c.g * factor))
        var b = Math.max(0, Math.min(1, c.b * factor))
        var a = depth === 0 ? baseOpacity : layerOpacity
        return Qt.rgba(r, g, b, a)
    }

    // Returns the glow color for a given accent and opacity.
    // Use with MultiEffect: shadowColor = Colours.glowFor(accent)
    function glowFor(accent, a) {
        var c = Qt.darker(accent, 1.0)
        return Qt.rgba(c.r, c.g, c.b, a !== undefined ? a : glowOpacity)
    }

    // Panel border color: accent at 55% opacity
    function panelBorder(accent, a) {
        var c = Qt.darker(accent, 1.0)
        return Qt.rgba(c.r, c.g, c.b, a !== undefined ? a : 0.55)
    }

    // Neon border (defaults to cyan)
    function neonBorder(a) {
        if (a === undefined) a = 0.35
        return Qt.rgba(accentSecondary.r, accentSecondary.g, accentSecondary.b, a)
    }

    // Error border (red)
    function errorBorder(a) {
        if (a === undefined) a = 0.60
        return Qt.rgba(accentDanger.r, accentDanger.g, accentDanger.b, a)
    }

    // Red channel for chromatic aberration at opacity a
    function aberrationRed(a) {
        return Qt.rgba(1, 0, 0.235, a !== undefined ? a : 0.55)
    }

    // Cyan channel for chromatic aberration at opacity a
    function aberrationCyan(a) {
        return Qt.rgba(0, 1, 0.824, a !== undefined ? a : 0.55)
    }
}
