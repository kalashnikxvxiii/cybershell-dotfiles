// ~/dotfiles/quickshell/.config/quickshell/modules/bar/AudioControl/tabs/InputsTab.qml
// Signal Flow: SOURCE CAPTURE (EndpointCard with oscilloscope) + OTHER SOURCES + SIGNAL ANALYSIS
import "../../../../common/Colors.js" as CP
import "../../../../common"
import ".." as AC
import QtQuick

Item {
    id: root
    implicitHeight: scroll.contentHeight

    readonly property int otherCount: {
        var n = 0
        var arr = AudioControlState.inputNodes
        for (var i = 0; i < arr.length; i++)
            if (arr[i] !== AudioControlState.focusedSource) n++
        return n
    }

    AC.TabScroll {
        id: scroll
        anchors.fill: parent
        spacing: 10

        // ── Empty state ─────────────────────────────────────────
        Item {
            visible: AudioControlState.inputNodes.length === 0
            width: parent.width
            height: 48
            Column {
                anchors.centerIn: parent
                spacing: 4
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "◢ NO INPUT DEVICES"
                    font.family: "Oxanium"
                    font.pixelSize: 12
                    font.letterSpacing: 2.5
                    font.bold: true
                    color: CP.alpha(Colours.textMuted, 0.7)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "AWAITING SOURCE · MIC OFFLINE?"
                    font.family: "Oxanium"
                    font.pixelSize: 9
                    font.letterSpacing: 1.5
                    color: CP.alpha(Colours.textMuted, 0.4)
                }
            }
        }

        // ── Section: SOURCE CAPTURE ─────────────────────────────
        AC.SectionHeader {
            visible: AudioControlState.focusedSource !== null
            width: parent.width
            label: "SOURCE CAPTURE"
            trail: "INBOUND SIGNAL · RIGHT → MUTE"
            accent: CP.magenta
        }

        AC.EndpointCard {
            visible: AudioControlState.focusedSource !== null
            width: parent.width
            node: AudioControlState.focusedSource
            mode: "source"
            accent: CP.magenta
            showOscilloscope: true
        }

        // ── Section: OTHER SOURCES ──────────────────────────────
        AC.SectionHeader {
            visible: root.otherCount > 0
            width: parent.width
            label: "OTHER SOURCES"
            trail: root.otherCount + " AVAILABLE · RIGHT → MUTE"
            accent: CP.magenta
        }
        
        Column {
            id: listCol
            width: parent.width
            spacing: 4

            Repeater {
                model: AudioControlState.inputNodes
                delegate: AC.AudioDeviceRow {
                    required property var modelData
                    width: listCol.width
                    visible: modelData !== AudioControlState.focusedSource
                    node: modelData
                    mode: "selectable"
                    accent: CP.magenta
                    onSelectRequested: AudioControlState._selectedSource = modelData
                }
            }
        }

        // ── SIGNAL ANALYSIS (MVP: hardcoded placeholders) ───────
        AC.SectionHeader {
            width: parent.width
            label: "SIGNAL ANALYSIS"
            trail: "LIVE METRICS · NOMINAL"
            accent: CP.magenta
        }

        Grid {
            width: parent.width
            columns: 3
            columnSpacing: 12
            rowSpacing: 4

            // Row 1
            Row {
                spacing: 4
                Text { text: "NOISE FLOOR"; font.family: "Oxanium"; font.pixelSize: 9; font.letterSpacing: 1; font.bold: true; color: CP.magenta }
                Text { text: "-72.4dB"; font.family: "Oxanium"; font.pixelSize: 10; color: "white" }
            }
            Row {
                spacing: 4
                Text { text: "PEAK"; font.family: "Oxanium"; font.pixelSize: 9; font.letterSpacing: 1; font.bold: true; color: CP.magenta }
                Text { text: "-12.8dB"; font.family: "Oxanium"; font.pixelSize: 10; color: "white" }
            }
            Row {
                spacing: 4
                Text { text: "SNR"; font.family: "Oxanium"; font.pixelSize: 9; font.letterSpacing: 1; font.bold: true; color: CP.magenta }
                Text { text: "59.6dB"; font.family: "Oxanium"; font.pixelSize: 10; color: "white" }
            }
            // Row 2
            Row {
                spacing: 4
                Text { text: "CLIP COUNT"; font.family: "Oxanium"; font.pixelSize: 9; font.letterSpacing: 1; font.bold: true; color: CP.magenta }
                Text { text: "0"; font.family: "Oxanium"; font.pixelSize: 10; color: "white" }
            }
            Row {
                spacing: 4
                Text { text: "RMS"; font.family: "Oxanium"; font.pixelSize: 9; font.letterSpacing: 1; font.bold: true; color: CP.magenta }
                Text { text: "-28.4dB"; font.family: "Oxanium"; font.pixelSize: 10; color: "white" }
            }
            Row {
                spacing: 4
                Text { text: "CH"; font.family: "Oxanium"; font.pixelSize: 9; font.letterSpacing: 1; font.bold: true; color: CP.magenta }
                Text { text: "1.0 MONO"; font.family: "Oxanium"; font.pixelSize: 10; color: "white" }
            }
        }
    }
}
