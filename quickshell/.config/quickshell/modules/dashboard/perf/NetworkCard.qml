// NetworkCard.qml — network metrics card for the CYBERWARE tab.
//
// Split out of PerfMetrics.qml, which was already long before this card grew a
// background graph and a speed-test mode of its own.
//
// The test is run by scripts/speedtest-run.py through PerfDataProvider; this
// file only presents it.
import QtQuick
import QtQuick.Effects
import "../../../common/Colors.js" as CP
import "../../../common"

Item {
    id: card

    // The data provider, passed in rather than picked up from the enclosing
    // file's scope: this card is meant to be readable on its own.
    required property var    provider
    required property string netStatus
    required property string netSsid
    required property string netSignal
    required property real   netRxBps
    required property real   netTxBps
    required property var    netHistory

    signal speedTestRequested()

    readonly property bool online: netStatus !== "off"

    // Set by the key's glitch while it runs; the chromatic ghosts of the key
    // and of the value follow it.
    property bool _glitching: false

    // ── Test mode ────────────────────────────────────────────────────────
    // "done" is a mode, not just a finished test: the results stay on the card
    // until dismissed, so entering and leaving is explicit rather than tied to
    // whether the helper happens to be running.
    property bool testMode: false
    readonly property string mode: !testMode ? "idle"
                                 : (provider.speedRunning ? "testing" : "done")

    readonly property string phaseKey: {
        if (provider.speedError !== "") return "ERROR"
        if (provider.speedCancelled)    return "CANCELLED"
        switch (provider.speedPhase) {
        case "connecting": return "CONNECTING"
        case "latency":    return "LATENCY"
        case "download":   return "DOWNLOAD"
        case "upload":     return "UPLOAD"
        case "done":       return "COMPLETE"
        }
        return ""
    }

    // What the rising row shows while a test runs: the figure for the phase
    // being measured, live, so the number under the key is the one being found.
    readonly property string phaseValue: {
        if (!testMode) return ""
        switch (provider.speedPhase) {
        case "latency":  return card.ms(provider.speedPing)
        case "download":
        case "upload":   return card.mbit(provider.speedRate)
        case "done":     return card.mbit(provider.speedDown)
        }
        return "—"
    }

    // Whether the test has produced a figure worth showing yet. Before that
    // the live pair keeps its place, rather than a dash standing in for it.
    readonly property bool hasFigure: {
        if (!testMode) return false
        switch (provider.speedPhase) {
        case "latency":  return provider.speedPing >= 0
        case "download":
        case "upload":   return provider.speedRate >= 0
        case "done":     return true
        }
        return false
    }

    // -1 is the provider's "not measured": shown as a dash, never as a zero.
    // How far below the ring's centre the lifted value sits, and the width
    // free inside the stroke at the value's lower edge -- the narrowest line
    // the text touches. The ring's radius and inset mirror its onPaint.
    readonly property real valueDrop: 7
    readonly property real ringChord: {
        var inner = (ring.width - 20) / 2 - 1.5 - 4
        var dy = valueDrop + rates.height * rates.liftScale / 2
        return 2 * Math.sqrt(Math.max(0, inner * inner - dy * dy))
    }

    // A run that reached its end, as opposed to one that stopped in "done" mode
    // because it was cancelled or failed.
    readonly property bool completed: mode === "done" && provider.speedPhase === "done"

    function mbit(bps) { return bps < 0 ? "—" : (bps / 1000000).toFixed(1) + " Mbit/s" }
    function ms(v, digits) { return v < 0 ? "—" : v.toFixed(digits || 0) + " ms" }

    // The one way in, used by both the corner button and the repeat inside the
    // ring, so the two cannot drift apart.
    function startTest() {
        if (provider.speedRunning) return
        testMode = true
        provider.runSpeedTest()
        fx.burst("start", "connecting")
        speedTestRequested()
    }

    // Milestones get a burst; the key glitches whenever it changes.
    Connections {
        target: card.provider
        function onSpeedPhaseChanged() {
            if (!card.testMode) return
            var ph = card.provider.speedPhase
            if (ph === "download" || ph === "upload") fx.burst("phase", ph)
            else if (ph === "done") fx.burst("done", ph)
        }
        function onSpeedErrorChanged() {
            if (card.testMode && card.provider.speedError !== "") fx.burst("fail")
        }
        function onSpeedCancelledChanged() {
            if (card.testMode && card.provider.speedCancelled) fx.burst("fail")
        }
    }
    onPhaseKeyChanged: if (testMode && phaseKey !== "") keyGlitch.restart()

    // After a completed test the card is not static: a sparse glitch, every
    // 4-9 s, as the design reference prescribes for idle hero readouts.
    Timer {
        interval: 4000
        repeat: true
        running: card.completed && card.visible
        onTriggered: {
            interval = 4000 + Math.random() * 5000
            keyGlitch.restart()
            fx.tear(null, 2)
        }
    }

    // When the result on screen was taken, as a clock time rather than an age:
    // an age would be computed once and then go stale while the card sits.
    function whenText() {
        if (!provider.speedWhen) return ""
        var d = new Date(provider.speedWhen)
        if (isNaN(d.getTime())) return ""
        var sameDay = d.toDateString() === new Date().toDateString()
        return Qt.formatDateTime(d, sameDay ? "HH:mm" : "dd/MM HH:mm")
    }

    // Card body, drawn first so everything else sits on top of it.
    CutShape {
        anchors.fill: parent
        fillColor: Colours.moduleBg
        cutBottomLeft: 24
    }

    // ── Background graph ─────────────────────────────────────────────────
    // Sits behind the readouts and is always on: it is the card's texture, not
    // a readout itself, so it stays quiet and unlabelled.
    Canvas {
        id: graph
        anchors.fill: parent
        anchors.margins: 1
        opacity: 0.45

        // Masked to the card's own outline: a plain canvas is rectangular and
        // would paint over the diagonal corner that the stroke cuts away.
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: graphMask
        }

        property var samples: card.netHistory
        onSamplesChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var n = samples ? samples.length : 0
            if (n < 2) return

            // Scaled to the window's own peak rather than a fixed ceiling, so
            // the shape stays legible on a quiet link and on a busy one alike.
            // The floor keeps idle noise from being amplified into mountains.
            var peak = 64 * 1024
            for (var i = 0; i < n; i++)
                peak = Math.max(peak, samples[i].rx, samples[i].tx)

            var w = width, h = height
            var step = w / (n - 1)

            function area(key, rgb) {
                ctx.beginPath()
                ctx.moveTo(0, h)
                for (var i = 0; i < n; i++) {
                    var v = samples[i][key] / peak
                    ctx.lineTo(i * step, h - Math.sqrt(v) * h * 0.8)
                }
                ctx.lineTo(w, h)
                ctx.closePath()
                var g = ctx.createLinearGradient(0, 0, 0, h)
                g.addColorStop(0, Qt.rgba(rgb.r, rgb.g, rgb.b, 0.30))
                g.addColorStop(1, Qt.rgba(rgb.r, rgb.g, rgb.b, 0.02))
                ctx.fillStyle = g
                ctx.fill()

                ctx.beginPath()
                for (var j = 0; j < n; j++) {
                    var y = h - Math.sqrt(samples[j][key] / peak) * h * 0.8
                    if (j === 0) ctx.moveTo(0, y); else ctx.lineTo(j * step, y)
                }
                ctx.strokeStyle = Qt.rgba(rgb.r, rgb.g, rgb.b, 0.7)
                ctx.lineWidth = 1
                ctx.stroke()
            }

            // Square root rather than linear: a burst would otherwise flatten
            // everything else to the baseline.
            area("rx", Colours.accentSecondary)
            area("tx", Colours.accentPrimary)
        }
    }

    // ── Test effects ─────────────────────────────────────────────────────
    // Above the graph, below every readout. Idle, it draws nothing and runs
    // nothing.
    SpeedFx {
        id: fx
        anchors.fill: parent
        cx: ring.x + ring.width / 2
        cy: ring.y + ring.height / 2
        // Mirrors the ring canvas's own radius and inset.
        radius: (ring.width - 20) / 2
        cutBottomLeft: 24
        keepOut: [title, statusText, signalText, qualityCol, routeCol, resultLine, startBtn]
        streaming: card.mode === "testing"
        phase: card.provider.speedPhase
        rate: Math.max(0, card.provider.speedRate)
    }

    // ── Header ───────────────────────────────────────────────────────────
    Row {
        id: title
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 6
        anchors.topMargin: 6
        spacing: 6

        Rectangle {
            width: 3; height: 10
            anchors.verticalCenter: parent.verticalCenter
            color: Colours.accentSecondary
        }
        Text {
            text: "NETWORK"
            font.family: "Oxanium"
            font.pixelSize: 10
            font.letterSpacing: 2
            color: Colours.accentSecondary
        }
    }

    Text {
        id: statusText
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 10
        anchors.topMargin: 6
        text: card.netStatus === "wifi" ? card.netSsid : card.netStatus.toUpperCase()
        font.family: "Chakra Petch"
        font.pixelSize: 10
        color: card.online ? Colours.accentOk : Colours.accentDanger
    }

    Text {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 10
        id: signalText
        anchors.topMargin: 20
        visible: card.netSignal !== ""
        text: card.netSignal + " dBm"
        font.family: "Chakra Petch"
        font.pixelSize: 9
        color: Colours.textMuted
    }

    // ── Live throughput ──────────────────────────────────────────────────
    // Bottom centre is its resting place; in test mode it rises under the phase
    // key and grows. The moving item spans the whole card and centres its
    // content, so its x never changes: a Row positioned by its own width jumped
    // sideways whenever its children swapped, because the width shifted
    // mid-motion while x was not animated.
    Item {
        id: rates
        width: card.width
        height: ratesRow.implicitHeight
        x: 0
        y: card.height - height - 10
        transformOrigin: Item.Center

        readonly property real liftScale: 1.3

        states: State {
            name: "lifted"
            when: card.testMode
            PropertyChanges {
                target: rates
                // Centred just below the ring's middle, with the key just
                // above it: the pair sits in the ring as one block.
                y: ring.y + ring.height / 2 + card.valueDrop - rates.height / 2
                scale: rates.liftScale
            }
        }
        transitions: Transition {
            NumberAnimation {
                properties: "y,scale"
                duration: 340
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }
        }

        Row {
            id: ratesRow
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14

            // Inside the ring the row also shrinks to fit when it would touch
            // the stroke: the live pair while connecting is wider than any
            // ring the card has room for, and so is a four-digit figure. Its
            // own scale rather than the state's, so the swap from pair to
            // figure animates -- a Behavior on a property the state also sets
            // would intercept the state's restore on the way out.
            scale: card.testMode ? Math.min(1, card.ringChord / (implicitWidth * rates.liftScale)) : 1
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            // Live pair: the default readout, and also what rides up while the
            // test is still connecting. A placeholder dash there read as a flat
            // line, not as a value on its way.
            Text {
                visible: !card.hasFigure
                text: "↓ " + card.provider.formatBytes(card.netRxBps)
                font.family: "Chakra Petch"
                font.pixelSize: 12
                color: Colours.accentSecondary
            }
            Text {
                visible: !card.hasFigure
                text: "↑ " + card.provider.formatBytes(card.netTxBps)
                font.family: "Chakra Petch"
                font.pixelSize: 12
                color: Colours.accentPrimary
            }

            // The figure being measured, once the test has one, with red and
            // cyan ghosts that split off while the key glitches.
            Item {
                visible: card.hasFigure
                implicitWidth: figure.implicitWidth
                implicitHeight: figure.implicitHeight

                Text {
                    visible: card._glitching
                    x: -2
                    text: figure.text
                    font: figure.font
                    color: Colours.aberrationRed(0.6)
                }
                Text {
                    visible: card._glitching
                    x: 2
                    text: figure.text
                    font: figure.font
                    color: Colours.aberrationCyan(0.6)
                }
                Text {
                    id: figure
                    text: card.phaseValue
                    font.family: "Chakra Petch"
                    font.pixelSize: 12
                    font.bold: true
                    color: card.provider.speedPhase === "upload" ? Colours.accentPrimary
                                                                 : Colours.accentSecondary
                }
            }
        }
    }

    // ── Test overlay: ring, phase key, repeat ────────────────────────────
    Item {
        id: ring
        // Sized for the block inside it, not for the card: the widest pair,
        // CONNECTING over a three-digit Mbit/s figure at the lifted scale,
        // has to clear the stroke. The card is 140 tall, so the ring nearly
        // fills it and the timestamp moved out from under it.
        width: 130; height: 130
        x: (card.width - width) / 2
        y: (card.height - height) / 2
        visible: opacity > 0
        opacity: card.testMode ? 1 : 0
        scale: card.testMode ? 1 : 0.75
        Behavior on opacity { NumberAnimation { duration: 260 } }
        Behavior on scale {
            NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        }

        // Only the canvas turns. A RotationAnimator runs on the render thread
        // and does not update the rotation property while it runs, so text
        // counter-rotated against it read 0 and spun along with the ring.
        Canvas {
            id: ringCanvas
            anchors.fill: parent

            RotationAnimator on rotation {
                running: card.completed
                loops: Animation.Infinite
                from: 0; to: 360
                duration: 5200
                // Stopping leaves the canvas at whatever angle the spin had
                // reached, so a repeat drew its new arc from there instead of
                // from the top. The reset is invisible: a new run starts with
                // an almost empty arc.
                onRunningChanged: if (!running) ringCanvas.rotation = 0
            }

            // A cancelled or failed run keeps the arc where it stopped: a full,
            // spinning ring would claim a result the run never reached.
            readonly property real prog: card.completed ? 1 : card.provider.speedProgress
            onProgChanged: requestPaint()
            // One handler: a second onVisibleChanged on the same item is a
            // load-time error, not an override.
            onVisibleChanged: {
                if (visible) requestPaint()
                else rotation = 0
            }
            Component.onCompleted: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var cx = width / 2, cy = height / 2
                // Inset so the head's glow is not clipped at the canvas edge.
                var r = (Math.min(width, height) - 20) / 2
                var top = -Math.PI / 2
                var c = Colours.accentSecondary

                ctx.beginPath()
                ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.15)
                ctx.lineWidth = 3
                ctx.stroke()

                if (prog <= 0) return

                var head = top + prog * 2 * Math.PI
                ctx.beginPath()
                ctx.arc(cx, cy, r, top, head)
                ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.9)
                ctx.lineWidth = 3
                ctx.lineCap = "round"
                ctx.stroke()

                // Head: a halo and a hot core in the body's own hue, so the arc
                // brightens into its tip instead of changing colour there. Same
                // treatment as the GPU gauge tip.
                var hx = cx + Math.cos(head) * r
                var hy = cy + Math.sin(head) * r
                var glow = ctx.createRadialGradient(hx, hy, 0, hx, hy, 9)
                glow.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.8))
                glow.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0))
                ctx.beginPath()
                ctx.arc(hx, hy, 9, 0, 2 * Math.PI)
                ctx.fillStyle = glow
                ctx.fill()

                ctx.beginPath()
                ctx.arc(hx, hy, 2.4, 0, 2 * Math.PI)
                ctx.fillStyle = Qt.rgba(Math.min(1, c.r + 0.55),
                                        Math.min(1, c.g + 0.55),
                                        Math.min(1, c.b + 0.55), 1)
                ctx.fill()
            }
        }

        Text {
            id: keyLabel
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height / 2 - height - 4
            text: card.phaseKey
            font.family: "Oxanium"
            font.pixelSize: 10
            font.letterSpacing: 2
            font.bold: true
            color: Colours.accentPrimary
            transform: Translate { id: keyShift }

            Text {
                visible: card._glitching
                x: -2
                text: keyLabel.text
                font: keyLabel.font
                color: Colours.aberrationRed(0.6)
            }
            Text {
                visible: card._glitching
                x: 2
                text: keyLabel.text
                font: keyLabel.font
                color: Colours.aberrationCyan(0.6)
            }
        }

        GlitchAnim {
            id: keyGlitch
            labelTarget: keyLabel
            shiftTarget: keyShift
            aberrationTarget: card
            baseColor: Colours.accentPrimary
            c1: CP.magenta
            c3: CP.cyan
        }

        // Repeat, revealed on hover once the test is over.
        MouseArea {
            id: ringMa
            anchors.fill: parent
            hoverEnabled: card.mode === "done"
            acceptedButtons: card.mode === "done" ? Qt.LeftButton : Qt.NoButton
            cursorShape: card.mode === "done" ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (card.mode === "done") card.startTest()
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            // Raised with the larger ring: at 14 its ends crossed the stroke,
            // where the ring is narrowest.
            anchors.bottomMargin: 26
            visible: opacity > 0
            opacity: (card.mode === "done" && ringMa.containsMouse) ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
            text: "↻ REPEAT"
            font.family: "Oxanium"
            font.pixelSize: 8
            font.letterSpacing: 1.5
            font.bold: true
            color: Colours.accentPrimary
        }
    }

    // ── Full result ──────────────────────────────────────────────────────
    // Spelled out on both sides of the ring and filled in as each figure is
    // measured, so a cancelled run still shows what it got. Quality on the
    // left, throughput and route on the right.
    component Detail: Row {
        id: detail
        property string key
        property string value
        property color  tint: Colours.textSecondary
        spacing: 6

        // A figure's first arrival decodes in, terminal style: characters
        // settle left to right out of noise, 30 ms each. Later updates are
        // data and land at once.
        property string shown: ""
        property int _revealed: -1
        Component.onCompleted: shown = value
        onValueChanged: {
            if (value === "—") {
                decodeTimer.stop()
                _revealed = -1
                shown = value
            } else if (_revealed < 0 && shown === "—") {
                _revealed = 0
                decodeTimer.start()
            } else if (_revealed < 0) {
                shown = value
            }
            // While decoding, the timer picks up the new value by itself.
        }
        Timer {
            id: decodeTimer
            interval: 30
            repeat: true
            onTriggered: {
                var v = detail.value
                detail._revealed++
                if (detail._revealed >= v.length) {
                    stop()
                    detail._revealed = -1
                    detail.shown = v
                    return
                }
                var noise = "█▓▒░#0123456789ABCDEF"
                var out = v.substr(0, detail._revealed)
                for (var i = detail._revealed; i < v.length; i++)
                    out += v.charAt(i) === " " ? " "
                         : noise.charAt(Math.floor(Math.random() * noise.length))
                detail.shown = out
            }
        }
        Text {
            anchors.baseline: valueText.baseline
            text: parent.key
            font.family: "Oxanium"
            font.pixelSize: 8
            font.letterSpacing: 1
            color: Colours.textMuted
        }
        Text {
            id: valueText
            text: detail.shown
            font.family: "Chakra Petch"
            font.pixelSize: 10
            color: parent.tint
        }
    }

    Column {
        id: qualityCol
        anchors.left: parent.left
        anchors.leftMargin: 12
        y: 34
        spacing: 3
        visible: opacity > 0
        opacity: card.testMode ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 220 } }

        Detail { key: "LATENCY"; value: card.ms(card.provider.speedPing) }
        Detail { key: "JITTER";  value: card.ms(card.provider.speedJitter, 1) }
        // Round trip measured while the download saturates the link, minus
        // the idle one: how much the line's queues add under load.
        Detail {
            key: "BLOAT"
            value: card.provider.speedBloat < 0 ? "—"
                 : "+" + card.provider.speedBloat.toFixed(0) + " ms"
        }
        // Latency probes that timed out. HTTP over TCP retransmits what it
        // loses, so this only catches losses bad enough to stall a request;
        // it is not packet loss, and the key does not pretend it is.
        Detail {
            key: "TIMEOUTS"
            value: card.provider.speedLoss < 0 ? "—"
                 : card.provider.speedLoss.toFixed(0) + "%"
            tint: card.provider.speedLoss > 0 ? Colours.accentWarn : Colours.textSecondary
        }
    }

    Column {
        id: routeCol
        anchors.right: parent.right
        anchors.rightMargin: 12
        y: 34
        spacing: 3
        visible: opacity > 0
        opacity: card.testMode ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 220 } }

        Detail {
            anchors.right: parent.right
            key: "DOWN"; value: card.mbit(card.provider.speedDown)
            tint: Colours.accentSecondary
        }
        Detail {
            anchors.right: parent.right
            key: "UP"; value: card.mbit(card.provider.speedUp)
            tint: Colours.accentPrimary
        }
        Detail {
            anchors.right: parent.right
            key: "EDGE"; value: card.provider.speedColo || "—"
        }
        Detail {
            anchors.right: parent.right
            key: "VIA"; value: card.provider.speedVia || "—"
        }
    }

    // Error, or when the shown result was taken. Bottom left, across from the
    // button: the ring now reaches down to the card's bottom edge. Clear of
    // the diagonal cut, and wraps upwards rather than running under the ring.
    Text {
        id: resultLine
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 28
        anchors.bottomMargin: 8
        width: ring.x - anchors.leftMargin - 6
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
        visible: opacity > 0
        opacity: (card.mode === "done" && text !== "") ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 220 } }
        text: card.provider.speedError !== ""
              ? card.provider.speedError.toUpperCase()
              : (card.whenText() ? "TESTED " + card.whenText() : "")
        font.family: "Chakra Petch"
        font.pixelSize: 9
        color: card.provider.speedError !== "" ? Colours.accentDanger : Colours.textMuted
    }

    // ── Speed test control ───────────────────────────────────────────────
    // Only this corner takes the click; the rest of the card stays inert. The
    // button carries three roles rather than three buttons appearing and
    // disappearing in the same spot.
    Item {
        id: startBtn
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 8
        anchors.bottomMargin: 8
        width: startLabel.implicitWidth + 6
        height: 14
        z: 5

        Text {
            id: startLabel
            anchors.centerIn: parent
            text: card.mode === "testing" ? "■ CANCEL"
                : card.mode === "done"    ? "✕ EXIT"
                                          : "▶ SPEEDTEST"
            font.family: "Oxanium"
            font.pixelSize: 9
            font.letterSpacing: 1.5
            font.bold: true
            color: {
                var c = card.mode === "testing" ? Colours.accentDanger
                                                : Colours.accentPrimary
                return startMa.containsMouse ? c : CP.alpha(c, 0.55)
            }
        }

        MouseArea {
            id: startMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                switch (card.mode) {
                case "idle":
                    card.startTest()
                    break
                case "testing":
                    // Stops the run but stays in the mode: whatever was
                    // already measured remains on screen, as asked.
                    card.provider.cancelSpeedTest()
                    break
                case "done":
                    card.testMode = false
                    break
                }
            }
        }
    }


    CutShape {
        id: graphMask
        anchors.fill: parent
        anchors.margins: 1
        visible: false
        layer.enabled: true
        fillColor: "white"
        cutBottomLeft: 24
    }

    // Border last, so it draws over the graph rather than under it.
    CutShape {
        anchors.fill: parent
        strokeColor: Colours.neonBorder(0.3)
        strokeWidth: 1
        inset: 0.5
        cutBottomLeft: 24
    }
}
