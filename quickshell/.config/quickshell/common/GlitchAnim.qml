// GlitchAnim.qml — Stepped glitch animation on text + shift
//
// Triggers: call restart() from an external HoverHandler.
// Backward compatible: no existing properties were removed.
//
// Required targets:
//   labelTarget   — Text that receives color changes
//   shiftTarget   — Translate that receives x offsets
//
// Colors (with cyberpunk defaults):
//   baseColor     — base color (start and end)      default: CP.cyan
//   c1            — first glitch color              default: CP.magenta
//   c2            — second glitch color             default: CP.yellow
//   c3            — third color (6-step only)       default: CP.cyan
//
// Offsets:
//   x1 / x2 / x3 / x4   — x offset per step 1..4  default: 4,-4,3,-2
//
// Intensity:
//   intensity     — multiplier for x offsets        default: 1.0
//   (e.g. intensity: 1.5 amplifies shifts by 50%)
//
// Optional chromatic aberration:
//   aberrationTarget — if set, toggles _glitching on the target Item
//   during the middle steps of the glitch. The Item must expose property bool _glitching.
//   (e.g. aberrationTarget: root — enables aberration on root during the glitch)
//
// Modes:
//   shortMode: false (default) — 6 step, finalPause 88ms  — WindowTitle/MprisModule
//   shortMode: true            — 4 step, use finalPause: 174 — Submap
//
// Examples:
//   // Standard
//   GlitchAnim { id: g; labelTarget: lbl; shiftTarget: sh }
//   HoverHandler { onHoveredChanged: if (hovered) g.restart() }
//
//   // With chromatic aberration
//   GlitchAnim { id: g; labelTarget: lbl; shiftTarget: sh
//                aberrationTarget: root }
//
//   // Subtle glitch (reduced intensity)
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

    // ── Colors ────────────────────────────────────────────────────────────
    property color baseColor: CP.cyan
    property color c1:        CP.magenta
    property color c2:        CP.yellow
    property color c3:        CP.cyan

    // ── Offsets ───────────────────────────────────────────────────────────
    property int x1:  4
    property int x2: -4
    property int x3:  3
    property int x4: -2

    // ── Intensity (0.1..3.0) — scales x offsets ────────────────────────────
    property real intensity: 1.0

    // ── Optional chromatic aberration ──────────────────────────────────────
    // If set, this Item gets _glitching=true during the middle steps
    property var aberrationTarget: null

    // ── Dual-shift convergence (chromatic aberration on enter) ─────────────
    // leftShiftTarget / rightShiftTarget — two Translates that converge to 0
    // converge: true — x1..x4 represent decreasing magnitudes
    //  Step 0: left=-x1, right=+x1 (initial spread)
    //  Step 1: left=-x2, right=+x2 ...
    //  Final: both at 0
    property var    leftShiftTarget:    null
    property var    rightShiftTarget:    null
    property bool   converge:           false

    // ── Mode ─────────────────────────────────────────────────────────────
    property bool shortMode:  false
    property int  finalPause: 88

    // ── Explicit reset (use instead of stop() to avoid stuck states) ──────
    function reset() {
        stop()
        if (labelTarget)        labelTarget.color           =   baseColor
        if (shiftTarget)        shiftTarget.x               =   0
        if (leftShiftTarget)    leftShiftTarget.x           =   0
        if (rightShiftTarget)   rightShiftTarget.x          =   0
        if (aberrationTarget)   aberrationTarget._glitching =   false
    }
    // ── Sequence ──────────────────────────────────────────────────────────

    // Step 0: reset + initial spread (converge)
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

    // Step 3 (long mode only)
    ScriptAction { script: {
        if (!root.shortMode) {
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

    // Step 4 (long mode only)
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

    // Final: full reset
    ScriptAction { script: {
        if (root.aberrationTarget) root.aberrationTarget._glitching = false
        if (root.labelTarget) root.labelTarget.color = root.baseColor
        if (root.shiftTarget) root.shiftTarget.x = 0
        if (root.leftShiftTarget) root.leftShiftTarget.x = 0
        if (root.rightShiftTarget) root.rightShiftTarget.x = 0
    }}
    PauseAnimation { duration: root.finalPause }
}
