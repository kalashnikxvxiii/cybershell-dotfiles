// Colors.js — Canonical Cyberpunk 2077 palette + color utilities
//
// Source: in-game ink files (UI), modding community, ColorsWall, gwannon/alddesign.
// Usage: import "Colors.js" as CP
//
// Recommended fonts:
//   Oxanium  — HUD labels (Google Fonts, already in use)
//   Rajdhani — official CP2077 UI font (Google Fonts)
//   Cyberpunk / Blender — display/logo

// ── Primary CP2077 palette (official) ────────────────────────────────────

// Yellow — dominant UI color (corpo/warning/money)
var yellow    = "#fcec0c"   // ColorsWall official
var yellowAlt = "#f9f002"   // gwannon/gwikicom variant
var yellowUI  = "#f3e600"   // in-game UI dark mode

// Cyan — netrunner/freedom/tech
var cyan      = "#00ffd2"   // main UI panel cyan (project default)
var cyan2     = "#25e1ed"   // saturated primary, official CP2077
var teal      = "#39c4b6"   // deep teal accent (less saturated)
var cyanBright = "#02d7f2"  // ColorsWall variant

// Red — violence/danger/street
var red       = "#ff003c"   // UI red bright (alert, critical — already in use)
var redDark   = "#c5003c"   // official UI red (less saturated)
var redShadow = "#880425"   // shadow red / danger fill

// Magenta — netrunner/augmentation accent
var magenta   = "#ea00d9"   // neon magenta (Street Kid / netrunner)
var magentaAlt = "#ed1e79"  // mid-range magenta accent

// Greens
var neon      = "#39ff14"   // neon green (terminal/matrix — already in use)
var olive     = "#9a9f17"   // dirty yellow-green (data display / chart)

// Authority / warmth
var amber     = "#f78b04"   // warm authority amber (Blade Runner / warm warning)

// Backgrounds
var black     = "#000000"   // pure black
var void_     = "#0a060e"   // main background (near-black blue-violet)
var void2     = "#00060e"   // title card deep blue-black
var panelBg   = "#0c5f74"   // gwannon deep blue panel
var dark      = "#333333"   // generic dark grey

// Neutrals
var white     = "#ffffff"
var blue      = "#0c5f74"   // alias for panelBg
var green     = "#446d44"   // dark green (rarely used)
var purple    = "#aa00aa"   // generic purple
var orange    = "#ff9800"   // standard orange

// ── Derived UI values (design-system) ────────────────────────────────────

// Module backgrounds: rgba(void_, opacity)
var moduleBg    = Qt.rgba(0.039, 0.024, 0.055, 0.92)   // #0a060e at 92%
var moduleBgAlt = Qt.rgba(0.047, 0.024, 0.071, 0.85)   // alternate layer

// Wallust-driven (updated at runtime by WallustColors.qml)
var wbBg   = "#050309"
var wbFg   = "#FF84AC"
var wbGlow = "#E5456F"

// ── Helper functions ─────────────────────────────────────────────────────

// Returns an rgba variant of a hex color at opacity a (0..1)
function alpha(hex, a) {
    var c = Qt.darker(hex, 1.0)
    return Qt.rgba(c.r, c.g, c.b, a)
}

// Linear interpolation between two colors (t: 0=c1, 1=c2)
function mix(c1, c2, t) {
    var a = Qt.darker(c1, 1.0)
    var b = Qt.darker(c2, 1.0)
    return Qt.rgba(
        a.r + (b.r - a.r) * t,
        a.g + (b.g - a.g) * t,
        a.b + (b.b - a.b) * t,
        a.a + (b.a - a.a) * t
    )
}

// Lightens a hex color by amount (0..1)
function lighten(hex, amount) {
    var c = Qt.darker(hex, 1.0)
    return Qt.rgba(
        Math.min(1, c.r + amount),
        Math.min(1, c.g + amount),
        Math.min(1, c.b + amount),
        c.a
    )
}

// Darkens a hex color by amount (0..1)
function darken(hex, amount) {
    var c = Qt.darker(hex, 1.0)
    return Qt.rgba(
        Math.max(0, c.r - amount),
        Math.max(0, c.g - amount),
        Math.max(0, c.b - amount),
        c.a
    )
}

// Red channel for chromatic aberration (#ff003c at opacity a)
function aberrationRed(a) {
    return Qt.rgba(1, 0, 0.235, a !== undefined ? a : 0.55)
}

// Cyan channel for chromatic aberration (#00ffd2 at opacity a)
function aberrationCyan(a) {
    return Qt.rgba(0, 1, 0.824, a !== undefined ? a : 0.55)
}
