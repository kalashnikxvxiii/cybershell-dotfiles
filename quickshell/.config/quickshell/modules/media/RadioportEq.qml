// RadioportEq.qml -- the equalizer beside the Radioport, on the same EasyEffects backend as
// the audio popup's EQ tab (AudioControlState + audio-eq.sh). Its height comes from the
// host: the bands take whatever the fixed rows leave.
import QtQuick
import QtQuick.Shapes
import "../../common/Colors.js" as CP
import "../../common"

Item {
    id: root

    property string station

    readonly property var presets: ["Flat", "Bass", "Treble", "Vocal", "Pop", "Rock", "Jazz", "Classic"]
    readonly property var labels: ["31 Hz", "63 Hz", "125 Hz", "250 Hz", "500 Hz", "1 kHz", "2 kHz", "4 kHz", "8 kHz", "16 kHz"]

    // Fixed rows above and below the bands, and the frequency labels
    readonly property int bandsHeight: Math.max(120, root.height - 186 - 22 - 150)

    implicitWidth: 390

    function stepPreset(delta) {
        const n = root.presets.length
        const i = root.presets.indexOf(AudioControlState.eqPreset)
        AudioControlState.applyEqPreset(root.presets[(i + delta + n) % n])
    }

    // Shown at once; the file and EasyEffects catch up behind it
    function setBand(index, value) {
        const v = Math.max(-12, Math.min(12, Math.round(value)))
        if (v === AudioControlState.eqBands[index])
            return
        const bands = AudioControlState.eqBands.slice()
        bands[index] = v
        AudioControlState.eqBands = bands
        AudioControlState.setEqBand(index + 1, v)
        applyDelay.restart()
    }

    // Reloading the EasyEffects preset on every step of a drag would be wasted
    Timer {
        id: applyDelay
        interval: 400
        onTriggered: AudioControlState.applyEqCustom()
    }

    RadioportHeader {
        width: parent.width
        code: "DSP_EQ_PARAM"
        title: "EQUALIZER"
    }

    Text {
        y: 62
        text: "STATION"
        color: CP.alpha(CP.red, 0.9)
        font { family: "Oxanium"; pixelSize: 10; letterSpacing: 1 }
    }
    Rectangle {
        y: 76
        width: parent.width
        height: 1
        color: CP.alpha(CP.red, 0.7)
    }
    Text {
        y: 82
        width: parent.width
        elide: Text.ElideRight
        text: root.station
        color: CP.red
        font { family: "Oxanium"; pixelSize: 18; bold: true }
    }

    Text {
        anchors.centerIn: bandsRow
        visible: !AudioControlState.eqAvailable
        text: "EASYEFFECTS REQUIRED"
        color: CP.red
        font { family: "Oxanium"; pixelSize: 14; bold: true; letterSpacing: 2 }
    }

    OptionRow {
        y: 112
        label: "Per-station EQ"
        on: AudioControlState.eqPerStation
        onToggled: AudioControlState.setEqOption("per_station", on ? 0 : 1)
    }

    // Preset
    Text {
        y: 148
        height: 32
        verticalAlignment: Text.AlignVCenter
        text: "Preset"
        color: CP.alpha(CP.red, 0.9)
        font { family: "Oxanium"; pixelSize: 15 }
    }
    Item {
        x: 110
        y: 148
        width: parent.width - 110
        height: 30
        enabled: AudioControlState.eqAvailable

        CutShape {
            anchors.fill: parent
            cutBottomRight: 8
            fillColor: Qt.rgba(0.07, 0.02, 0.05, 0.75)
            strokeColor: CP.alpha(CP.red, 0.8)
            inset: 0.5
        }
        Arrow {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 16
            points: [[14, 0], [0, 8], [14, 16], [14, 0]]
            onClicked: root.stepPreset(-1)
        }
        Text {
            anchors.centerIn: parent
            text: AudioControlState.eqPreset
            color: CP.cyan
            font { family: "Oxanium"; pixelSize: 15 }
        }
        Arrow {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 16
            points: [[0, 0], [14, 8], [0, 16], [0, 0]]
            onClicked: root.stepPreset(1)
        }
    }

    // Bands
    Row {
        id: bandsRow
        y: 186
        spacing: 4
        opacity: AudioControlState.eqAvailable ? 1 : 0.25
        enabled: AudioControlState.eqAvailable

        Repeater {
            model: 10

            Column {
                id: band
                required property int index
                readonly property int value: AudioControlState.eqBands[index] ?? 0
                spacing: 6

                Item {
                    width: 35
                    height: root.bandsHeight

                    CutShape {
                        anchors.fill: parent
                        cutBottomRight: 9
                        fillColor: Qt.rgba(0.07, 0.02, 0.05, 0.75)
                        strokeColor: CP.alpha(CP.red, 0.8)
                        inset: 0.5
                    }
                    Arrow {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 8
                        width: 18
                        height: 15
                        points: [[9, 0], [18, 15], [0, 15], [9, 0]]
                        onClicked: root.setBand(band.index, band.value + 1)
                    }
                    Arrow {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8
                        width: 18
                        height: 15
                        points: [[0, 0], [18, 0], [9, 15], [0, 0]]
                        onClicked: root.setBand(band.index, band.value - 1)
                    }

                    // Track and its handle, from +12 at the top to -12 at the bottom
                    Item {
                        id: track
                        x: 0
                        y: 30
                        width: parent.width
                        height: parent.height - 60

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 2
                            height: parent.height
                            color: CP.alpha(CP.red, 0.35)
                        }
                        CutShape {
                            x: 2
                            y: (track.height - height) * (12 - band.value) / 24
                            width: parent.width - 4
                            height: 26
                            cutBottomRight: 6
                            fillColor: Qt.rgba(0.28, 0.06, 0.11, 1)
                            strokeColor: CP.alpha(CP.red, 0.9)
                            inset: 0.5

                            Text {
                                anchors.centerIn: parent
                                text: (band.value > 0 ? "+" : "") + band.value
                                color: CP.cyan
                                font { family: "Oxanium"; pixelSize: 13 }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true

                            function setFrom(y) {
                                root.setBand(band.index, 12 - 24 * (y - 13) / (track.height - 26))
                            }

                            onPressed: e => setFrom(e.y)
                            onPositionChanged: e => { if (pressed) setFrom(e.y) }
                            onWheel: e => root.setBand(band.index, band.value + (e.angleDelta.y > 0 ? 1 : -1))
                        }
                    }
                }
                Text {
                    width: 35
                    horizontalAlignment: Text.AlignHCenter
                    text: root.labels[band.index]
                    color: CP.alpha(CP.red, 0.9)
                    font { family: "Oxanium"; pixelSize: 9 }
                }
            }
        }
    }

    // Effects below the bands
    Column {
        anchors.bottom: parent.bottom
        width: parent.width
        spacing: 6

        OptionRow {
            label: "Even out loudness"
            on: AudioControlState.eqLoudness
            onToggled: AudioControlState.setEqOption("loudness", on ? 0 : 1)
        }
        OptionRow {
            label: "Soften peaks"
            on: AudioControlState.eqSoften
            onToggled: AudioControlState.setEqOption("soften", on ? 0 : 1)
        }
        OptionRow {
            label: "Limiter"
            on: AudioControlState.eqLimiter
            onToggled: AudioControlState.setEqOption("limiter", on ? 0 : 1)
        }

        // Volume boost: 0..12 dB
        Item {
            width: parent.width
            height: 30
            enabled: AudioControlState.eqAvailable

            Text {
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                text: "Volume boost"
                color: CP.alpha(CP.red, 0.9)
                font { family: "Oxanium"; pixelSize: 15 }
            }
            Item {
                x: 150
                width: parent.width - 150
                height: parent.height

                CutShape {
                    anchors.fill: parent
                    cutBottomRight: 8
                    fillColor: Qt.rgba(0.07, 0.02, 0.05, 0.75)
                    strokeColor: CP.alpha(CP.red, 0.8)
                    inset: 0.5
                }
                Arrow {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12
                    height: 14
                    points: [[12, 0], [0, 7], [12, 14], [12, 0]]
                    onClicked: AudioControlState.setEqOption("boost", Math.max(0, AudioControlState.eqBoost - 1))
                }
                Rectangle {
                    x: 32
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 64
                    height: 2
                    color: CP.alpha(CP.red, 0.35)
                }
                CutShape {
                    x: 32 + (parent.width - 64 - width) * AudioControlState.eqBoost / 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 62
                    height: 24
                    cutBottomRight: 6
                    fillColor: Qt.rgba(0.28, 0.06, 0.11, 1)
                    strokeColor: CP.alpha(CP.red, 0.9)
                    inset: 0.5
                    Text {
                        anchors.centerIn: parent
                        text: "+" + AudioControlState.eqBoost + " dB"
                        color: CP.cyan
                        font { family: "Oxanium"; pixelSize: 12 }
                    }
                }
                Arrow {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12
                    height: 14
                    points: [[0, 0], [12, 7], [0, 14], [0, 0]]
                    onClicked: AudioControlState.setEqOption("boost", Math.min(12, AudioControlState.eqBoost + 1))
                }
            }
        }
    }

    // Label, ON/OFF and a switch whose block moves to the lit side
    component OptionRow: Item {
        id: option
        property string label
        property bool on: false
        signal toggled()

        width: root.width
        height: 30
        enabled: AudioControlState.eqAvailable

        Text {
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: option.label
            color: CP.alpha(CP.red, 0.9)
            font { family: "Oxanium"; pixelSize: 15 }
        }
        Text {
            anchors.right: toggle.left
            anchors.rightMargin: 12
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: option.on ? "ON" : "OFF"
            color: option.on ? CP.cyan : CP.red
            font { family: "Oxanium"; pixelSize: 14 }
        }
        Item {
            id: toggle
            anchors.right: parent.right
            width: 116
            height: parent.height

            CutShape {
                anchors.fill: parent
                cutBottomRight: 8
                fillColor: Qt.rgba(0.07, 0.02, 0.05, 0.75)
                strokeColor: CP.alpha(CP.red, 0.8)
                inset: 0.5
            }
            CutShape {
                x: option.on ? parent.width - width - 3 : 3
                y: 3
                width: 52
                height: parent.height - 6
                cutBottomRight: 6
                fillColor: option.on ? CP.alpha(CP.cyan, 0.8) : CP.alpha(CP.red, 0.55)
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: option.toggled()
            }
        }
    }

    // An outlined triangle that takes clicks
    component Arrow: Item {
        id: arrow
        property var points: []
        signal clicked()

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: hit.containsMouse ? CP.white : CP.cyan
                strokeWidth: 1.5
                fillColor: "transparent"
                joinStyle: ShapePath.MiterJoin
                PathPolyline { path: arrow.points.map(p => Qt.point(p[0], p[1])) }
            }
        }
        MouseArea {
            id: hit
            anchors.fill: parent
            anchors.margins: -5
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: arrow.clicked()
        }
    }
}
