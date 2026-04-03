pragma Singleton

import QtQuick
import "Colors.js" as CP

// Colours.qml — servizio colori cyberpunk (Wallust + CP2077)
// Basato su Caelestia Colours.qml, esteso con semantica CP2077 completa.
//
// Accesso: import ".." (o import "." se nello stesso livello root)
// Tutte le proprietà sono readonly — aggiornate reattivamente da Wallust.

QtObject {
    id: root

    // ── Wallust (colori estratti dal wallpaper) ───────────────────────────
    property WallustColors wallust: WallustColors { }

    readonly property color bg:   wallust.bg
    readonly property color fg:   wallust.fg
    readonly property color glow: wallust.glow

    // ── Accenti CP2077 (statici) ──────────────────────────────────────────
    // Seguire la convenzione modulo:
    //   cyan=CPU/Network, magenta=Memory, yellow=Disk/Volume, red=Exit/Alert

    readonly property color accentPrimary:   CP.yellow    // #fcec0c — corpo/warning/money
    readonly property color accentSecondary: CP.cyan      // #00ffd2 — netrunner/tech
    readonly property color accentDanger:    CP.red       // #ff003c — pericolo/critico
    readonly property color accentOk:        CP.neon      // #39ff14 — ok/connesso
    readonly property color accentWarn:      CP.amber     // #f78b04 — warning caldo (non ancora critico)
    readonly property color accentMem:       CP.magenta   // #ea00d9 — memoria

    // ── Background modulare ───────────────────────────────────────────────
    readonly property color moduleBg:    layer(colorFromRgba(CP.moduleBg), 0)
    readonly property color moduleBgAlt: layer(colorFromRgba(CP.moduleBgAlt), 1)

    // ── Trasparenze canoniche ─────────────────────────────────────────────
    readonly property real baseOpacity:  0.92   // panel attivo
    readonly property real layerOpacity: 0.45   // layer sovrapposto
    readonly property real glowOpacity:  0.45   // MultiEffect shadowOpacity default
    readonly property real glowBlur:     0.75   // MultiEffect shadowBlur default

    // ── Scanline ──────────────────────────────────────────────────────────
    // Colore da usare per scanline overlays (scuro, suggerisce CRT)
    readonly property color scanlineColor: Qt.rgba(0, 0, 0, 1)

    // ── Bar ───────────────────────────────────────────────────────────────
    readonly property color barBg:         layer(bg, 0)
    readonly property color barBorder:     Qt.rgba(accentSecondary.r, accentSecondary.g, accentSecondary.b, 0.35)
    readonly property color barGlowLeft:   Qt.rgba(accentSecondary.r, accentSecondary.g, accentSecondary.b, 0.15)
    readonly property color barGlowCenter: Qt.rgba(accentPrimary.r, accentPrimary.g, accentPrimary.b, 0.50)
    readonly property color barGlowRight:  Qt.rgba(accentSecondary.r, accentSecondary.g, accentSecondary.b, 0.15)

    // ── Testo ─────────────────────────────────────────────────────────────
    readonly property color textPrimary:   fg
    readonly property color textSecondary: Qt.rgba(fg.r, fg.g, fg.b, 0.70)
    readonly property color textMuted:     Qt.rgba(fg.r, fg.g, fg.b, 0.45)

    // ── Funzioni di utilità ───────────────────────────────────────────────

    // Converte un Qt.rgba JS in un color QML puro
    function colorFromRgba(c) {
        return Qt.rgba(c.r, c.g, c.b, c.a)
    }

    // Luminanza percettiva (0..1)
    function luminance(c) {
        return Math.sqrt(0.299 * (c.r * c.r) + 0.587 * (c.g * c.g) + 0.114 * (c.b * c.b))
    }

    // Strato colore adattivo in base alla luminanza del bg.
    // depth 0 = superficie (opacity = baseOpacity)
    // depth > 0 = layer sovrapposto (opacity = layerOpacity), leggermente più chiaro su bg scuro
    function layer(c, depth) {
        if (depth === undefined) depth = 1
        var bgLum = luminance(wallust.bg)
        var factor = bgLum < 0.25
            ? 1.0 + 0.12 * depth   // bg scuro → schiarisce i layer
            : 1.0 - 0.08 * depth   // bg chiaro → scurisce per contrasto
        var r = Math.max(0, Math.min(1, c.r * factor))
        var g = Math.max(0, Math.min(1, c.g * factor))
        var b = Math.max(0, Math.min(1, c.b * factor))
        var a = depth === 0 ? baseOpacity : layerOpacity
        return Qt.rgba(r, g, b, a)
    }

    // Restituisce il colore di glow per un dato accento e opacità.
    // Usare con MultiEffect: shadowColor = Colours.glowFor(accent)
    function glowFor(accent, a) {
        var c = Qt.darker(accent, 1.0)
        return Qt.rgba(c.r, c.g, c.b, a !== undefined ? a : glowOpacity)
    }

    // Colore bordo per un pannello: accent al 55% di opacità
    function panelBorder(accent, a) {
        var c = Qt.darker(accent, 1.0)
        return Qt.rgba(c.r, c.g, c.b, a !== undefined ? a : 0.55)
    }

    // Bordo neon (default cyan)
    function neonBorder(a) {
        if (a === undefined) a = 0.35
        return Qt.rgba(accentSecondary.r, accentSecondary.g, accentSecondary.b, a)
    }

    // Bordo errore (rosso)
    function errorBorder(a) {
        if (a === undefined) a = 0.60
        return Qt.rgba(accentDanger.r, accentDanger.g, accentDanger.b, a)
    }

    // Canale rosso aberrazione cromatica a opacità a
    function aberrationRed(a) {
        return Qt.rgba(1, 0, 0.235, a !== undefined ? a : 0.55)
    }

    // Canale cyan aberrazione cromatica a opacità a
    function aberrationCyan(a) {
        return Qt.rgba(0, 1, 0.824, a !== undefined ? a : 0.55)
    }
}
