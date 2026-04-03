// GlitchAnim.qml — Animazione glitch stepped su testo + shift
//
// Triggers: chiama restart() da HoverHandler esterno.
// Retrocompatibile: nessuna property esistente è stata rimossa.
//
// Targets obbligatori:
//   labelTarget   — Text che riceve i cambi colore
//   shiftTarget   — Translate che riceve gli spostamenti x
//
// Colori (con default cyberpunk):
//   baseColor     — colore base (inizio e fine)     default: CP.cyan
//   c1            — primo colore glitch             default: CP.magenta
//   c2            — secondo colore glitch           default: CP.yellow
//   c3            — terzo colore (solo 6 step)      default: CP.cyan
//
// Spostamenti:
//   x1 / x2 / x3 / x4   — offset x per step 1..4  default: 4,-4,3,-2
//
// Intensità:
//   intensity     — moltiplicatore degli offset x   default: 1.0
//   (esempio: intensity: 1.5 amplifica gli shift del 50%)
//
// Aberrazione cromatica opzionale:
//   aberrationTarget — se impostato, toggling _glitching sull'Item indicato
//   durante i passi centrali del glitch. L'Item deve esporre property bool _glitching.
//   (esempio: aberrationTarget: root  — attiva aberrazione su root durante il glitch)
//
// Modalità:
//   shortMode: false (default) — 6 step, finalPause 88ms  — WindowTitle/MprisModule
//   shortMode: true            — 4 step, usare finalPause: 174 — Submap
//
// Esempi:
//   // Standard
//   GlitchAnim { id: g; labelTarget: lbl; shiftTarget: sh }
//   HoverHandler { onHoveredChanged: if (hovered) g.restart() }
//
//   // Con aberrazione cromatica
//   GlitchAnim { id: g; labelTarget: lbl; shiftTarget: sh
//                aberrationTarget: root }
//
//   // Con intensità ridotta (glitch sottile)
//   GlitchAnim { id: g; labelTarget: lbl; shiftTarget: sh; intensity: 0.6 }
//
//   // Short mode
//   GlitchAnim { id: g; labelTarget: lbl; shiftTarget: sh
//                shortMode: true; x1: 3; x2: -3; finalPause: 174 }

import QtQuick
import "Colors.js" as CP

SequentialAnimation {
    id: root

    running:    false
    loops:      1

    // ── Targets ───────────────────────────────────────────────────────────
    property var labelTarget
    property var shiftTarget

    // ── Colori ────────────────────────────────────────────────────────────
    property color baseColor: CP.cyan
    property color c1:        CP.magenta
    property color c2:        CP.yellow
    property color c3:        CP.cyan

    // ── Spostamenti ───────────────────────────────────────────────────────
    property int x1:  4
    property int x2: -4
    property int x3:  3
    property int x4: -2

    // ── Intensità (0.1..3.0) — scala gli offset x ─────────────────────────
    property real intensity: 1.0

    // ── Aberrazione cromatica opzionale ───────────────────────────────────
    // Se impostato, questo Item riceve _glitching=true durante i passi centrali
    property var aberrationTarget: null

    // ── Dual-shift convergenza (aberrazione cromatica in entrata) ────────────
    // leftShifTarget / rightShiftTarget - due Translate che convergono a 0
    // converge: true - x1..x4 rappresentano magnitudini decrescenti
    //  Step 0: left=-x1, right=+x1 (spread iniziale)
    //  Step 1: left=-x2, rioght=+x2 ...
    //  Finale: entrambiu a 0
    property var    leftShiftTarget:    null
    property var    rightShiftTarget:    null
    property bool   converge:           false

    // ── Modalità ──────────────────────────────────────────────────────────
    property bool shortMode:  false
    property int  finalPause: 88

    // ── Reset esplicito (usa invece di stop() per evitare stati bloccati) ───
    function reset() {
        stop()
        if (labelTarget)        labelTarget.color           =   baseColor
        if (shiftTarget)        shiftTarget.x               =   0
        if (leftShiftTarget)    leftShiftTarget.x           =   0
        if (rightShiftTarget)   rightShiftTarget.x          =   0
        if (aberrationTarget)   aberrationTarget._glitching =   false
    }
    // ── Sequenza ──────────────────────────────────────────────────────────

    // Step 0: reset + spread iniziale (converge)
    ScriptAction { script: {
        if (root.aberrationTarget) root.aberrationTarget._glitching = false
        if (root.labelTarget) root.labelTarget.color = root.baseColor
        if (root.converge) {
            var mag = Math.round(Math.abs(root.x1) * root.intensity)
            if (root.leftShiftTarget) root.leftShiftTarget.x = -mag
            if (root.rightShiftTarget) root.rightShiftTarget.x = mag
        }
        if (root.shiftTarget) root.shiftTarget.x = 0
    }}
    PauseAnimation { duration: 30 }

    // Step 1
    ScriptAction { script: {
        if (root.aberrationTarget) root.aberrationTarget._glitching = true
        if (root.labelTarget) root.labelTarget.color = root.c1
        if (root.shiftTarget) root.shiftTarget.x = Math.round(root.x1 * root.intensity)
        if (root.converge) {
            var mag = Math.round(Math.abs(root.x2) * root.intensity)
            if (root.leftShiftTarget) root.leftShiftTarget.x = -mag
            if (root.rightShiftTarget) root.rightShiftTarget.x = mag
        }
    }}
    PauseAnimation { duration: 42 }

    // Step 3 (solo long mode)
    ScriptAction { script: {
        if (!root.sortMode) {
            if (root.labelTarget) root.labelTarget.color = root.c3
            if (root.shiftTarget) root.shiftTarget.x = Math.round(root.x3 * root.intensity)
        }
        if (root.converge && !root.shortMode) {
            var mag = Math.round(Math.abs(root.x4) * root.intensity)
            if (root.leftShiftTarget) root.leftShiftTarget.x = -mag
            if (root.rightShiftTarget) root.rightShiftTarget.x = mag
        }
    }}
    PauseAnimation { duration: root.shortMode ? 0 : 42 }

    // Step 4 (solo long mode)
    ScriptAction { script: {
        if (!root.shortMode) {
            if (root.labelTarget) root.labelTarget.color = root.c1
            if (root.shiftTarget) root.shiftTarget.x = Math.round(root.x4 * root.intensity)
        }
        if (root.converge && !root.shortMode) {
            if (root.leftShiftTarget) root.leftShiftTarget.x = 0
            if (root.rightShiftTarget) root.rightShiftTarget.x = 0
        }
    }}
    PauseAnimation { duration: root.shortMode ? 0 : 42 }

    // Finale: ripristino completo
    ScriptAction { script: {
        if (root.aberrationTarget) root.aberrationTarget._glitching = false
        if (root.labelTarget) root.labelTarget.color = root.baseColor
        if (root.shiftTarget) root.shiftTarget.x = 0
        if (root.leftShiftTarget) root.leftShiftTarget.x = 0
        if (root.rightShiftTarget) root.rightShiftTarget.x = 0
    }}
    PauseAnimation { duration: root.finalPause }
}
