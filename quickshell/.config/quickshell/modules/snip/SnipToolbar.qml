// SnipToolbar.qml — the action tabs that float over the frozen screen.
//
// It is on screen for the whole selector session, which is what makes the
// action changeable mid-selection: the keybind only arms the initial tab, and
// switching afterwards costs a click or a number key, not a restart.
//
// Each tab carries its own accent rather than a shared one, because here the
// colour IS the information -- it is the only thing distinguishing four
// otherwise identical chips.
import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/effects"
import "../../common/Colors.js" as CP

Item {
    id: root

    implicitWidth: layout.width + 28
    implicitHeight: 64

    CutShape {
        anchors.fill: parent
        fillColor: CP.alpha(CP.void2, 0.88)
        strokeColor: CP.alpha(SnipState.currentAccent, 0.55)
        strokeWidth: 1
        inset: 0.5
        cutTopRight: 16
        cutBottomLeft: 16

        Behavior on strokeColor { CAnim {} }
    }

    ScanlineOverlay {
        anchors.fill: parent
        opacity: 0.10
        lineSpacing: 2
    }

    Column {
        id: layout
        anchors.centerIn: parent
        spacing: 6

        Row {
            id: tabRow
            spacing: 6
            anchors.horizontalCenter: parent.horizontalCenter

            Repeater {
                model: SnipState.tabs

                delegate: Item {
                    id: chip

                    required property var modelData
                    required property int index

                    readonly property bool current: chip.index === SnipState.currentTab
                    readonly property color accent: chip.modelData.accent

                    width: label.implicitWidth + 30
                    height: 28

                    CutShape {
                        anchors.fill: parent
                        fillColor: chip.current
                            ? Qt.rgba(chip.accent.r, chip.accent.g, chip.accent.b, 0.20)
                            : (ma.containsMouse
                                ? Qt.rgba(chip.accent.r, chip.accent.g, chip.accent.b, 0.10)
                                : CP.alpha(CP.void2, 0.55))
                        strokeColor: chip.current
                            ? chip.accent
                            : Qt.rgba(chip.accent.r, chip.accent.g, chip.accent.b, 0.30)
                        strokeWidth: chip.current ? 1.5 : 1
                        inset: 0.5
                        cutTopLeft: 2
                        cutBottomRight: 2

                        Behavior on fillColor { CAnim {} }
                        Behavior on strokeColor { CAnim {} }
                    }

                    // The 1-4 shortcut, as a badge rather than prose.
                    Text {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.leftMargin: 4
                        anchors.topMargin: 2
                        text: chip.index + 1
                        font.family: "Oxanium"
                        font.pixelSize: 7
                        color: chip.current
                            ? chip.accent
                            : Qt.rgba(chip.accent.r, chip.accent.g, chip.accent.b, 0.45)
                    }

                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: chip.modelData.label
                        font.family: "Oxanium"
                        font.pixelSize: 10
                        font.letterSpacing: 1.2
                        color: chip.current
                            ? chip.accent
                            : Qt.rgba(chip.accent.r, chip.accent.g, chip.accent.b, 0.45)

                        Behavior on color { CAnim {} }
                    }

                    // Active tab pulses, per the tightness rule for pending or
                    // armed states.
                    SequentialAnimation on opacity {
                        running: chip.current
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.72; duration: 1100 }
                        NumberAnimation { from: 0.72; to: 1.0; duration: 1100 }
                    }
                    onCurrentChanged: if (!chip.current) chip.opacity = 1.0

                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SnipState.setTab(chip.index)
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "TRASCINA PER SELEZIONARE  ·  TASTO DESTRO = ANNOTA  ·  ESC = ANNULLA"
            font.family: "Oxanium"
            font.pixelSize: 8
            font.letterSpacing: 1.5
            color: Colours.textMuted
        }
    }
}
