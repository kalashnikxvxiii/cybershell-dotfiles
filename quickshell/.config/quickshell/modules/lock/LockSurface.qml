// LockSurface.qml -- one screen of the lock: the still of the desktop, blurred and darkened,
// framed as a NETWATCH security camera, with the authentication panel in the middle and the
// newsfeed along the bottom. Every screen shows the panel; what's typed is shared (LockState).
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../../common/Colors.js" as CP
import "../../common"
import "../../common/effects"

Item {
    id: root

    required property var screen

    property double now: Date.now()
    readonly property string user: (Quickshell.env("USER") || "").toUpperCase()
    property string host: ""

    function two(n) { return (n < 10 ? "0" : "") + n }
    readonly property string elapsed: {
        const s = Math.max(0, Math.floor((root.now - LockState.since) / 1000))
        return root.two(Math.floor(s / 3600)) + ":" + root.two(Math.floor(s / 60) % 60) + ":" + root.two(s % 60)
    }

    Timer {
        interval: 1000
        repeat: true
        running: LockState.locked
        onTriggered: root.now = Date.now()
    }

    FileView {
        path: "/etc/hostname"
        onLoaded: root.host = text().trim().toUpperCase()
    }

    // -- Background: the desktop as it was, out of focus ------------------
    Image {
        id: still
        anchors.fill: parent
        source: "file://" + LockState.shotDir + "/" + root.screen.name + ".png"
        fillMode: Image.PreserveAspectCrop
        cache: false
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: still
        visible: still.status === Image.Ready
        blurEnabled: true
        blur: 0.7
        blurMax: 48
        brightness: -0.45
        saturation: -0.3
    }
    Rectangle {
        anchors.fill: parent
        color: CP.alpha(Theme.void2, 0.35)
    }
    ScanlineOverlay {
        opacity: 0.12
    }

    // -- Camera frame --------------------------------------
    CornerAccents {
        anchors.fill: parent
        anchors.margins: 18
        accentColor: CP.alpha(Theme.red, 0.8)
        size: 26
        thickness: 2
    }

    // Top left: recording
    Column {
        x: 40
        y: 34
        spacing: 6

        Row {
            spacing: 10
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 10
                height: 10
                color: Theme.red
                opacity: rec.k
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "REC"
                color: Theme.red
                font { family: Theme.font; pixelSize: 14; bold: true; letterSpacing: 2 }
            }
            Rectangle {
                width: timer.implicitWidth + 16
                height: 22
                color: Theme.red
                Text {
                    id: timer
                    anchors.centerIn: parent
                    text: root.elapsed
                    color: "#000000"
                    font { family: Theme.font; pixelSize: 13; bold: true; letterSpacing: 1 }
                }
            }
        }
        Repeater {
            model: ["HD", "F 5.6", "ISO 100"]
            Text {
                required property string modelData
                text: modelData
                color: CP.alpha(Theme.red, 0.75)
                font { family: Theme.font; pixelSize: 11; bold: true; letterSpacing: 1 }
            }
        }
    }
    Pulse {
        id: rec
        running: LockState.locked
        from: 1
        to: 0.15
        halfMs: 700
    }

    // Top right: the camera and the clock
    Column {
        anchors.right: parent.right
        anchors.rightMargin: 40
        y: 34
        spacing: 4

        Text {
            anchors.right: parent.right
            text: "  CAMERA 01: " + root.host
            color: Theme.red
            font { family: Theme.font; pixelSize: 16; bold: true; letterSpacing: 2 }
        }
        Text {
            anchors.right: parent.right
            text: Qt.formatDateTime(new Date(root.now), "HH:mm  ·  yyyy.MM.dd  ddd").toUpperCase()
            color: CP.alpha(Theme.cyan, 0.8)
            font { family: Theme.font; pixelSize: 12; letterSpacing: 2 }
        }
    }

    // -- Authentication panel --------------------------
    Item {
        id: panel
        anchors.centerIn: parent
        width: 400
        height: content.implicitHeight + 40

        // Bracket across the top
        Rectangle {
            width: parent.width
            height: 2
            color: Theme.red
        }
        Rectangle { width: 2; height: 12; color: Theme.red }
        Rectangle { x: parent.width - 2; width: 2; height: 12; color: Theme.red }
        Rectangle {
            y: 2
            width: parent.width
            height: parent.height - 2
            color: CP.alpha(Theme.void2, 0.55)
        }

        Column {
            id: content
            x: 28
            y: 28
            width: parent.width - 56
            spacing: 16

            Item {
                width: parent.width
                height: 18
                Text {
                    text: "//:: AUTHENTICATION_SEQUENCE"
                    color: Theme.yellow
                    font { family: Theme.font; pixelSize: 12; letterSpacing: 1 }
                }
                Text {
                    anchors.right: parent.right
                    text: ""
                    color: Theme.red
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
                }
            }

            Item {
                width: parent.width
                height: 18
                Text {
                    text: "USER"
                    color: Theme.yellow
                    font { family: Theme.font; pixelSize: 12; letterSpacing: 1 }
                }
                Text {
                    anchors.right: parent.right
                    text: root.user + (root.host !== "" ? "@" + root.host : "")
                    color: CP.alpha(Theme.cyan, 0.9)
                    font { family: Theme.font; pixelSize: 12; letterSpacing: 1 }
                }
            }

            // Password
            Item {
                width: parent.width
                height: 44

                CutShape {
                    anchors.fill: parent
                    cutBottomRight: 10
                    fillColor: CP.alpha(Theme.red, input.activeFocus ? 0.12 : 0.06)
                    strokeColor: LockState.status === "denied" || LockState.status === "lockout" ? Theme.red : CP.alpha(Theme.red, 0.7)
                    strokeWidth: input.activeFocus ? 2 : 1
                    inset: strokeWidth / 2
                }
                Text {
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: ">"
                    color: Theme.red
                    font { family: Theme.font; pixelSize: 14; bold: true }
                }
                Text {
                    x: 34
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === ""
                    text: "PASSWORD"
                    color: CP.alpha(Theme.red, 0.45)
                    font { family: Theme.font; pixelSize: 13; letterSpacing: 2 }
                }
                TextInput {
                    id: input
                    x: 34
                    width: parent.width - 48
                    anchors.verticalCenter: parent.verticalCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "◆"
                    readOnly: LockState.busy
                    clip: true
                    focus: true
                    color: CP.white
                    font { family: Theme.font; pixelSize: 15; letterSpacing: 3 }
                    // Shared between the screens: the keyboard may sit on any of them
                    onTextChanged: if (LockState.buffer !== text) LockState.buffer = text
                    Connections {
                        target: LockState
                        function onBufferChanged() { if (input.text !== LockState.buffer) input.text = LockState.buffer }
                    }
                    Keys.onReturnPressed: LockState.submit()
                    Keys.onEnterPressed: LockState.submit()
                    Keys.onEscapePressed: LockState.buffer = ""
                    Component.onCompleted: forceActiveFocus()
                }
            }

            // Log in
            Item {
                width: parent.width
                height: 40
                opacity: LockState.buffer !== "" && !LockState.busy ? 1 : 0.45

                CutShape {
                    anchors.fill: parent
                    cutTopLeft: 10
                    cutBottomRight: 10
                    fillColor: loginHit.containsMouse ? CP.alpha(Theme.red, 0.18) : "transparent"
                    strokeColor: Theme.red
                    inset: 0.5
                }
                Text {
                    anchors.centerIn: parent
                    text: LockState.busy ? "VERIFYING…" : "LOG IN"
                    color: Theme.red
                    font { family: Theme.font; pixelSize: 13; bold: true; letterSpacing: 3 }
                }
                MouseArea {
                    id: loginHit
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: LockState.submit()
                }
            }

            Text {
                width: parent.width
                height: 16
                horizontalAlignment: Text.AlignHCenter
                text: LockState.status === "denied" ? "ACCESS DENIED  ·  ATTEMPT " + LockState.failures
                    : LockState.status === "lockout" ? "TOO MANY ATTEMPTS: ACCOUNT LOCKED FOR A WHILE"
                    : LockState.status === "error" ? "AUTHENTICATION ERROR"
                    : ""
                color: Theme.red
                font { family: Theme.font; pixelSize: 11; bold: true; letterSpacing: 2 }
            }
        }
    }

    // -- Bottom: newsfeed and signature -------------------------
    NewsTicker {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 60
        accent: Theme.red
        textColor: CP.alpha(Theme.red, 0.85)
        fontLabels: Theme.font
        fontData: "JetBrainsMono Nerd Font"
    }
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 56
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 30
        spacing: 8
        Text {
            anchors.baseline: brand.baseline
            text: "POWERED BY"
            color: CP.alpha(Theme.red, 0.6)
            font { family: Theme.font; pixelSize: 9; letterSpacing: 2 }
        }
        Text {
            id: brand
            text: "NETWATCH"
            color: Theme.red
            font { family: Theme.font; pixelSize: 14; bold: true; letterSpacing: 3 }
        }
    }
}
