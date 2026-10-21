// EndpointCard.qml — Hero card per default sink (OUT) o source (IN).
// Layout:
//   ● ACTIVE ENDPOINT · DEFAULT
//   ▶ NAME OF DEVICE
//   DEV /alsa.0:7  SR 48kHz/24b  CH 2.0
//   L [██████████░░░░░] ▰  68%
//   R [██████████░░░░░] ▰
//   [optional Oscilloscope 340×34 below metadata if showOscilloscope = true]
import "../../../common/Colors.js" as CP
import "../../../common"
import "../../../common/effects"
import QtQuick
import CyberAudio.Services

Item {
    id: root

    // -- Public API -------------------------------------------------
    property var    node:               null
    property color  accent:             Colours.accentSecondary
    property string mode:               "sink"            // "sink" | "source"
    property bool   showOscilloscope:   false

    // -- Derived ------------------------------------------------
    readonly property string displayName: {
        if (!node) return "—"
        return (node.description || node.name || "Unknown").toUpperCase()
    }
    readonly property string devPath: {
        if (!node || !node.properties) return ""
        var p = node.properties
        return p["node.name"] || p["api.alsa.path"] || p["object.path"] || ""
    }
    readonly property string sampleRate: {
        if (!node || !node.properties) return "48kHz"
        var r = node.properties["node.rate"] || node.properties["audio.rate"] || "48000"
        if (typeof r === "string" && r.indexOf("/") >= 0) r = r.split("/")[1]
        return Math.round(Number(r) / 1000) + "kHz"
    }
    readonly property string bitDepth: "24b"  // PipeWire default; PwNode doesn't always expose this
    readonly property string chCount: {
        if (!node || !node.properties) return "2.0"
        var c = Number(node.properties["audio.channels"] || 2)
        return c + ".0"
    }
    readonly property int    volPercent: node && node.audio ? Math.round(node.audio.volume * 100) : 0
    readonly property bool   muted:      node && node.audio ? node.audio.muted : false

    // VU reali: PCM stereo dal monitor del sink di default.
    // I campioni lineari vengono mappati su dBFS con fondoscala a -60 dB,
    // altrimenti su materiale musicale la barra resta quasi ferma in alto.
    function _toBar(v) {
        if (v <= 0.001) return 0
        var db = 20 * Math.log(v) / Math.LN10
        return Math.max(0, Math.min(1, (db + 60) / 60))
    }
    readonly property string nodeTarget: node && node.properties
                                        ? (node.properties["node.name"] || "") : ""

    NodeLevelProvider {
        id: cardLevel
        target: root.nodeTarget
        captureSink: root.mode === "sink"
    }
    // Sampled at 30Hz instead of following the provider's ~90 updates a
    // second: each one re-laid the meters and kept the popup rendering at the
    // monitor's refresh rate
    property real vuL: 0
    property real vuR: 0

    // Peak hold (3s decay)
    property real _peakL: 0
    property real _peakR: 0
    Ticker {
        running: root.visible
        onTicked: {
            root.vuL = root.showOscilloscope ? 0 : root._toBar(cardLevel.peakL)
            root.vuR = root.showOscilloscope ? 0 : root._toBar(cardLevel.peakR)
            if (root.vuL > root._peakL) root._peakL = root.vuL
            else root._peakL = Math.max(0, root._peakL - 0.0111)
            if (root.vuR > root._peakR) root._peakR = root.vuR
            else root._peakR = Math.max(0, root._peakR - 0.0111)
        }
    }

    // -- Sizing ------------------------------------------
    implicitHeight: showOscilloscope ? 110 : 84

    // -- Background card ----------------------------------------------
    CutShape {
        anchors.fill: parent
        fillColor: muted ? CP.alpha(CP.void2, 0.45) : CP.alpha(root.accent, 0.10)
        strokeColor: muted ? CP.alpha(Colours.textMuted, 0.4) : root.accent
        strokeWidth: 1.5
        inset: 0.5
        cutTopRight: 24
        Behavior on fillColor   { CAnim {} }
        Behavior on strokeColor { CAnim {} }
    }

    // -- Badge ------------------------------------------------
    Text {
        id: badge
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 8
        text: "● ACTIVE " + (mode === "source" ? "SOURCE" : "ENDPOINT") + " · DEFAULT"
        font.family: "Oxanium"
        font.pixelSize: 9
        font.letterSpacing: 2
        font.bold: true
        color: muted ? Colours.textMuted : root.accent
    }

    // -- Device name (Oxanium 14 bold) -------------------------------------
    Text {
        id: name
        anchors.top: badge.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 6
        anchors.leftMargin: 8
        anchors.rightMargin: 60
        text: (mode === "source" ? "◀ " : "▶ ") + root.displayName
        font.family: "Oxanium"
        font.pixelSize: 16
        font.letterSpacing: 1
        font.bold: true
        color: muted ? Colours.textMuted : root.accent
        elide: Text.ElideRight
    }

    // -- Metadata line --------------------------------
    Text {
        id: meta
        anchors.top: name.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 4
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        text: {
            var parts = []
            if (root.devPath) parts.push("DEV " + root.devPath)
            parts.push("SR " + root.sampleRate + "/" + root.bitDepth)
            parts.push("CH " + root.chCount)
            return parts.join("  ")
        }
        font.family: "Oxanium"
        font.pixelSize: 9
        font.letterSpacing: 0.5
        color: Colours.textMuted
        elide: Text.ElideRight
    }

    // -- Cattura reale del mic: attiva solo finché questa card è viva -----------------
    Loader {
        active: root.showOscilloscope && root.mode === "source" && root.node !== null && root.visible
        sourceComponent: Item {
            ServiceRef { service: Audio.micScope }
            Binding {
                target: Audio.micScope
                property: "target"
                value: root.node && root.node.properties
                    ? (root.node.properties["node.name"] || "") : ""
            }
        }
    }

    // -- Livello reale in uscita: attivo solo mentre la card OUT è viva ---------------
    // The ref lives inside the component: as a direct child of a Loader it
    // outlived `active` and kept the capture running with the popup closed.
    // The VU reads cardLevel, not Audio.outLevel, so that is the one to hold.
    Loader {
        active: !root.showOscilloscope && root.node !== null && root.visible
        sourceComponent: Item {
            ServiceRef { service: cardLevel }
        }
    }

    // ── Oscilloscopio (solo quando showOscilloscope = true) ──────
    Canvas {
        id: scope
        visible: root.showOscilloscope
        anchors.top: meta.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 4
        anchors.leftMargin: 8
        anchors.rightMargin: 50  // leave room for volume %
        height: visible ? 24 : 0

        property real gain: 3.5
        readonly property var frame: root.showOscilloscope && root.mode === "source"
                                     ? Audio.micScope.samples : []
        onFrameChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            // Midline
            ctx.strokeStyle = CP.alpha(root.accent, 0.4).toString()
            ctx.setLineDash([2, 2])
            ctx.beginPath()
            ctx.moveTo(0, height / 2)
            ctx.lineTo(width, height / 2)
            ctx.stroke()
            ctx.setLineDash([])

            var s = scope.frame
            if (!s || s.length < 2) return

            // Waveform reale (PCM dal MicCollector, media per bucket)
            ctx.strokeStyle = root.accent.toString()
            ctx.lineWidth = 1
            ctx.beginPath()
            var mid = height / 2
            var amp = height * 0.45
            for (var i = 0; i < s.length; i++) {
                var x = i / (s.length - 1) * width
                var v = Math.max(-1, Math.min(1, s[i] * scope.gain))
                var y = mid - v * amp
                if (i === 0) ctx.moveTo(x, y)
                else ctx.lineTo(x, y)
            }
            ctx.stroke()
        }
    }

    // ── VU meter L (only when NOT showOscilloscope) ──────────────
    Item {
        id: vuLabelL
        visible: !root.showOscilloscope
        anchors.top: meta.bottom
        anchors.left: parent.left
        anchors.topMargin: 6
        anchors.leftMargin: 8
        width: 10
        height: 5
        Text {
            anchors.centerIn: parent
            text: "L"
            font.family: "Oxanium"
            font.pixelSize: 9
            font.letterSpacing: 1
            font.bold: true
            color: muted ? Colours.textMuted : Colours.accentPrimary
        }
    }
    Item {
        visible: !root.showOscilloscope
        anchors.left: vuLabelL.right
        anchors.right: parent.right
        anchors.verticalCenter: vuLabelL.verticalCenter
        anchors.leftMargin: 4
        anchors.rightMargin: 50
        height: 5
        Rectangle {
            anchors.fill: parent
            color: CP.alpha(CP.void2, 0.7)
            border.color: CP.alpha(Colours.accentPrimary, 0.3)
            border.width: 0.5
        }
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 1
            width: Math.max(0, (parent.width - 2) * root.vuL)
            color: muted ? Colours.textMuted : Colours.accentPrimary
        }
        // Peak hold red rect
        Rectangle {
            visible: !muted && root._peakL > 0.01
            x: Math.max(0, (parent.width - 2) * root._peakL)
            width: 2
            height: parent.height
            color: "#ff003c"
        }
    }

    // ── VU meter R ───────────────────────────────────────────────
    Item {
        id: vuLabelR
        visible: !root.showOscilloscope
        anchors.top: vuLabelL.bottom
        anchors.left: parent.left
        anchors.topMargin: 4
        anchors.leftMargin: 8
        width: 10
        height: 5
        Text {
            anchors.centerIn: parent
            text: "R"
            font.family: "Oxanium"
            font.pixelSize: 9
            font.letterSpacing: 1
            font.bold: true
            color: muted ? Colours.textMuted : Colours.accentPrimary
        }
    }
    Item {
        visible: !root.showOscilloscope
        anchors.left: vuLabelR.right
        anchors.right: parent.right
        anchors.verticalCenter: vuLabelR.verticalCenter
        anchors.leftMargin: 4
        anchors.rightMargin: 50
        height: 5
        Rectangle {
            anchors.fill: parent
            color: CP.alpha(CP.void2, 0.7)
            border.color: CP.alpha(Colours.accentPrimary, 0.3)
            border.width: 0.5
        }
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 1
            width: Math.max(0, (parent.width - 2) * root.vuR)
            color: muted ? Colours.textMuted : Colours.accentPrimary
        }
        Rectangle {
            visible: !muted && root._peakR > 0.01
            x: Math.max(0, (parent.width - 2) * root._peakR)
            width: 2
            height: parent.height
            color: "#ff003c"
        }
    }

    // ── Volume % readout (right side) ────────────────────────────
    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 8
        text: muted ? "MUTE" : (root.volPercent + "%")
        font.family: "Oxanium"
        font.pixelSize: 13
        font.bold: true
        color: muted ? Colours.textMuted : Colours.accentPrimary
    }

    // ── RMB -> mute the active device ───────────────
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: AudioControlState.toggleMute(root.node)
    }
}

