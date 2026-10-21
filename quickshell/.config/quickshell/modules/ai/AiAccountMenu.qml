// AiAccountMenu.qml - the profile drop-down of the header: who is logged in,
// and how much of the plan limits is already gone.
//
// Everything comes from the CLI: the account from its `initialize` answer,
// the limits from `get_usage`, asked again at every opening. VIEW DETAILS
// opens the full panel
import QtQuick
import "../../common"
import "../../common/Colors.js" as CP

Item {
    id: root

    signal detailsRequested()
    signal logoutRequested()

    readonly property color fg: "#d8e0e8"
    readonly property var session: AiState.session

    implicitWidth: 250
    implicitHeight: body.implicitHeight + 24
    width: implicitWidth
    height: implicitHeight

    CutShape {
        anchors.fill: parent
        fillColor: CP.alpha(CP.void2, 0.97)
        strokeColor: CP.alpha(CP.magenta, 0.45)
        strokeWidth: 1
        inset: 0.5
        cutBottomLeft: 14
    }

    // Takes the clicks: the transcript under the menu must not get them
    MouseArea { anchors.fill: parent }

    Column {
        id: body
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.margins: 12
        spacing: 9

        Item {
            width: parent.width
            height: 14

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "\u25e2 ACCOUNT & USAGE"
                font.family: "Oxanium"
                font.pixelSize: 10
                font.letterSpacing: 2
                font.bold: true
                color: CP.magenta
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "VIEW DETAILS"
                font.family: "Oxanium"
                font.pixelSize: 9
                font.letterSpacing: 1
                font.underline: details.containsMouse
                color: details.containsMouse ? CP.cyan : CP.alpha(CP.cyan, 0.60)
                Behavior on color { ColorAnimation { duration: 100 } }

                MouseArea {
                    id: details
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.detailsRequested()
                }
            }
        }

        Text {
            text: "ACCOUNT"
            font.family: "Oxanium"
            font.pixelSize: 8
            font.letterSpacing: 2
            font.bold: true
            color: CP.alpha(root.fg, 0.38)
        }

        Item {
            width: parent.width
            height: email.implicitHeight

            Text {
                id: emailLabel
                anchors.left: parent.left
                text: "Email"
                font.family: "Oxanium"
                font.pixelSize: 11
                color: CP.alpha(root.fg, 0.45)
            }

            Text {
                id: email
                anchors.left: emailLabel.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                horizontalAlignment: Text.AlignRight
                text: root.session?.account?.email ?? "\u2014"
                elide: Text.ElideLeft
                font.family: "Oxanium"
                font.pixelSize: 11
                color: root.fg
            }
        }

        Text {
            text: "USAGE"
            font.family: "Oxanium"
            font.pixelSize: 8
            font.letterSpacing: 2
            font.bold: true
            color: CP.alpha(root.fg, 0.38)
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: root.session?.usageNote ?? ""
            wrapMode: Text.Wrap
            font.family: "Oxanium"
            font.pixelSize: 10
            color: CP.alpha(root.fg, 0.45)
        }

        Repeater {
            model: root.session?.usageWindows ?? []

            AiUsageBar {
                required property var modelData
                width: body.width
                label: modelData.label
                utilization: modelData.utilization
                resetsAt: modelData.resetsAt
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: CP.alpha(CP.magenta, 0.22)
        }

        Text {
            text: "LOG OUT"
            font.family: "Oxanium"
            font.pixelSize: 9
            font.letterSpacing: 1
            font.underline: out.containsMouse
            color: out.containsMouse ? CP.red : CP.alpha(CP.red, 0.65)
            Behavior on color { ColorAnimation { duration: 100 } }

            MouseArea {
                id: out
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.logoutRequested()
            }
        }
    }
}