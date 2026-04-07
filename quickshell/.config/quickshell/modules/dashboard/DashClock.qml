import Quickshell
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import QtQuick.Layouts
import "../../common/Colors.js" as CP
import "../../common"

// Vertical clock: hours / separator / minutes
// Adapted from Caelestia dash/DateTime.qml

Item {
    id: root
    clip: true

    implicitWidth: 120

    readonly property real fontSize: Math.min(width * 0.50, height * 0.85)

    SystemClock { id: clock; precision: SystemClock.Minutes }

    property int _prevHours: clock.hours
    property int _prevMinutes: clock.minutes
    
    readonly property string gifSource: {
        const h = clock.hours
        if (h < 5) return "../../assets/clock-backgrounds/edgerunners-over-midnight-time.gif"
        if (h < 7 || h > 18 && h < 20) return "../../assets/clock-backgrounds/cyberpunk-night-city-sunrise-dawn.gif"
        if (h < 18) return "../../assets/clock-backgrounds/edgerunners-morning-time.gif"
        return "../../assets/clock-backgrounds/cyberpunk-night-city-night-time.gif"
    }

    onGifSourceChanged: gifFade.restart()

    layer.enabled: true
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: maskShape
    }

    CutShape {
        anchors.fill: parent
        fillColor: "transparent"
        cutBottomLeft: 24
    }

    component GlitchDigit: Item {
        id: gd

        required property string txt
        required property real sz

        implicitWidth: lbl.implicitWidth
        implicitHeight: lbl.implicitHeight

        function glitch() { anim.restart() }

        Text {
            text: gd.txt
            font.family: "Oxanium"
            font.pixelSize: gd.sz
            font.weight: Font.Bold
            color: Colours.accentDanger
            opacity: 0.55
            x: -5; y: 3
        }

        Text {
            text: gd.txt
            font.family: "Oxanium"
            font.pixelSize: gd.sz
            font.weight: Font.Bold
            color: Colours.accentPrimary
            opacity: 0.55
            x: 5; y: -3
        }

        Text {
            id: lbl
            text: gd.txt
            font.family: "Oxanium"
            font.pixelSize: gd.sz
            font.weight: Font.Bold
            color: Colours.accentSecondary
            transform: Translate { id: sh }
        }

        GlitchAnim {
            id: anim
            labelTarget: lbl
            shiftTarget: sh
            baseColor: Colours.accentSecondary
            intensity: 1.0
        }
    }

    AnimatedImage {
        id: bgGif
        height: parent.height
        width: sourceSize.width > 0 ? Math.ceil(height * sourceSize.width / sourceSize.height) : parent.width
        Component.onCompleted: source = root.gifSource
        fillMode: Image.Stretch
        playing: true

        SequentialAnimation on x {
            loops: Animation.Infinite
            NumberAnimation {
                to: -(Math.max(0, bgGif.width - root.width))
                duration: 14000
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 0
                duration: 14000
                easing.type: Easing.InOutSine
            }
        }
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Row {
            spacing: 0
            Layout.bottomMargin: -6
            Layout.alignment: Qt.AlignHCenter
            GlitchDigit { id: hoursTens; txt: Math.floor(clock.hours / 10).toString(); sz: root.fontSize }
            GlitchDigit { id: hoursUnits; txt: (clock.hours % 10).toString(); sz: root.fontSize }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "•••"
            font.family: "Oxanium"
            font.pixelSize: root.fontSize / 2
            color: Colours.accentPrimary
        }

        Row {
            spacing: 0
            Layout.topMargin: -6
            Layout.alignment: Qt.AlignHCenter
            GlitchDigit { id: minutesTens; txt: Math.floor(clock.minutes / 10).toString(); sz: root.fontSize }
            GlitchDigit { id: minutesUnits; txt: (clock.minutes % 10).toString(); sz: root.fontSize }
        }
    }

    CutShape {
        id: maskShape
        layer.enabled: true
        visible: false
        anchors.fill: parent
        fillColor: "white"
        cutBottomLeft: 24
    }

    Connections {
        target: clock
        function onMinutesChanged() {
            if (Math.floor(clock.minutes / 10) !== Math.floor(root._prevMinutes / 10)) minutesTens.glitch()
            if (clock.minutes % 10 !== root._prevMinutes % 10) minutesUnits.glitch()
            root._prevMinutes = clock.minutes
        }
        function onHoursChanged() {
            if (Math.floor(clock.hours / 10) !== Math.floor(root._prevHours / 10)) hoursTens.glitch()
            if (clock.hours % 10 !== root._prevHours % 10) hoursUnits.glitch()
            root._prevHours = clock.hours
        }
    }

    SequentialAnimation {
        id: gifFade
        NumberAnimation { target: bgGif; property: "opacity"; to: 0; duration: 500; easing.type: Easing.InQuart }
        ScriptAction { script: bgGif.source = root.gifSource }
        NumberAnimation { target: bgGif; property: "opacity"; to: 1; duration: 700; easing.type: Easing.OutQuart }
    }
}
