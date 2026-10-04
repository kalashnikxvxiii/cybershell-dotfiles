// ~/dotfiles/quickshell/.config/quickshell/modules/bar/AudioControl/AudioTabBar.qml
import "../../../common/Colors.js" as CP
import "../../../common"
import QtQuick
import QtQuick.Effects

Item {
    id: root
    implicitHeight: 32

    readonly property var tabs: [
        { id: "outputs", label: "OUT",  accent: CP.cyan    },
        { id: "inputs",  label: "IN",   accent: CP.magenta },
        { id: "apps",    label: "APPS", accent: CP.yellow  },
        { id: "eq",      label: "EQ",   accent: CP.neon    }
    ]

    Row {
        id: row
        anchors.fill: parent
        spacing: 4

        Repeater {
            model: root.tabs
            delegate: Item {
                id: chip
                required property var modelData
                required property int index
                width: (row.width - 12) / 4
                height: row.height

                readonly property bool active: AudioControlState.activeTab === modelData.id

                CutShape {
                    anchors.fill: parent
                    fillColor: active
                            ? CP.alpha(modelData.accent, 0.20)
                            : (chipMa.containsMouse
                            ? CP.alpha(modelData.accent, 0.10)
                            : Colours.moduleBgAlt)
                    strokeColor: active
                                ? modelData.accent
                                : CP.alpha(modelData.accent, 0.30)
                    strokeWidth: active ? 1.5 : 1
                    inset: 0.5
                    cutBottomRight: 8
                    Behavior on fillColor   { CAnim {} }
                    Behavior on strokeColor { CAnim {} }

                    layer.enabled: chip.active
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Colours.glowFor(modelData.accent)
                        shadowOpacity: Colours.glowOpacity
                        shadowBlur: 0.7
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 0
                    }
                }

                // Active marker dot (4×4 top-left, canonical PresetGrid pattern)
                Rectangle {
                    visible: chip.active
                    width: 4; height: 4
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 3
                    color: modelData.accent
                }

                // Shortcut number (1 - 4)
                Text {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 3
                    text: chip.index + 1
                    font.family: "Oxanium"
                    font.pixelSize: 8
                    font.letterSpacing: 0.5
                    color: chip.active ? CP.alpha("white", 0.75)
                                       : CP.alpha(modelData.accent, 0.5)
                    Behavior on color { CAnim {} }
                }


                Text {
                    anchors.centerIn: parent
                    text: modelData.label
                    font.family: "Oxanium"
                    font.pixelSize: 18
                    font.letterSpacing: 1.2
                    font.bold: true
                    color: chip.active ? "white" : CP.alpha(modelData.accent, 0.8)
                    Behavior on color { CAnim {} }
                }

                // Bold underline indicator under active tab
                Rectangle {
                    visible: chip.active
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -1
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    height: 2
                    color: modelData.accent
                }

                MouseArea {
                    id: chipMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AudioControlState.activeTab = modelData.id
                }
            }
        }
    }
}
