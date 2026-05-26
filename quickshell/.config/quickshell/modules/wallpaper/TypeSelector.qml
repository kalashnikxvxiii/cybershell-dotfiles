import "../../common/Colors.js" as CP
import "../../common"
import QtQuick
import QtQuick.Effects

Item {
    id: root

    property string selectedType: "fade"
    signal typeSelected(string type)

    readonly property var groups: [
        { name: "BASIC",   accent: CP.yellow,  types: ["none", "fade"] },
        { name: "WIPE",    accent: CP.cyan,    types: ["left", "right", "top", "bottom", "wipe"] },
        { name: "RADIAL",  accent: CP.magenta, types: ["grow", "outer"] },
        { name: "SPECIAL", accent: CP.neon,    types: ["wave", "rand-wipe", "random"] }
    ]

    implicitHeight: column.implicitHeight

    Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 12

        Repeater {
            model: root.groups
            delegate: Column {
                id: groupColumn
                required property var modelData
                width: column.width
                spacing: 6

                Row {
                    spacing: 6
                    Text {
                        text: "◢"
                        color: groupColumn.modelData.accent
                        font.pixelSize: 9
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: groupColumn.modelData.name
                        color: groupColumn.modelData.accent
                        font.family: "Oxanium"
                        font.pixelSize: 9
                        font.letterSpacing: 2.5
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Rectangle {
                        width: 60
                        height: 1
                        color: CP.alpha(groupColumn.modelData.accent, 0.25)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Flow {
                    width: parent.width
                    spacing: 5

                    Repeater {
                        model: groupColumn.modelData.types
                        delegate: Item {
                            id: chipItem
                            required property string modelData
                            readonly property bool _selected: root.selectedType === modelData
                            readonly property color _accent: groupColumn.modelData.accent

                            width: chipText.implicitWidth + 18
                            height: 22

                            CutShape {
                                id: chipBg
                                anchors.fill: parent
                                fillColor: chipItem._selected
                                    ? CP.alpha(chipItem._accent, 0.30)
                                    : (chipMa.containsMouse
                                        ? CP.alpha(chipItem._accent, 0.10)
                                        : CP.alpha(CP.void2, 0.55))
                                strokeColor: chipItem._selected
                                    ? chipItem._accent
                                    : CP.alpha(chipItem._accent, 0.32)
                                strokeWidth: chipItem._selected ? 1.5 : 1
                                inset: 0.5
                                cutTopLeft: 3
                                cutBottomRight: 3
                                Behavior on fillColor   { ColorAnimation { duration: 120 } }
                                Behavior on strokeColor { ColorAnimation { duration: 120 } }

                                layer.enabled: chipItem._selected
                                layer.effect: MultiEffect {
                                    shadowEnabled: true
                                    shadowBlur: 1.0
                                    shadowColor: chipItem._accent
                                    shadowOpacity: 0.7
                                    shadowHorizontalOffset: 0
                                    shadowVerticalOffset: 0
                                }
                            }

                            Text {
                                id: chipText
                                anchors.centerIn: parent
                                text: chipItem.modelData.toUpperCase()
                                font.family: "Oxanium"
                                font.pixelSize: 9
                                font.letterSpacing: 1.5
                                color: chipItem._selected ? "white" : Colours.textMuted
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            MouseArea {
                                id: chipMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.typeSelected(chipItem.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
