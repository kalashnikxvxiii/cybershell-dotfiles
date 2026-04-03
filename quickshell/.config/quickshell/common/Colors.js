// Colors.js — Palette Cyberpunk 2077 canonica + utilità colore
//
// Fonte: file ink del gioco (UI), modding community, ColorsWall, gwannon/alddesign.
// Usage: import "Colors.js" as CP
//
// Fonts consigliati:
//   Oxanium  — label HUD (Google Fonts, già in uso)
//   Rajdhani — font UI ufficiale CP2077 (Google Fonts)
//   Cyberpunk / Blender — display/logo

// ── Palette primaria CP2077 (ufficiale) ──────────────────────────────────

// Giallo — colore dominante UI (corpo/warning/money)
var yellow    = "#fcec0c"   // ColorsWall ufficiale
var yellowAlt = "#f9f002"   // gwannon/gwikicom variant
var yellowUI  = "#f3e600"   // in-game UI dark mode

// Cyan — netrunner/libertà/tech
var cyan      = "#00ffd2"   // UI panel cyan principale (progetto)
var cyan2     = "#25e1ed"   // saturato primario CP2077 ufficiale
var teal      = "#39c4b6"   // deep teal accent (meno saturo)
var cyanBright = "#02d7f2"  // ColorsWall variant

// Rosso — violenza/pericolo/strada
var red       = "#ff003c"   // UI red bright (alert, critical — già in uso)
var redDark   = "#c5003c"   // rosso ufficiale UI (meno saturato)
var redShadow = "#880425"   // shadow red / danger fill

// Magenta — netrunner/augumentation accent
var magenta   = "#ea00d9"   // neon magenta (Street Kid / netrunner)
var magentaAlt = "#ed1e79"  // magenta accento mid

// Verdi
var neon      = "#39ff14"   // neon green (terminale/matrix — già in uso)
var olive     = "#9a9f17"   // dirty yellow-green (data display / chart)

// Autorità / calore
var amber     = "#f78b04"   // warm authority amber (Blade Runner / warning caldo)

// Backgrounds
var black     = "#000000"   // pure black
var void_     = "#0a060e"   // background principale (quasi-nero blu-viola)
var void2     = "#00060e"   // title card deep blue-black
var panelBg   = "#0c5f74"   // gwannon deep blue panel
var dark      = "#333333"   // dark grigio generico

// Neutri
var white     = "#ffffff"
var blue      = "#0c5f74"   // alias panelBg
var green     = "#446d44"   // verde scuro (usato raramente)
var purple    = "#aa00aa"   // viola generico
var orange    = "#ff9800"   // arancio standard

// ── Valori derivati UI (design-system) ───────────────────────────────────

// Sfondi modulo: rgba(void_, opacity)
var moduleBg    = Qt.rgba(0.039, 0.024, 0.055, 0.92)   // #0a060e at 92%
var moduleBgAlt = Qt.rgba(0.047, 0.024, 0.071, 0.85)   // strato alternato

// Wallust-driven (aggiornati a runtime da WallustColors.qml)
var wbBg   = "#050309"
var wbFg   = "#FF84AC"
var wbGlow = "#E5456F"

// ── Funzioni helper ───────────────────────────────────────────────────────

// Restituisce una variante rgba di un colore hex a opacità a (0..1)
function alpha(hex, a) {
    var c = Qt.darker(hex, 1.0)
    return Qt.rgba(c.r, c.g, c.b, a)
}

// Interpolazione lineare tra due colori (t: 0=c1, 1=c2)
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

// Schiarisce un colore hex di amount (0..1)
function lighten(hex, amount) {
    var c = Qt.darker(hex, 1.0)
    return Qt.rgba(
        Math.min(1, c.r + amount),
        Math.min(1, c.g + amount),
        Math.min(1, c.b + amount),
        c.a
    )
}

// Scurisce un colore hex di amount (0..1)
function darken(hex, amount) {
    var c = Qt.darker(hex, 1.0)
    return Qt.rgba(
        Math.max(0, c.r - amount),
        Math.max(0, c.g - amount),
        Math.max(0, c.b - amount),
        c.a
    )
}

// Canale rosso aberrazione cromatica (#ff003c a opacità a)
function aberrationRed(a) {
    return Qt.rgba(1, 0, 0.235, a !== undefined ? a : 0.55)
}

// Canale cyan aberrazione cromatica (#00ffd2 a opacità a)
function aberrationCyan(a) {
    return Qt.rgba(0, 1, 0.824, a !== undefined ? a : 0.55)
}
