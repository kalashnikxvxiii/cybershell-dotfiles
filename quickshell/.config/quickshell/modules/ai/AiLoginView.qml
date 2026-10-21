// AiLoginView.qml - the sign-in screen, over the chat while the CLI holds no login.
//
// The extension's three steps: pick how to log in, continue in the browser
// (the URL to copy, and a field for the code when the browser cannot call
// back), done. The session does the work and this only shows where it is
import QtQuick
import Quickshell
import "../../common"
import "../../common/Colors.js" as CP

Item {
    id: root

    readonly property var session: AiState.session
    readonly property string stage: root.session?.loginStage ?? ""
    readonly property color fg: "#d8e0e8"

    // Takes the clicks: the chat under it cannot be used
    Rectangle { anchors.fill: parent; color: CP.void2 }
    MouseArea { anchors.fill: parent }

    // A full-width action: the primary one is filled
    component LoginButton: Item {
        id: btn

        property string label: ""
        property string note: ""
        property color accent: CP.cyan
        property bool primary: false

        signal triggered()

        width: parent.width
        height: 32 + (btn.note !== "" ? noteText.implicitHeight + 4 : 0)
        opacity: btn.enabled ? 1 : 0.35

        CutShape {
            width: parent.width
            height: 32
            fillColor: CP.alpha(btn.accent, btn.primary
                ? (ma.containsMouse ? 0.30 : 0.18) : (ma.containsMouse ? 0.12 : 0.04))
            strokeColor: CP.alpha(btn.accent, ma.containsMouse ? 0.80 : 0.40)
            strokeWidth: 1
            inset: 0.5
            cutTopLeft: 6
            cutBottomRight: 6
        }

        Text {
            width: parent.width
            height: 32
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: btn.label
            font.family: "Oxanium"
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 2
            color: btn.primary ? btn.accent : root.fg
        }

        Text {
            id: noteText
            y: 36
            width: parent.width
            visible: btn.note !== ""
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: btn.note
            font.family: "Oxanium"
            font.pixelSize: 9
            color: CP.alpha(root.fg, 0.45)
        }

        MouseArea {
            id: ma
            width: parent.width
            height: 32
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.triggered()
        }
    }

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 330)
        spacing: 14

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: clawd.width + 48
            height: clawd.height + 3

            AiClawd {
                id: clawd
                anchors.horizontalCenter: parent.horizontalCenter
                hole: CP.void2
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: CP.alpha(CP.magenta, 0.30)
            }
        }

        // -- 1. How to log in ----------------------------------------------
        Column {
            width: parent.width
            spacing: 14
            visible: root.stage === ""

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: "Claude can be used with your Claude subscription or billed "
                    + "based on API usage through your Console account."
                font.family: "Oxanium"
                font.pixelSize: 11
                color: CP.alpha(root.fg, 0.70)
            }

            Text {
                width: parent.width
                visible: text !== ""
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: root.session?.loginError ?? ""
                font.family: "Oxanium"
                font.pixelSize: 10
                color: CP.red
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "HOW DO YOU WANT TO LOG IN?"
                font.family: "Oxanium"
                font.pixelSize: 9
                font.letterSpacing: 2
                font.bold: true
                color: CP.magenta
            }

            LoginButton {
                label: "CLAUDE.AI SUBSCRIPTION"
                note: "Use your Claude Pro, Team, or Enterprise subscription"
                accent: CP.yellow
                primary: true
                onTriggered: root.session.login(true)
            }

            LoginButton {
                label: "ANTHROPIC CONSOLE"
                note: "Pay for API usage through your Console account"
                onTriggered: root.session.login(false)
            }

            LoginButton {
                label: "BEDROCK, FOUNDRY, OR VERTEX  \u2197"
                note: "Instructions on how to use API keys or third-party providers."
                accent: CP.magenta
                onTriggered: Quickshell.execDetached(["xdg-open",
                    "https://code.claude.com/docs/en/vs-code#use-third-party-providers"])
            }
        }

        // -- 2. Waiting for the URLs ----------------------------------------
        Column {
            width: parent.width
            spacing: 14
            visible: root.stage === "starting"

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "SIGNING IN\u2026"
                font.family: "Oxanium"
                font.pixelSize: 12
                font.letterSpacing: 3
                font.bold: true
                color: CP.cyan
            }

            LoginButton {
                label: "CANCEL"
                onTriggered: root.session.cancelLogin()
            }
        }

        // -- 3. Continue in the browser -------------------------------------
        Column {
            width: parent.width
            spacing: 10
            visible: root.stage === "browser"

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "CONTINUE IN BROWSER"
                font.family: "Oxanium"
                font.pixelSize: 12
                font.letterSpacing: 3
                font.bold: true
                color: CP.cyan
            }

            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: "If the browser didn't open, visit this URL:"
                font.family: "Oxanium"
                font.pixelSize: 10
                color: CP.alpha(root.fg, 0.60)
            }

            // The URL, selectable, and a button for the clipboard
            Item {
                width: parent.width
                height: 28

                CutShape {
                    anchors.fill: parent
                    fillColor: CP.alpha(CP.cyan, 0.04)
                    strokeColor: CP.alpha(CP.cyan, 0.30)
                    strokeWidth: 1
                    inset: 0.5
                    cutBottomRight: 6
                }

                TextInput {
                    anchors.left: parent.left
                    anchors.right: copy.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 8
                    anchors.rightMargin: 6
                    readOnly: true
                    selectByMouse: true
                    clip: true
                    text: root.session?.loginUrl ?? ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 9
                    color: CP.alpha(root.fg, 0.75)
                    selectionColor: CP.alpha(CP.cyan, 0.35)
                    // Show the start of it, not where the text ended
                    onTextChanged: cursorPosition = 0
                }

                AiIconButton {
                    id: copy
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 4
                    frame: false
                    glyph: "\uf0c5"
                    glyphSize: 11
                    accent: CP.cyan
                    onTriggered: Quickshell.execDetached(["wl-copy", "-n", "--",
                        root.session?.loginUrl ?? ""])
                }
            }

            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: "Or, paste your authorization code manually:"
                font.family: "Oxanium"
                font.pixelSize: 10
                color: CP.alpha(root.fg, 0.60)
            }

            Text {
                width: parent.width
                visible: text !== ""
                wrapMode: Text.Wrap
                text: root.session?.loginError ?? ""
                font.family: "Oxanium"
                font.pixelSize: 10
                color: CP.red
            }

            Item {
                width: parent.width
                height: 28

                CutShape {
                    anchors.fill: parent
                    fillColor: CP.alpha(CP.cyan, 0.04)
                    strokeColor: CP.alpha(CP.cyan, code.activeFocus ? 0.80 : 0.30)
                    strokeWidth: 1
                    inset: 0.5
                    cutBottomRight: 6
                }

                TextInput {
                    id: code
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    clip: true
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    color: root.fg
                    selectionColor: CP.alpha(CP.cyan, 0.35)
                    onAccepted: root.session.submitLoginCode(code.text)

                    Text {
                        visible: code.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "012345"
                        font: code.font
                        color: CP.alpha(root.fg, 0.25)
                    }
                }
            }

            LoginButton {
                label: "CONTINUE"
                accent: CP.yellow
                primary: true
                enabled: code.text.trim() !== ""
                onTriggered: root.session.submitLoginCode(code.text)
            }

            LoginButton {
                label: "BACK"
                onTriggered: root.session.cancelLogin()
            }
        }
    }
}
