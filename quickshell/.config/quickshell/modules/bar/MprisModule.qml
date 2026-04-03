// MprisModule.qml — now playing via Quickshell.Services.Mpris
//   Text per il testo Artista/Titolo con animazione marquee
//   Rectangle per la barra di avanzamento con animazione glitch
//   MouseArea per la gestione del click e del scroll

import Quickshell.Services.Mpris
import QtQuick
import "../../common/Colors.js" as CP
import "../../common"

Item {
    id: root
    implicitHeight: 24
    
    property int minWidth: 140
    property int maxWidth: 260
    property int textInset: 10

    implicitWidth: Math.max(minWidth, Math.min(maxWidth, label1.implicitWidth + 2 * root.textInset))

    property bool showBackground: true
    property var player: {
        var players = Mpris.players.values
        for (var i = 0; i < players.length; i++) {
            if (players[i].isPlaying) return players[i]
        }
        return players.length > 0 ? players[0] : null
    }

    property real progress: 0

    property string playerIcon: {
        if (!player) return ""
        var name = (player.identity || "").toLowerCase()
        if (name.includes("spotify"))  return ""
        if (name.includes("youtube"))  return ""
        if (name.includes("zen"))  return ""
        if (name.includes("vlc"))      return "嗢"
        return ""
    }

    property string displayText: {
        if (!player) return "No Signal"
        var title  = player.trackTitle  || ""
        var artist = player.trackArtist || ""
        var sep    = (title && artist) ? " — " : ""
        var full   = playerIcon + " " + title + sep + artist
        return full
    }

    visible: player !== null

    onDisplayTextChanged: {
        textViewport.marqueeOffset = 0
    }

    Timer {
        id: progressTimer
        interval: 100
        repeat: true
        running: player
                && player.positionSupported
                && player.playbackState == MprisPlaybackState.Playing
        
        onTriggered: {
            //console.log("progress tick", root.width, root.progress, progressBarBg.width)
            if (!root.player) {
                root.progress = 0
                progressBarFill.width = 0
                return
            }

            if (root.player.playbackState !== MprisPlaybackState.Playing) {
                root.progress = 0
                progressBarFill.width = 0
                return
            }

            if (!player.lengthSupported || player.length <= 0) {
                root.progress = 0
                progressBarFill.width = 0
                return
            }

            root.player.positionChanged()

            var ratio = player.position / player.length
            ratio = Math.max(0, Math.min(1, ratio))
            root.progress = ratio
            progressBarFill.width = progressBarBg.width * ratio
        }
    }

    Item {
        id: textViewport
        anchors {
            left: parent.left
            right: parent.right
            leftMargin: root.textInset
            rightMargin: root.textInset
            verticalCenter: parent.verticalCenter
            verticalCenterOffset: 0.5
        }
        height: label1.implicitHeight
        clip: true

        property real marqueeOffset: 0
        property real marqueeGap: 40
        property bool marqueeActive: player && root.displayText.length > 0
                                && label1.implicitWidth > width

        onMarqueeActiveChanged: {
            if (!marqueeActive) {
                marqueeOffset = 0
            }
        }

        // Testo Artista/Titolo
        Text {
            id: label1
            x: textViewport.marqueeActive ? textViewport.marqueeOffset : (textViewport.width - label1.implicitWidth) / 2
            anchors.verticalCenter: parent.verticalCenter
            text: root.displayText
            font.family: "Oxanium"
            font.pixelSize: 12
            font.italic: true
            font.letterSpacing: 2
            color: CP.cyan
            style: Text.Raised
            styleColor: Colours.neonBorder(0.3)
            transform: Translate { id: labelShift; x: 0 }
        }

        Text {
            id: label2
            visible: textViewport.marqueeActive
            x: textViewport.marqueeOffset + label1.implicitWidth + textViewport.marqueeGap
            anchors.verticalCenter: parent.verticalCenter
            text: label1.text
            font: label1.font
            color: label1.color
            style: label1.style
            styleColor: label1.styleColor
        }

        // Animazione del marquee: pausa, scroll, pausa...
        SequentialAnimation {
            id: marqueeAnim
            running: textViewport.marqueeActive
            loops: Animation.Infinite

            // reset: testo fuori a destra
            PropertyAction {
                target: textViewport
                property: "marqueeOffset"
                value: 0
            }
            PauseAnimation { duration: 1500 }

            // scorrimento a sinistra
            NumberAnimation {
                target: textViewport
                property: "marqueeOffset"
                from: 0
                to: -(label1.implicitWidth + textViewport.marqueeGap)
                duration: 8000
                easing.type: Easing.Linear
            }
            PauseAnimation { duration: 1000 }
        }
    }

    Rectangle {
        id: progressBarBg
        anchors {
            left: parent.left
            right: parent.right
            top: textViewport.bottom
            leftMargin: 1
            rightMargin: 1
            topMargin: 1
            bottomMargin: 1
        }
        height: 1
        radius: 1
        color: Qt.rgba(1, 1, 1, 0)
        visible: player && player.lengthSupported

        Rectangle {
            id: progressBarFill
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            radius: parent.radius
            color: CP.alpha(CP.yellow, 1)
        }
    }

    GlitchAnim { id: glitch; labelTarget: label1; shiftTarget: labelShift }
    HoverHandler { onHoveredChanged: if (hovered) glitch.restart() }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked:  if (root.player) root.player.togglePlaying()
        onWheel: wheel => {
            if (!root.player) return
            if (wheel.angleDelta.y > 0) root.player.next()
            else                        root.player.previous()
        }
    }
}
