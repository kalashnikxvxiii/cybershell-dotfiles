import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../common/Colors.js" as CP
import "../../common"

// Calendario mensile con navigazione mese
// Adattato da Caelestia dash/Calendar.qml

Item {
    id: root

    required property var state

    readonly property int currMonth: state.currentDate.getMonth()
    readonly property int currYear: state.currentDate.getFullYear()

    anchors.left: parent.left
    anchors.right: parent.right
    implicitHeight: inner.implicitHeight + inner.anchors.margins * 2

    // Click rotella: reset a oggi; scroll: naviga mesi
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton
        onClicked: root.state.currentDate = new Date()
        onWheel: wheel => {
            if (wheel.angleDelta.y > 0)
                root.state.currentDate = new Date(root.currYear, root.currMonth - 1, 1)
            else if (wheel.angleDelta.y < 0)
                root.state.currentDate = new Date(root.currYear, root.currMonth + 1, 1)
        }
    }

    ColumnLayout {
        id: inner

        anchors.fill: parent
        anchors.margins: 8
        spacing: 3

        // Riga navigazione: < Mese Anno >
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            // Pulsante mese precedente
            Item {
                implicitWidth: 20
                implicitHeight: 20

                Text {
                    anchors.centerIn: parent
                    text: "<"
                    font.family: "Oxanium"
                    font.pixelSize: 24
                    color: Colours.accentSecondary
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.state.currentDate = new Date(root.currYear, root.currMonth - 1, 1)
                }
            }

            // Titolo mese/anno (clic = torna a oggi)
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: grid.title
                font.family: "Oxanium"
                font.pixelSize: 22
                font.capitalization: Font.Capitalize
                color: Colours.accentPrimary

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.state.currentDate = new Date()
                }
            }

            // Pulsante mese successivo
            Item {
                implicitWidth: 20
                implicitHeight: 20

                Text {
                    anchors.centerIn: parent
                    text: ">"
                    font.family: "Oxanium"
                    font.pixelSize: 24
                    color: Colours.accentSecondary
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.state.currentDate = new Date(root.currYear, root.currMonth + 1, 1)
                }
            }
        }

        // Riga giorni della settimana
        DayOfWeekRow {
            Layout.fillWidth: true
            locale: grid.locale

            delegate: Text {
                required property var model

                horizontalAlignment: Text.AlignHCenter
                text: model.shortName
                font.family: "Oxanium"
                font.pixelSize: 18
                font.weight: Font.Medium
                color: (model.day === 0 || model.day === 6) ? Colours.accentSecondary : Colours.textSecondary
            }
        }

        // Griglia mese
        Item {
            Layout.fillWidth: true
            implicitHeight: grid.implicitHeight

            MonthGrid {
                id: grid

                month: root.currMonth
                year: root.currYear
                anchors.fill: parent
                spacing: 2
                locale: Qt.locale()

                delegate: Item {
                    id: dayItem

                    required property var model

                    implicitWidth: implicitHeight
                    implicitHeight: dayText.implicitHeight + 4

                    // Indicatore oggi
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width
                        height: parent.height
                        radius: 3
                        color: dayItem.model.today ? CP.alpha(CP.cyan, 0.25) : "transparent"
                    }

                    Text {
                        id: dayText

                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: grid.locale.toString(dayItem.model.day)
                        font.family: "Oxanium"
                        font.pixelSize: 18
                        font.weight: dayItem.model.today ? Font.Bold : Font.Normal
                        color: {
                            if (dayItem.model.today)
                                return CP.cyan
                            const dayOfWeek = dayItem.model.date.getUTCDay()
                            if (dayOfWeek === 0 || dayOfWeek === 6)
                                return CP.alpha(CP.cyan, 0.7)
                            return dayItem.model.month === grid.month ? Colours.textPrimary : CP.alpha(Colours.textSecondary, 0.4)
                        }
                    }
                }
            }
        }
    }
}
