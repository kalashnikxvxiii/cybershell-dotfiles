// GlitchEffect.qml — Three independent glitch effects in one component
// Inspired by github.com/xendak/nierlock
//
// Usage:
// GlitchEffect {
//      anchors.fill: parent
//
//      // 1) Horizontal scanlines
//      linesEnabled: true
//      linesCount: 8
//
//      // 2) Text glitch — set sourceText, read glitchedText and textOffset
//      textGlitchActive: true
//      sourceText: "HELLO WORLD"
//      // in your Text { text: myGlitch.glitchedText; x: myGlitch.textOffset }
//
//      // 3) Screen tear — set tearSourceItem, then call triggerTear()
//      tearSourceItem: myContentItem
//}

import QtQuick

Item {
    id: root

    // =======================================================
    // EFFECT 1: GLITCH LINES — animated horizontal scanlines
    // =======================================================
    //
    // Thin rectangles (h=1) that sweep across the screen
    // with random Y position, width, opacity, and direction.
    // Infinite loop with random pauses between passes.

    property bool linesEnabled:         false               // enable/disable the lines
    property int  linesCount:           8                   // how many simultaneous lines
    property color linesColor:          "#1A1A2E"         // line color
    property real linesMinWidth:        100                 // minimum width (px)
    property real linesMaxWidth:        300                 // maximum width (px)
    property real linesMaxOpacity:      0.5                 // max reachable opacity
    property real linesMaxPause:        5000                // max pause between passes (ms)
    property real linesBaseSpeed:       1000                // base traversal duration (ms)
    property real linesSpeedVariation:  1200                // random duration variation (ms)

    Repeater {
        model: root.linesEnabled ? root.linesCount : 0

        Rectangle {
            id: lineRect
            parent: root
            height: 1
            color: root.linesColor
            opacity: 0

            SequentialAnimation {
                loops: Animation.Infinite
                running: true

                // Random pause before the next pass
                PauseAnimation { duration: Math.random() * root.linesMaxPause }

                // Randomize line properties
                ScriptAction {
                    script: {
                        const goRight = Math.random() > 0.5
                        lineRect.width = root.linesMinWidth
                                        + Math.random() * (root.linesMaxWidth - root.linesMinWidth)
                        lineRect.y = Math.random() * root.height
                        lineRect.opacity = 0.2
                                            + Math.random() * (root.linesMaxOpacity - 0.2)
                        lineMoveAnim.from = goRight ? -lineRect.width : root.width
                        lineMoveAnim.to   = goRight ? root.width : -lineRect.width
                        lineMoveAnim.duration = root.linesBaseSpeed
                                                + Math.random() * root.linesSpeedVariation
                    }
                }

                // Horizontal sweep
                NumberAnimation {
                    id: lineMoveAnim
                    target: lineRect
                    property: "x"
                    easing.type: Easing.Linear
                }

                // Hide at end of pass
                PropertyAction { target: lineRect; property: "opacity"; value: 0 }
            }
        }
    }

    // ========================================================
    // EFFECT 2: TEXT GLITCH — jitter + character substitution
    // ========================================================
    //
    // Set sourceText with the original text.
    // Read the output properties to apply to your Text:
    //      - glitchedText:     text with randomly substituted characters
    //      - textOffset:       main text X offset (jitter)
    //      - shadowOffset:     recommended shadow X offset (40% of jitter)
    //
    // Example:
    //      Text { text: myGlitch.glitchedText; x: myGlitch.textOffset }
    //      Text { text: myGlitch.glitchedText; x: myGlitch.shadowOffset; opacity: 0.3 }

    property bool   textGlitchActive:       false   // enable/disable text glitch
    property string sourceText:             ""      // original input text
    property int    textGlitchRate:         2       // apply glitch every N ticks (lower = more frequent)
    property real   textGlitchMaxOfs:       6       // max X offset in pixels
    property real   textGlitchSubChance:    0.35    // character substitution probability (0-1)
    property string glitchCharPool:                 // substitution character pool
        "█▓▒░│┤╡╢╖╕╣║╗╝╜╛┐└╒╓╫╪┘┌"
    property int    textGlitchInterval:     55      // timer interval in ms

    // --- Output (bind your Text elements to these) ---
    readonly property string    glitchedText:   _gText
    readonly property real      textOffset:     _tOfs
    readonly property real      shadowOffset:   _tOfs * 0.4

    property string _gText: sourceText
    property real   _tOfs:  0
    property int    _gTick: 0

    Timer {
        running:  root.textGlitchActive
        interval: root.textGlitchInterval
        repeat:   true
        onTriggered: {
            root._gTick++

            if (root._gTick % root.textGlitchRate === 0) {
                // Random horizontal jitter
                const dir  = Math.random() > 0.5 ? 1 : -1
                root._tOfs = dir * Math.random() * root.textGlitchMaxOfs

                // Random character substitution
                const txt = root.sourceText
                if (Math.random() < root.textGlitchSubChance && txt.length > 1) {
                    const idx = Math.floor(Math.random() * txt.length)
                    const ch  = root.glitchCharPool[
                        Math.floor(Math.random() * root.glitchCharPool.length)]
                    root._gText = txt.substring(0, idx) + ch + txt.substring(idx + 1)
                } else {
                    root._gText = txt
                }

                _glitchClearTimer.restart()
            } else {
                root._tOfs  = 0
                root._gText = root.sourceText
            }
        }
    }

    // Reset glitch after 60% of the interval (brief impulse)
    Timer {
        id: _glitchClearTimer
        interval: root.textGlitchInterval * 0.6
        onTriggered: { root._tOfs = 0; root._gText = root.sourceText }
    }

    // =============================================
    // EFFECT 3: SCREEN TEAR — element distortion
    // =============================================
    //
    // Full-screen tearing/glitch effect in pure QML.
    // Made of: colored horizontal bands + jitter + flicker.
    // Call triggerTear() to fire it off.
    //
    // For true pixel-by-pixel displacement you'll need a
    // compiled fragment shader (.qsb). Set tearShaderSource
    // to use it instead of the QML fallback.
    //
    // Example:
    //      GlitchEffect { id: fx; tearSourceItem: myContent }
    //      onError: fx.triggerTear

    property Item   tearSourceItem:     null    // item to apply jitter to
    property int    tearDuration:       700     // total effect duration (ms)
    property int    tearBandCount:      15      // number of horizontal bands
    property real   tearMaxDisplace:    30      // max displacement in pixels
    property real   tearFlickerDepth:   0.4     // flicker depth (0-1)
    property url    tearShaderSource:   ""      // optional .qsb path for real displacement

    // Current intensity (1.0 → 0.0 during the effect)
    property real           tearIntensity:  0
    readonly property bool  tearActive:     tearIntensity > 0

    signal tearStarted()
    signal tearFinished()

    // Saved target X position for restoration
    property real _tearSavedX: 0

    function triggerTear() {
        if (!tearSourceItem) return
        _tearSavedX   = tearSourceItem.x
        tearIntensity = 1.0
        _tearDecayAnim.restart()
        _tearJitterTimer.start()
        _tearEndTimer.restart()
        tearStarted()
    }

    // Intensity decay from 1 to 0
    NumberAnimation {
        id: _tearDecayAnim
        target: root
        property: "tearIntensity"
        from: 1.0; to: 0.0
        duration: root.tearDuration
        easing.type: Easing.OutQuad
    }

    // Jitter: shifts the target horizontally + repaints bands
    Timer {
        id: _tearJitterTimer
        interval: 33            // ~30fps
        repeat: true
        onTriggered: {
            if (root.tearSourceItem) {
                root.tearSourceItem.x = root._tearSavedX
                                        + (Math.random() - 0.5) * root.tearMaxDisplace * 2 * root.tearIntensity
            }
            tearCanvas.requestPaint()
        }
    }

    // End of effect: restore everything
    Timer {
        id: _tearEndTimer
        interval: root.tearDuration
        onTriggered: {
            _tearJitterTimer.stop()
            if (root.tearSourceItem)
                root.tearSourceItem.x = root._tearSavedX
            root.tearIntensity = 0
            tearCanvas.requestPaint()
            root.tearFinished()
        }
    }

    // Canvas overlay — colored bands + noise
    Canvas {
        id: tearCanvas
        parent: root.tearSourcItem ?? root
        anchors.fill: parent
        visible: root.tearIntensity > 0
        z: 9999

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const intensity = root.tearIntensity
            if (intensity <= 0) return

            // Semi-transparent colored bands (RGB noise)
            for (let i = 0; i < root.tearBandCount; i++) {
                const y = Math.random() * height
                const h = 1 + Math.random() * 8
                const r = Math.random() > 0.7 ? 255 : 0
                const g = Math.random() > 0.7 ? 255 : 0
                const b = Math.random() > 0.7 ? 255 : 0
                ctx.fillStyle = `rgba(${r},${g},${b},${0.08 * intensity})`
                ctx.fillRect(0, y, width, h)
            }

            // Displaced dark bands (simulate tearing)
            for (let i = 0; i < 4; i++) {
                const y  = Math.random() * height
                const h  = 2 + Math.random() * 20
                const dx = (Math.random() - 0.5) * root.tearMaxDisplace * intensity
                ctx.fillStyle = `rgba(0,0,0,${0.18 * intensity})`
                ctx.fillRect(dx, y, width, h)
            }

            // Thin scanlines
            for (let y = 0; y < height; y += 2) {
                ctx.fillStyle = `rgba(0,0,0,${0.04 * intensity})`
                ctx.fillRect(0, y, width, 1)
            }
        }
    }

    // Opacity flicker on the target during the tear
    SequentialAnimation {
        id: _tearFlickerAnim
        running: root.tearIntensity > 0
        loops: Animation.Infinite

        ScriptAction {
            script: {
                if (root.tearSourceItem)
                    root.tearSourceItem.opacity =
                        1.0 - Math.random() * root.tearFlickerDepth * root.tearIntensity
            }
        }
        PauseAnimation { duration: 30 + Math.random() * 50 }
        ScriptAction {
            script: { if (root.tearSourceItem) root.tearSourceItem.opacity = 1.0 }
        }
        PauseAnimation { duration: 20 + Math.random() * 40 }
    }

    // Shader override (optional — for real pixel displacement)
    // If tearShaderSource is set, uses ShaderEffect instead of Canvas
    Loader {
        active: root.tearShaderSource != "" && root.tearIntensity > 0
        parent: root.tearSourceItem ?? root
        anchors.fill: parent
        z: 10000

        sourceComponent: ShaderEffect {
            property variant source: ShaderEffectSource {
                sourceItem: root.tearSourceItem
                live: true
                hideSource: true
            }
            property real iTime: root.tearIntensity
            fragmentShader: root.tearShaderSource
        }
    }
}
