// Widget utente: avatar + username + OS + WM + uptime
//
// Struttura:
//   Process per la lettura di username, home dir e ~/.face
//   Timer per l'aggiornamento dell'uptime ogni minuto
//   UserInfoRow per la riga di informazioni sistema

import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "../../common/Colors.js" as CP
import "../../common"

Item {
    id: root

    property string username: ""
    property string homeDir: ""
    property string osName: ""
    property string uptimeStr: ""
    property string facePath: ""   // valorizzato solo se ~/.face esiste
    property bool   _glitchingUser: false  // aberrazione cromatica attiva durante burst glitch

    readonly property int avatarSize: Math.min(width * 0.7, height * 0.7)
    readonly property real fontSize: Math.min(width * 0.1, height * 0.1)
    readonly property real frameCut: avatarSize * 0.3
    readonly property real maskInset: 4

    // Leggi username, home dir e verifica esistenza ~/.face (output: "USER|HOME|facepath")
    Process {
        command: ["bash", "-c",
            "echo \"$USER|$HOME|$([ -f $HOME/.face ] && echo $HOME/.face)\""
        ]
        running: true
        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split("|")
                root.username = parts[0] || ""
                root.homeDir  = parts[1] || ""
                const face    = parts[2] || ""
                root.facePath = face ? ("file://" + face) : ""
            }
        }
    }

    // OS name da /etc/os-release
    Process {
        command: ["bash", "-c", "grep '^PRETTY_NAME' /etc/os-release | cut -d= -f2 | tr -d '\"'"]
        running: true
        stdout: SplitParser { onRead: data => { root.osName = data.trim() } }
    }

    // Uptime aggiornato ogni minuto
    Timer { interval: 60000; running: true; repeat: true; triggeredOnStart: true; onTriggered: uptimeProc.running = true }
    Process {
        id: uptimeProc
        command: ["bash", "-c", "uptime -p | sed 's/up //'"]
        running: false
        stdout: SplitParser { onRead: data => { root.uptimeStr = data.trim() } }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 10

        // Avatar frame
        Item {
            Layout.preferredWidth: root.avatarSize
            Layout.preferredHeight: root.avatarSize
            Layout.alignment: Qt.AlignVCenter

            Item {
                id: iconFrame
                anchors.fill: parent
                
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: shapeMask
                }

                // Sfondo
                Rectangle {
                    anchors.fill: parent
                    color: Colours.moduleBg
                }

                // Fallback quando immagine non disponibile
                Text {
                    anchors.centerIn: parent
                    text: root.username ? root.username[0].toUpperCase() : "?"
                    font.family: "Oxanium"
                    font.pixelSize: root.avatarSize * 0.4
                    font.weight: Font.Bold
                    color: CP.cyan
                    visible: face.status !== Image.Ready
                }

                Image {
                    id: face
                    anchors.fill: parent
                    source: root.facePath
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    mipmap: true
                }
                
                CutShape {
                    id: shapeMask
                    layer.enabled: true
                    visible: false
                    anchors.fill: parent
                    inset: root.maskInset
                    fillColor: "white"
                    cutTopLeft: 8
                }
            }
            
            AnimatedImage {
                anchors.fill: parent
                source: Qt.resolvedUrl("../../assets/cyberpunk-frame.gif").toString().replace("file://", "")
                playing: true
                fillMode: Image.PreserveAspectFit
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: CP.black
                    shadowOpacity: 0.8
                    shadowBlur: 0.3
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                }
                mipmap: true
            }
        }

        // Informazioni sistema
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: 5
            spacing: 6

            // Username con aberrazione cromatica permanente
            Item {
                Layout.fillWidth: true
                implicitHeight: usernameLabel.implicitHeight

                // Canale rosso (+3px dx) — sempre visibile a bassa opacità
                Text {
                    width: parent.width
                    x: 3; y: 0
                    text:  root.username || "user"
                    font:  usernameLabel.font
                    color: CP.aberrationRed(root._glitchingUser ? 0.65 : 0.28)
                    elide: Text.ElideRight
                    z: 0
                    Behavior on color { ColorAnimation { duration: 30 } }
                }
                // Canale cyan (−3px sx) — sempre visibile a bassa opacità
                Text {
                    width: parent.width
                    x: -3; y: 0
                    text:  root.username || "user"
                    font:  usernameLabel.font
                    color: CP.aberrationCyan(root._glitchingUser ? 0.65 : 0.28)
                    elide: Text.ElideRight
                    z: 0
                    Behavior on color { ColorAnimation { duration: 30 } }
                }
                // Glow ombra diagonale (faint)
                Text {
                    width: parent.width
                    x: 1; y: 1
                    text:  root.username || "user"
                    font:  usernameLabel.font
                    color: CP.aberrationCyan(0.30)
                    elide: Text.ElideRight
                    z: 0
                }
                // Testo principale
                Text {
                    id: usernameLabel
                    anchors { left: parent.left; right: parent.right }
                    text: root.username || "user"
                    font.family: "Oxanium"
                    font.pixelSize: root.fontSize * 1.8
                    font.weight: Font.Bold
                    color: CP.yellow
                    elide: Text.ElideRight
                    transform: Translate { id: labelShift; x: 0 }
                    z: 2
                }
            }

            // OS
            UserInfoRow {
                Layout.fillWidth: true
                prefix: "OS"
                value: root.osName || "Linux"
                accent: Colours.accentPrimary
            }

            // WM
            UserInfoRow {
                Layout.fillWidth: true
                prefix: "WM"
                value: "Hyprland"
                accent: Colours.accentSecondary
            }

            // Uptime
            UserInfoRow {
                Layout.fillWidth: true
                prefix: "UP"
                value: root.uptimeStr || "..."
                accent: CP.magenta
            }
        }
    }

    // Riga info: prefisso colorato + valore
    component UserInfoRow: RowLayout {
        id: infoRow

        required property string prefix
        required property string value
        required property color accent

        spacing: 4

        Text {
            text: infoRow.prefix
            font.family: "Oxanium"
            font.pixelSize: root.fontSize
            font.weight: Font.Bold
            color: infoRow.accent
        }

        Text {
            Layout.fillWidth: true
            text: infoRow.value
            font.family: "Oxanium"
            font.pixelSize: root.fontSize
            color: Colours.textSecondary
            elide: Text.ElideRight
        }
    }

    // ── Glitch continuo stepped con aberrazione cromatica ────────────────
    SequentialAnimation {
        running: true; loops: Animation.Infinite

        PropertyAction  { target: root;          property: "_glitchingUser"; value: false }
        PropertyAction  { target: usernameLabel; property: "color";          value: CP.yellow }
        PropertyAction  { target: labelShift;    property: "x";              value: 0 }
        PauseAnimation  { duration: 1400 }

        // Burst 1: aberrazione ON
        PropertyAction  { target: root;          property: "_glitchingUser"; value: true }
        PropertyAction  { target: usernameLabel; property: "color";          value: CP.magenta }
        PropertyAction  { target: labelShift;    property: "x";              value: 3 }
        PauseAnimation  { duration: 60 }

        PropertyAction  { target: usernameLabel; property: "color";          value: CP.yellow }
        PropertyAction  { target: labelShift;    property: "x";              value: -3 }
        PauseAnimation  { duration: 60 }

        PropertyAction  { target: usernameLabel; property: "color";          value: CP.cyan }
        PropertyAction  { target: labelShift;    property: "x";              value: 2 }
        PauseAnimation  { duration: 60 }

        // Fine burst 1: aberrazione OFF
        PropertyAction  { target: root;          property: "_glitchingUser"; value: false }
        PropertyAction  { target: usernameLabel; property: "color";          value: CP.yellow }
        PropertyAction  { target: labelShift;    property: "x";              value: 0 }
        PauseAnimation  { duration: 100 }

        // Burst 2: micro
        PropertyAction  { target: root;          property: "_glitchingUser"; value: true }
        PropertyAction  { target: usernameLabel; property: "color";          value: CP.magenta }
        PropertyAction  { target: labelShift;    property: "x";              value: -1 }
        PauseAnimation  { duration: 40 }

        PropertyAction  { target: root;          property: "_glitchingUser"; value: false }
        PropertyAction  { target: usernameLabel; property: "color";          value: CP.yellow }
        PropertyAction  { target: labelShift; property: "x";     value: 0 }
        PauseAnimation  { duration: 230 }
    }

    // ── Opacity flicker (clock-pulse: glow che respira) ───────────────────
    SequentialAnimation {
        running: true; loops: Animation.Infinite
        PropertyAction  { target: root; property: "opacity"; value: 1.0 }
        PauseAnimation  { duration: 2400 }
        PropertyAction  { target: root; property: "opacity"; value: 0.85 }
        PauseAnimation  { duration: 50 }
        PropertyAction  { target: root; property: "opacity"; value: 1.0 }
        PauseAnimation  { duration: 50 }
        PropertyAction  { target: root; property: "opacity"; value: 0.92 }
        PauseAnimation  { duration: 50 }
        PropertyAction  { target: root; property: "opacity"; value: 1.0 }
        PauseAnimation  { duration: 500 }
    }
}
