// ~/dotfiles/quickshell/.config/quickshell/modules/bar/AudioControl/AudioHeader.qml
// Master volume header — Signal Flow concept:
//   ◢ SIGNAL · STATUS [hex_id]
//   68%  DP-1·HDMI  48kHz/24b
//   ▶ FLOW  [══════════════════━━━━━━━] (with 4 particles)
//   [MUTE]                              [EXPAND ▼]
// Border + accent del popup contenitore cambia con la tab attiva, gestito dal popup root.
import "../../../common/Colors.js" as CP
import "../../../common"
import "../../../common/effects"
import QtQuick

Item {
    id: root

    signal expandToggleRequested()
    signal closeRequested()

    property bool expanded: false

    readonly property var sink: AudioControlState.defaultSink
    readonly property real volRatio: sink && sink.audio ? Math.min(1.5, sink.audio.volume) : 0
    readonly property int volPercent: Math.round(volRatio * 100)
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property string sinkName: sink ? (sink.description || sink.name || "—").toUpperCase().replace(/\s+/g, "·") : "NO DEFAULT"

    // Hex device ID for diegetic metadata: last byte of node.id formatted [0xNN]
    readonly property string hexId: {
        if (!sink) return ""
        var n = Number(sink.id) & 0xFF
        return "[0x" + n.toString(16).toUpperCase() + "]"
    }

    // Sample rate / bit depth — best effort from PipeWire props
    readonly property string sampleSpec: {
        if (!sink || !sink.properties) return ""
        // PipeWire node properties: try node.rate / audio.rate / object.rate
        var p = sink.properties
        var rate = p["node.rate"] || p["audio.rate"] || "48000"
        // Normalize "1/48000" form
        if (typeof rate === "string" && rate.indexOf("/") >= 0) rate = rate.split("/")[1]
        var hz = Math.round(Number(rate) / 1000)
        return hz + "kHz/24b"
    }

    // Chromatic glitch burst on volume change
    property bool _volGlitching: false
    Timer { id: _volGlitchTimer; interval: 90; repeat: false; onTriggered: root._volGlitching = false }
    onVolPercentChanged: {
        root._volGlitching = true
        _volGlitchTimer.restart()
    }

    implicitHeight: 120

    // ── Status row (◢ SIGNAL · ROUTED [0xNN]) ──────────────────
    Text {
        id: statusLabel
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 6
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        elide: Text.ElideRight
        text: {
            var status = muted ? "MUTED" : (sink ? "ROUTED" : "OFFLINE")
            var hex = (root.expanded && root.hexId !== "") ? " " + root.hexId : ""
            return "◢ SIGNAL · " + status + hex
        }
        font.family: "Oxanium"
        font.pixelSize: root.expanded ? 16 : 13
        font.letterSpacing: 2
        font.bold: true
        color: muted ? Colours.textMuted : CP.alpha(Colours.accentSecondary, 0.85)
        Behavior on color { CAnim {} }
    }

    // ── Master readout row: % + name + sample spec ─────────────
    Item {
        id: readoutRow
        anchors.top: statusLabel.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 4
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        height: 28

        ChromaticText {
            id: percentTxt
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: muted ? "MUTE" : (root.volPercent + "%")
            color: muted ? Colours.textMuted : Colours.accentPrimary
            font.family: "Oxanium"
            font.pixelSize: 22
            font.bold: true
            glitching: root._volGlitching
            offsetX: 2
            aberrationOpacity: 0.7
        }

        Column {
            anchors.left: percentTxt.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Item {
                id: nameViewport
                width: parent.width
                height: nameLabel.implicitHeight
                clip: true

                readonly property real marqueeOffset: marqueeActive ? marquee.offset : 0
                readonly property real marqueeGap: 40
                readonly property bool marqueeActive: nameLabel.implicitWidth > width

                onMarqueeActiveChanged: if (!marqueeActive) marquee.restart()

                Text {
                    id: nameLabel
                    x: nameViewport.marqueeActive ? nameViewport.marqueeOffset : 0
                    text: root.sinkName
                    font.family: "Oxanium"
                    font.pixelSize: root.expanded ? 14 : 12
                    font.letterSpacing: 1.5
                    font.bold: true
                    color: muted ? Colours.textMuted : Colours.accentSecondary
                }

                Text {
                    visible: nameViewport.marqueeActive
                    x: nameViewport.marqueeOffset + nameLabel.implicitWidth + nameViewport.marqueeGap
                    text: nameLabel.text
                    font: nameLabel.font
                    color: nameLabel.color
                }

                MarqueeDriver {
                    id: marquee
                    running: nameViewport.marqueeActive && root.visible
                    distance: nameLabel.implicitWidth + nameViewport.marqueeGap
                }
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: root.sampleSpec
                font.family: "Oxanium"
                font.pixelSize: 9
                font.letterSpacing: 1
                color: Colours.textMuted
            }
        }
    }

    // -- FLOW gauge -------------------------------------
    Item {
        id: flowSection
        anchors.top: readoutRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 4
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        height: 18

        Text {
            id: flowLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "▶ FLOW"
            font.family: "Oxanium"
            font.pixelSize: 12
            font.letterSpacing: 2
            font.bold: true
            color: CP.alpha(Colours.accentPrimary, 0.65)
        }

        FlowGauge {
            id: gauge
            anchors.left: flowLabel.right
            anchors.leftMargin: 6
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 14
            fillPercent: root.volRatio
            active: !root.muted && root.sink !== null
            muted: root.muted
            accent: Colours.accentPrimary
            onVolumeRequested: pct => {
                if (root.sink) {
                    AudioControlState.setVolume(root.sink, pct)
                    if (root.muted) AudioControlState.toggleMute(root.sink)
                }
            }
            onScrollRequested: direction => {
                if (root.sink && root.sink.audio) {
                    AudioControlState.setVolume(root.sink, root.sink.audio.volume + direction * 0.02)
                }
            }
        }
    }

    // ── Button row: MUTE (left) + EXPAND (right) ────────────────
    Item {
        id: buttonsRow
        anchors.top: flowSection.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 6
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        height: 22

        // MUTE button
        Item {
            id: muteBtn
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: muteTxt.implicitWidth + 16
            height: parent.height

            CutShape {
                anchors.fill: parent
                fillColor: muteMa.containsMouse ? CP.alpha(Colours.accentSecondary, 0.10) : "transparent"
                strokeColor: CP.alpha(Colours.accentSecondary, 0.35)
                strokeWidth: muteMa.containsMouse ? 1.5 : 1
                inset: 0.5
                cutBottomLeft: 6
                Behavior on fillColor   { CAnim {} }
                Behavior on strokeColor { CAnim {} }
            }
            Text {
                id: muteTxt
                anchors.centerIn: parent
                text: root.muted ? "UNMUTE" : "MUTE"
                font.family: "Oxanium"
                font.pixelSize: 9
                font.letterSpacing: 1.5
                color: muteMa.containsMouse ? Colours.accentSecondary : CP.alpha(Colours.accentSecondary, 0.65)
                Behavior on color { CAnim {} }
            }
            MouseArea {
                id: muteMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: AudioControlState.toggleMute(root.sink)
            }
        }

        // EXPAND/COLLAPSE chevron (right)
        Item {
            id: expandBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: expandTxt.implicitWidth + 26
            height: parent.height

            CutShape {
                anchors.fill: parent
                fillColor: expandMa.containsMouse ? CP.alpha(Colours.accentSecondary, 0.10) : "transparent"
                strokeColor: CP.alpha(Colours.accentSecondary, 0.35)
                strokeWidth: expandMa.containsMouse ? 1.5 : 1
                inset: 0.5
                cutBottomLeft: 6
                Behavior on fillColor   { CAnim {} }
                Behavior on strokeColor { CAnim {} }
            }
            Row {
                anchors.centerIn: parent
                spacing: 4
                Text {
                    text: "▼"
                    font.pixelSize: 10
                    color: expandMa.containsMouse ? Colours.accentSecondary : CP.alpha(Colours.accentSecondary, 0.8)
                    rotation: root.expanded ? 180 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on rotation { Anim {} }
                    Behavior on color { CAnim {} }
                }
                Text {
                    id: expandTxt
                    text: root.expanded ? "COLLAPSE" : "EXPAND"
                    font.family: "Oxanium"
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                    color: expandMa.containsMouse ? Colours.accentSecondary : CP.alpha(Colours.accentSecondary, 0.8)
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { CAnim {} }
                }
            }
            MouseArea {
                id: expandMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expandToggleRequested()
            }
        }
    }
}
