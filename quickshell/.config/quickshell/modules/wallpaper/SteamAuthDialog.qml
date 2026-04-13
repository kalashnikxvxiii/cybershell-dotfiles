import QtQuick
import "../../common/Colors.js" as CP
import "../../common"
import "../../common/effects"

Item {
    id: root

    property bool open: false
    property string step: ""       // "password" | "guard" | "working" | "success" | "error"
    property string errorText: ""

    signal loginRequested(string password)
    signal closed()

    visible: open
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 150 } }

    function reset() {
        passwordInput.text = ""
        errorText = ""
        step = "password"
        passwordInput.forceActiveFocus()
    }

    onOpenChanged: {
        if (open) reset()
    }

    onStepChanged: {
        if (step === "error") passwordInput.forceActiveFocus()
    }

    Keys.onEscapePressed: event => {
        root.open = false
        root.closed()
        event.accepted = true
    }

    CutShape {
        anchors.fill: parent
        fillColor: CP.moduleBg
        strokeColor: CP.alpha(CP.cyan, 0.6)
        strokeWidth: 2
        inset: 10
        cutTopLeft: 16
        cutBottomRight: 16
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - 40
        spacing: 12

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "STEAM LOGIN"
            font.family: "Oxanium"
            font.pixelSize: 13
            font.letterSpacing: 3
            color: Colours.accentSecondary
        }

        // Error message
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.errorText
            font.family: "Oxanium"
            font.pixelSize: 10
            font.letterSpacing: 1
            color: Colours.accentDanger
            visible: root.step === "error"
        }

        // Password field
        Item {
            width: parent.width
            height: 32
            visible: root.step === "password" || root.step === "error"

            CutShape {
                anchors.fill: parent
                fillColor: CP.alpha(CP.cyan, 0.05)
                strokeColor: CP.alpha(CP.cyan, 0.3)
                strokeWidth: 1
                inset: 0.5
                cutTopLeft: 4
                cutBottomRight: 4
            }

            TextInput {
                id: passwordInput
                anchors.fill: parent
                anchors.margins: 8
                verticalAlignment: TextInput.AlignVCenter
                font.family: "Oxanium"
                font.pixelSize: 12
                color: Colours.textPrimary
                echoMode: TextInput.Password
                clip: true

                Keys.onReturnPressed: {
                    root.loginRequested(passwordInput.text)
                }
                Keys.onEscapePressed: {
                    root.open = false
                    root.closed()
                }
            }

            Text {
                anchors.centerIn: parent
                text: "PASSWORD"
                font.family: "Oxanium"
                font.pixelSize: 10
                font.letterSpacing: 2
                color: CP.alpha(Colours.textMuted, 0.3)
                visible: passwordInput.text === ""
            }
        }

        // Waiting for phone confirmation
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "CONFIRM ON STEAM APP"
            font.family: "Oxanium"
            font.pixelSize: 11
            font.letterSpacing: 2
            color: Colours.accentPrimary
            visible: root.step === "confirming"
            PulseAnim on opacity { running: root.step === "confirming"; minOpacity: 0.3; duration: 600 }
        }

        // Working indicator
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "AUTHENTICATING..."
            font.family: "Oxanium"
            font.pixelSize: 10
            font.letterSpacing: 2
            color: Colours.accentSecondary
            visible: root.step === "working"
            PulseAnim on opacity { running: root.step === "working"; minOpacity: 0.3; duration: 400 }
        }

        // Success message
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "AUTHENTICATED"
            font.family: "Oxanium"
            font.pixelSize: 10
            font.letterSpacing: 2
            color: Colours.accentOk
            visible: root.step === "success"
        }
    }
}
