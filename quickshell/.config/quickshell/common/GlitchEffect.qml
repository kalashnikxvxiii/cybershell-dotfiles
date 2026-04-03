// GlitchEffect.qml - Tre effetti glitch indipendenti in un unico componente
// Ispirato a github.com/xendak/nierlock
// 
// Uso:
// GlitchEffect {
//      anchors.fill: parent
//      
//      // 1) Scanlines orizzontali
//      linesEnabled: true
//      linesCount: 8
//
//      // 2) Glitch testuale - imposta sourceText, leggi glitcheText e textOffset
//      textGlitchActive: true
//      sourceText: "HELLO WORLD"
//      // nel tuo Text { text: myGlitch.glitchedText; x: myGlitch.textOffset }
//
//      // 3) Screen tear - imposta tearSourceItem, poi chiama triggerTear()
//      tearSourceItem: myContentItem
//}

import QtQuick

Item {
    id: root

    // =======================================================
    // EFFETTO 1: GLITCH LINES - scanlines orizzontali animate
    // =======================================================
    //
    // Rettangoli sottili (h=1) che attraversano lo schermo
    // con posizione Y, larghezza, opacita' e direzioni casuali
    // Loop infinito con pause random tra un passaggio e l'altro

    property bool linesEnabled:         false               // attiva/disattiva le linee
    property int  linesCount:           8                   // quante linee simultanee
    property color linesColor:          "#1A1A2E"         // colore delle linee
    property real linesMinWidth:        100                 // larghezza minima (px)
    property real linesMaxWidth:        300                 // larghezza massima (px)
    property real linesMaxOpacity:      0.5                 // opacita' massima raggiungibile
    property real linesMaxPause:        5000                // pause massima tra passaggi (ms)
    property real linesBaseSpeed:       1000                // durata base traversata (ms)
    property real linesSpeedVariation:  1200                // variazione casuale sulla durata (ms)

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

                // Pausa casuale prima del prossimo passaggio
                PauseAnimation { duration: Math.random() * root.linesMaxPause }

                // Randomizza properieta' della lines
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

                // Movimento orizzontale
                NumberAnimation {
                    id: lineMoveAnim
                    target: lineRect
                    property: "x"
                    easing.type: Easing.Linear
                }

                // Nascondi a fine passaggio
                PropertyAction { target: lineRect; property: "opacity"; value: 0 }
            }
        }
    }

    // ========================================================
    // EFFETTO 2: TEXT GLITCH - jitter + sostituzione caratteri
    // ========================================================
    //
    // Imposta sourceText con il testo originale
    // Leggi le proprieta' di output per applicarle al tuo Text:
    //      - glitchedText:     testo con caratteri sostituiti casualmente
    //      - textOffset:       offset X del testo principale (jitter)
    //      - shadowOffset:     offset X consigliato per l'ombra (40% del jitter)
    //
    // Esempio:
    //      Text { text: myGlitch.glitchedText; x: myGlitch.textOffset }
    //      Text { text: myGlitch.glitchedText; x: myGlitch.shaodwOffset; opacity: 0.3 }

    property bool   textGlitchActive:       false   // attiva/disattiva il glitch testuale
    property string sourceText:             ""      // testo originale in input
    property int    textGlitchRate:         2       // ogni N tick applica glitch (piu' basso = piu' frequente)
    property real   textGlitchMaxOfs:       6       // offset X massimo in pixel
    property real   textGlitchSubChance:    0.35    // probabilita' sostituzione carattere (0-1)
    property string glitchCharPool:                 // pool di caratteri sostituti
        "█▓▒░│┤╡╢╖╕╣║╗╝╜╛┐└╒╓╫╪┘┌"
    property int    textGlitchInterval:     55      // intervallo timer in ms

    // --- Output (bind i tuoi Text a queste) ---
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
                // Jitter orizzontale casuale
                const dir  = Math.random() > 0.5 ? 1 : -1
                root._tOfs = dir * Math.random() * root.textGlitchMaxOfs

                // Sostituzione carattere casuale
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

    // Reset glitch dopo il 60% dell'intervallo (impulso breve)
    Timer {
        id: _glitchClearTimer
        interval: root.textGlitchInterval * 0.6
        onTriggered: { root._tOfs = 0; root._gText = root.sourceText }
    }

    // =============================================
    // EFFETTO 3: SCREEN TEAR - distorzione elementi
    // =============================================
    //
    // Effetto tearing/glitch a schermo intero in puro QML
    // Composto da: bande orizzontali colorate + jitter + flicker
    // Chiama triggerTear() per attivarlo
    //
    // Se vuoi il vero displacement pixel-per-pixel, serve un
    // fragment shader compilato (.qsb). Imposta tearShaderSource
    // per usarlo al posto del fallback QML.
    //
    // Esempio:
    //      GlitchEffect { id: fx; tearSourceItem: myContent }
    //      onError: fx.triggerTear

    property Item   tearSourceItem:     null    // item su cui applicare il jitter
    property int    tearDuration:       700     // durata totale dell'effetto (ms)
    property int    tearBandCount:      15      // numero di bande orizzontali
    property real   tearMaxDisplace:    30      // displacement massimo in pixel
    property real   tearFlickerDepth:   0.4     // profondita' del flicker (0-1)
    property url    tearShaderSource:   ""      // path a .qsb opzionale per vero displacement

    // Intensita' corrente (1.0 -> 0.0 durante l'effetto)
    property real           tearIntensity:  0
    readonly property bool  tearActive:     tearIntensity > 0

    signal tearStarted()
    signal tearFinished()

    // Posizione X salvata del target per il ripristino
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

    // Decadimento intensita' da 1 a 0
    NumberAnimation {
        id: _tearDecayAnim
        target: root
        property: "tearIntensity"
        from: 1.0; to: 0.0
        duration: root.tearDuration
        easing.type: Easing.OutQuad
    }

    // Jitter: sposta il target orizzontalmente + ridisegna bande
    Timer {
        id: _tearJitterTimer
        interval: 33            // ~30fps
        repeat: true
        onTriggered: {
            if (root.tearSourceItem) {
                root.tearSourceitem.x = root._tearSavedX
                                        + (Math.random() - 0.5) * root.tearMaxDisplace * 2 * root.tearIntensity
            }
            tearCanvas.requestPaint()
        }
    }

    // Fine effetto: ripristina tutto
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

    // Canvas overlay - bande colorate + rumore
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

            // Bande colorate semitrasparenti (RGB noise)
            for (let i = 0; i < root.tearBandCount; i++) {
                const y = Math.random() * height
                const h = 1 + Math.random() * 8
                const r = Math.random() > 0.7 ? 255 : 0
                const g = Math.random() > 0.7 ? 255 : 0
                const b = Math.random() > 0.7 ? 255 : 0
                ctx.fillStyle = `rgba(${r},${g},${b},${0.08 * intensity})`
                ctx.fillRect(0, y, width, h)
            }

            // Bande scure displaced (simulano tearing)
            for (let i = 0; i < 4; i++) {
                const y  = Math.random() * height
                const h  = 2 + Math.random() * 20
                const dx = (Math.random() - 0.5) * root.tearMaxDisplace * intensity
                ctx.fillStyle = `rgba(0,0,0,${0.18 * intensity})`
                ctx.fillRect(dx, y, width, h)
            }

            // Scanlines sottili
            for (let y = 0; y < height; y += 2) {
                ctx.fillStyle = `rgba(0,0,0,${0.04 * intensity})`
                ctx.fillRect(0, y, width, 1)
            }
        }
    }

    // Flicker opacita' sul target durante il tear
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

    // Sahder override (opzionale - per vero pixel displacement)
    // Se tearShaderSource e' impostato, usa ShaderEffect al posto del Canvas
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
