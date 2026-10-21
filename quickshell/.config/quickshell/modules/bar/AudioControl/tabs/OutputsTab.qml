// ~/dotfiles/quickshell/.config/quickshell/modules/bar/AudioControl/tabs/OutputsTab.qml
// Signal Flow: SINK ROUTING (EndpointCard hero) + ALTERNATIVE ENDPOINTS list + PIPELINE mini-viz
import "../../../../common/Colors.js" as CP
import "../../../../common"
import "../../../../common/effects"
import ".." as AC
import QtQuick

Item {
    id: root
    implicitHeight: scroll.contentHeight

    // Moves the pipeline particles of both links: a Ticker instead of one
    // NumberAnimation per particle, which kept the popup rendering at the
    // monitor's refresh rate
    Ticker { id: linkTick; running: root.visible }

    readonly property int otherCount: {
        var n = 0
        var arr = AudioControlState.outputNodes
        for (var i = 0; i < arr.length; i++)
            if (arr[i] !== AudioControlState.focusedSink) n++
        return n
    }

    AC.TabScroll {
        id: scroll
        anchors.fill: parent
        spacing: 10

        // ── Empty state ─────────────────────────────────────────
        Item {
            visible: AudioControlState.outputNodes.length === 0
            width: parent.width
            height: 48
            Column {
                anchors.centerIn: parent
                spacing: 4
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "◢ NO OUTPUT DEVICES"
                    font.family: "Oxanium"
                    font.pixelSize: 12
                    font.letterSpacing: 2.5
                    font.bold: true
                    color: CP.alpha(Colours.textMuted, 0.7)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "AWAITING SINK · PIPEWIRE OFFLINE?"
                    font.family: "Oxanium"
                    font.pixelSize: 9
                    font.letterSpacing: 1.5
                    color: CP.alpha(Colours.textMuted, 0.4)
                }
            }
        }

        // ── Section: SINK ROUTING ───────────────────────────────
        AC.SectionHeader {
            visible: AudioControlState.focusedSink !== null
            width: parent.width
            label: "SINK ROUTING"
            trail: "1 ACTIVE / " + root.otherCount + " IDLE"
            accent: Colours.accentSecondary
        }

        AC.EndpointCard {
            visible: AudioControlState.focusedSink !== null
            width: parent.width
            node: AudioControlState.focusedSink
            mode: "sink"
            accent: Colours.accentSecondary
            showOscilloscope: false
        }

        // ── Section: ALTERNATIVE ENDPOINTS ──────────────────────
        AC.SectionHeader {
            visible: root.otherCount > 0
            width: parent.width
            label: "ALTERNATIVE ENDPOINTS"
            trail: "CLICK → REROUTE · RIGHT → MUTE"
            accent: Colours.accentSecondary
        }

        Column {
            id: listCol
            width: parent.width
            spacing: 4

            Repeater {
                model: AudioControlState.outputNodes
                delegate: AC.AudioDeviceRow {
                    required property var modelData
                    width: listCol.width
                    visible: modelData !== AudioControlState.focusedSink
                    node: modelData
                    mode: "selectable"
                    accent: Colours.accentSecondary
                    onSelectRequested: AudioControlState._selectedSink = modelData
                }
            }
        }

        // ── PIPELINE mini-viz (bottom) ──────────────────────────
        AC.SectionHeader {
            width: parent.width
            label: "PIPELINE"
            trail: AudioControlState.streamNodes.length + " STREAMS → EQ:" + AudioControlState.eqPreset.toUpperCase() + " → " + (AudioControlState.defaultSink ? "OUT" : "—")
            accent: Colours.accentSecondary
        }

        Item {
            width: parent.width
            height: 28

            // 3 boxes connected by particles
            Item {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 24

                Rectangle {
                    id: srcBox
                    anchors.left: parent.left
                    width: 80
                    height: parent.height
                    color: CP.alpha(Colours.accentPrimary, 0.15)
                    border.color: CP.alpha(Colours.accentPrimary, 0.5)
                    border.width: 0.7
                    Column {
                        anchors.centerIn: parent
                        spacing: 1
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "SOURCES"
                            font.family: "Oxanium"
                            font.pixelSize: 9
                            font.letterSpacing: 1
                            font.bold: true
                            color: Colours.accentPrimary
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: AudioControlState.streamNodes.length + " ACTIVE"
                            font.family: "Oxanium"
                            font.pixelSize: 9
                            color: Colours.textMuted
                        }
                    }
                }

                // Line + 2 particles (src → eq)
                Item {
                    id: link1
                    anchors.left: srcBox.right
                    anchors.right: eqBox.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: 8
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 0.8
                        color: CP.alpha(Colours.accentPrimary, 0.6)
                    }
                    Repeater {
                        model: 2
                        delegate: Rectangle {
                            required property int index
                            width: 2; height: 2
                            color: Colours.accentPrimary
                            opacity: 1.0 - index * 0.4
                            anchors.verticalCenter: parent.verticalCenter
                            x: linkTick.elapsed > 0
                                ? link1.width * ((linkTick.elapsed % 2400) / 2400)
                                : index * (link1.width / 2)
                        }
                    }
                }

                Rectangle {
                    id: eqBox
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 80
                    height: parent.height
                    color: CP.alpha(CP.neon, 0.15)
                    border.color: CP.alpha(CP.neon, 0.6)
                    border.width: 0.7
                    Column {
                        anchors.centerIn: parent
                        spacing: 1
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "EQ:" + AudioControlState.eqPreset.toUpperCase()
                            font.family: "Oxanium"
                            font.pixelSize: 9
                            font.letterSpacing: 1
                            font.bold: true
                            color: CP.neon
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: AudioControlState.eqAvailable ? "10-BAND" : "BYPASSED"
                            font.family: "Oxanium"
                            font.pixelSize: 9
                            color: Colours.textMuted
                        }
                    }
                }

                Item {
                    id: link2
                    anchors.left: eqBox.right
                    anchors.right: sinkBox.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: 8
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 0.8
                        color: CP.alpha(Colours.accentSecondary, 0.6)
                    }
                    Repeater {
                        model: 2
                        delegate: Rectangle {
                            required property int index
                            width: 2; height: 2
                            color: Colours.accentSecondary
                            opacity: 1.0 - index * 0.4
                            anchors.verticalCenter: parent.verticalCenter
                            x: linkTick.elapsed > 0
                                ? link2.width * ((linkTick.elapsed % 2400) / 2400)
                                : index * (link2.width / 2)
                        }
                    }
                }

                Rectangle {
                    id: sinkBox
                    anchors.right: parent.right
                    width: 80
                    height: parent.height
                    color: CP.alpha(Colours.accentSecondary, 0.15)
                    border.color: CP.alpha(Colours.accentSecondary, 0.6)
                    border.width: 0.7
                    Column {
                        anchors.centerIn: parent
                        spacing: 1
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "SINK OUT"
                            font.family: "Oxanium"
                            font.pixelSize: 9
                            font.letterSpacing: 1
                            font.bold: true
                            color: Colours.accentSecondary
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: sinkBox.width - 6
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: AudioControlState.defaultSink
                                ? (AudioControlState.defaultSink.description
                                || AudioControlState.defaultSink.name || "—").substring(0, 8).toUpperCase()
                                : "—"
                            font.family: "Oxanium"
                            font.pixelSize: 9
                            color: Colours.textMuted
                        }
                    }
                }
            }
        }
    }
}
