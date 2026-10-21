// ~/dotfiles/quickshell/.config/quickshell/modules/bar/AudioControl/tabs/EqualizerTab.qml
// Signal Flow EQ tab — preset chips + APPLY + FrequencyResponseCurve hero + CURRENT BAND detail
import "../../../../common/Colors.js" as CP
import "../../../../common"
import "../../../../common/effects"
import ".." as AC
import QtQuick

Item {
    id: root
    implicitHeight: scroll.contentHeight

    readonly property var presets: ["Flat","Bass","Treble","Vocal","Pop","Rock","Jazz","Classic"]
    readonly property var bandLabels: ["31","63","125","250","500","1k","2k","4k","8k","16k"]
    readonly property var bandFreqs:  [31,63,125,250,500,1000,2000,4000,8000,16000]

    // Glitch the preset name briefly on change
    property bool _presetGlitching: false
    property string _lastPreset: AudioControlState.eqPreset
    Timer { id: _presetGlitchTimer; interval: 110; repeat: false; onTriggered: root._presetGlitching = false }
    Connections {
        target: AudioControlState
        function onEqPresetChanged() {
            if (AudioControlState.eqPreset !== root._lastPreset) {
                root._lastPreset = AudioControlState.eqPreset
                root._presetGlitching = true
                _presetGlitchTimer.restart()
            }
        }
    }

    // ── EasyEffects unavailable banner ───────────────────────────
    Item {
        anchors.fill: parent
        visible: !AudioControlState.eqAvailable
        Column {
            anchors.centerIn: parent
            spacing: 8
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "⚠ EASYEFFECTS REQUIRED"
                font.family: "Oxanium"
                font.pixelSize: 14
                font.letterSpacing: 3
                font.bold: true
                color: CP.red
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "sudo pacman -S easyeffects"
                font.family: "JetBrains Mono"
                font.pixelSize: 12
                color: Colours.textMuted
            }
        }
    }

    // ── Main EQ UI ───────────────────────────────────────────────
    AC.TabScroll {
        id: scroll
        anchors.fill: parent
        spacing: 8
        visible: AudioControlState.eqAvailable

        // ── PRESETS section header ──────────────────────────────
        AC.SectionHeader {
            width: parent.width
            label: "PRESETS"
            accent: CP.neon
            divider: false
        }

        // ── Chromatic current preset readout ────────────────────
        Item {
            width: parent.width
            height: 16
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 17
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Text {
                    text: "· CURRENT:"
                    color: CP.alpha(CP.neon, 0.65)
                    font.family: "Oxanium"
                    font.pixelSize: 12
                    font.letterSpacing: 2
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
                ChromaticText {
                    text: AudioControlState.eqPreset.toUpperCase()
                    color: CP.neon
                    font.family: "Oxanium"
                    font.pixelSize: 14
                    font.letterSpacing: 2
                    font.bold: true
                    glitching: root._presetGlitching
                    offsetX: 2
                    aberrationOpacity: 0.7
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // ── Preset chips + Apply button row ─────────────────────
        Item {
            width: parent.width
            height: presetFlow.height

            Flow {
                id: presetFlow
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: applyBtn.left
                anchors.rightMargin: 6
                spacing: 4

                Repeater {
                    model: root.presets
                    delegate: Item {
                        id: presetChip
                        required property string modelData
                        width: chipTxt.implicitWidth + 14
                        height: 20
                        readonly property bool active: AudioControlState.eqPreset === modelData

                        CutShape {
                            anchors.fill: parent
                            fillColor: presetChip.active
                                       ? CP.alpha(CP.neon, 0.20)
                                       : (chipMa.containsMouse
                                          ? CP.alpha(CP.neon, 0.10)
                                          : Colours.moduleBgAlt)
                            strokeColor: presetChip.active ? CP.neon : CP.alpha(CP.neon, 0.30)
                            strokeWidth: presetChip.active ? 1.5 : 1
                            inset: 0.5
                            cutBottomRight: 6
                            Behavior on fillColor   { CAnim {} }
                            Behavior on strokeColor { CAnim {} }
                        }
                        Rectangle {
                            visible: presetChip.active
                            width: 4; height: 4
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: 3
                            color: CP.neon
                        }
                        Text {
                            id: chipTxt
                            anchors.centerIn: parent
                            text: modelData.toUpperCase()
                            font.family: "Oxanium"
                            font.pixelSize: 11
                            font.letterSpacing: 1
                            font.bold: true
                            color: presetChip.active ? "white" : CP.alpha(CP.neon, 0.7)
                            Behavior on color { CAnim {} }
                        }
                        MouseArea {
                            id: chipMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: AudioControlState.applyEqPreset(modelData)
                        }
                    }
                }
            }

            // ── Apply button ────────────────────────────────────
            Item {
                id: applyBtn
                anchors.right: parent.right
                anchors.top: parent.top
                width: applyTxt.implicitWidth + 22
                height: 22

                CutShape {
                    anchors.fill: parent
                    fillColor: AudioControlState.eqPending
                               ? CP.alpha(Colours.accentPrimary, 0.20)
                               : (applyMa.containsMouse ? CP.alpha(Colours.accentSecondary, 0.10) : "transparent")
                    strokeColor: AudioControlState.eqPending
                                 ? Colours.accentPrimary
                                 : CP.alpha(Colours.accentSecondary, 0.35)
                    strokeWidth: AudioControlState.eqPending ? 1.5 : 1
                    inset: 0.5
                    cutBottomLeft: 6
                    Behavior on fillColor   { CAnim {} }
                    Behavior on strokeColor { CAnim {} }

                    opacity: eqPendingPulse.k
                    Pulse {
                        id: eqPendingPulse
                        running: root.visible && AudioControlState.eqPending
                        from: 1.0; to: 0.55; halfMs: 1200; sine: true
                    }
                }
                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: "⊕"
                        font.pixelSize: 14
                        color: AudioControlState.eqPending ? Colours.accentPrimary : Colours.accentSecondary
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { CAnim {} }
                    }
                    Text {
                        id: applyTxt
                        text: AudioControlState.eqPending ? "APPLY" : "SAVED"
                        font.family: "Oxanium"
                        font.pixelSize: 12
                        font.letterSpacing: 1.5
                        font.bold: true
                        color: AudioControlState.eqPending ? Colours.accentPrimary : Colours.accentSecondary
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { CAnim {} }
                    }
                }
                MouseArea {
                    id: applyMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { if (AudioControlState.eqPending) AudioControlState.applyEqCustom() }
                }
            }
        }

        // ── FREQUENCY RESPONSE section header ───────────────────
        AC.SectionHeader {
            width: parent.width
            label: "FREQUENCY RESPONSE"
            trail: "-12 / +12 dB · LIVE"
            accent: CP.neon
        }

        // ── Hero canvas: FrequencyResponseCurve ─────────────────
        Item {
            width: parent.width
            height: 140

            AC.FrequencyResponseCurve {
                id: curveCanvas
                anchors.fill: parent
                onBandSelected: idx => AudioControlState.eqSelectedBand = idx
            }
        }

        // ── X-axis labels under the curve ───────────────────────
        Item {
            width: parent.width
            height: 12
            Repeater {
                model: 10
                delegate: Text {
                    required property int index
                    text: root.bandLabels[index]
                    font.family: "Oxanium"
                    font.pixelSize: 9
                    font.letterSpacing: 1
                    color: CP.alpha(CP.neon, 0.65)
                    // Position at the band's X (approximation; precise math is in FrequencyResponseCurve)
                    x: {
                        var freqs = [31, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
                        var logMin = Math.log10(freqs[0])
                        var logMax = Math.log10(freqs[9])
                        var t = (Math.log10(freqs[index]) - logMin) / (logMax - logMin)
                        return t * parent.width - implicitWidth / 2
                    }
                }
            }
        }

        // ── CURRENT BAND detail ─────────────────────────────────
        AC.SectionHeader {
            width: parent.width
            label: "CURRENT BAND"
            trail: AudioControlState.eqSelectedBand >= 0 ? "DRAG TO EDIT" : "TAP A NODE"
            accent: CP.neon
        }

        Item {
            width: parent.width
            height: 16

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 17
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                visible: AudioControlState.eqSelectedBand >= 0

                Row {
                    spacing: 4
                    Text { text: "SELECTED"; font.family: "Oxanium"; font.pixelSize: 8; font.letterSpacing: 1; font.bold: true; color: CP.neon }
                    Text {
                        text: AudioControlState.eqSelectedBand >= 0 ? root.bandFreqs[AudioControlState.eqSelectedBand] + " Hz" : "—"
                        font.family: "Oxanium"; font.pixelSize: 10; color: "white"
                    }
                }
                Row {
                    spacing: 4
                    Text { text: "GAIN"; font.family: "Oxanium"; font.pixelSize: 8; font.letterSpacing: 1; font.bold: true; color: CP.neon }
                    Text {
                        text: AudioControlState.eqSelectedBand >= 0 ? (AudioControlState.eqBands[AudioControlState.eqSelectedBand] > 0 ? "+" : "") + AudioControlState.eqBands[AudioControlState.eqSelectedBand] + " dB" : "—"
                        font.family: "Oxanium"; font.pixelSize: 10; font.bold: true; color: Colours.accentPrimary
                    }
                }
                Row {
                    spacing: 4
                    Text { text: "Q"; font.family: "Oxanium"; font.pixelSize: 8; font.letterSpacing: 1; font.bold: true; color: CP.neon }
                    Text { text: "1.0"; font.family: "Oxanium"; font.pixelSize: 10; color: "white" }
                }
                Row {
                    spacing: 4
                    Text { text: "MODE"; font.family: "Oxanium"; font.pixelSize: 8; font.letterSpacing: 1; font.bold: true; color: CP.neon }
                    Text { text: "BELL"; font.family: "Oxanium"; font.pixelSize: 10; color: "white" }
                }
            }
        }
    }
}
