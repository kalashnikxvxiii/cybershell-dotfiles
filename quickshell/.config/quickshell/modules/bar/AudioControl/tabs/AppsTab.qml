// ~/dotfiles/quickshell/.config/quickshell/modules/bar/AudioControl/tabs/AppsTab.qml
// Signal Flow: STREAM PIPELINE (StreamFlowNode list) + MIXDOWN summary bar
import "../../../../common/Colors.js" as CP
import "../../../../common"
import ".." as AC
import QtQuick

Item {
    id: root
    implicitHeight: scroll.contentHeight

    readonly property int streamCount: AudioControlState.streamNodes.length
    readonly property int mutedCount: {
        var n = 0
        var arr = AudioControlState.streamNodes
        for (var i = 0; i < arr.length; i++) {
            if (arr[i].audio && arr[i].audio.muted) n++
        }
        return n
    }

    AC.TabScroll {
        id: scroll
        anchors.fill: parent
        spacing: 10

        // Empty state
        Item {
            visible: root.streamCount === 0
            width: parent.width
            height: 48
            Column {
                anchors.centerIn: parent
                spacing: 4
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "◢ NO ACTIVE STREAMS"
                    font.family: "Oxanium"
                    font.pixelSize: 12
                    font.letterSpacing: 2.5
                    font.bold: true
                    color: CP.alpha(Colours.textMuted, 0.7)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "AWAITING PIPEWIRE STREAMS"
                    font.family: "Oxanium"
                    font.pixelSize: 9
                    font.letterSpacing: 1.5
                    color: CP.alpha(Colours.textMuted, 0.4)
                }
            }
        }

        AC.SectionHeader {
            visible: root.streamCount > 0
            width: parent.width
            label: "STREAM PIPELINE"
            trail: root.streamCount + " ACTIVE STREAMS → MASTER · CLICK ROW = MUTE"
            accent: Colours.accentPrimary
        }
        Column {
            id: listCol
            width: parent.width
            spacing: 4

            Repeater {
                model: AudioControlState.streamNodes
                delegate: AC.StreamFlowNode {
                    required property var modelData
                    width: listCol.width
                    streamNode: modelData
                    accent: Colours.accentPrimary
                }
            }
        }

        // ── MIXDOWN summary bar ─────────────────────────────────
        AC.SectionHeader {
            visible: root.streamCount > 0
            width: parent.width
            label: "MIXDOWN"
            trail: "COMBINED SIGNAL · " + (root.streamCount - root.mutedCount) + " ACTIVE / " + root.mutedCount + " MUTED"
            accent: Colours.accentPrimary
        }

        Rectangle {
            visible: root.streamCount > 0
            width: parent.width
            height: 40
            color: CP.alpha(Colours.accentPrimary, 0.06)
            border.color: CP.alpha(Colours.accentPrimary, 0.3)
            border.width: 0.7

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: "▶ SUMMED OUTPUT"
                font.family: "Oxanium"
                font.pixelSize: 9
                font.letterSpacing: 1.5
                font.bold: true
                color: Colours.accentPrimary
            }

            // Mini cava bars (right side)
            Row {
                id: cavaBars
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                height: 18
                Repeater {
                    model: 19
                    delegate: Rectangle {
                        required property int index
                        width: 2
                        height: Math.max(2, 18 * (Audio.cava && Audio.cava.values && Audio.cava.values.length > index ? Audio.cava.values[index] : 0))
                        anchors.verticalCenter: parent.verticalCenter
                        color: Colours.accentPrimary
                        opacity: 0.85
                    }
                }
            }
        }
    }
}
