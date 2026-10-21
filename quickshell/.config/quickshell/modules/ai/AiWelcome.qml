// AiWelcome.qml - what an empty conversation shows: the mascot and one line.
//
// A new line is drawn every time the view comes up empty. It types itself out
// over a layout that is already final: the part not yet revealed is laid out
// in a transparent colour, so a centred, wrapped line never shifts as it grows
import QtQuick
import "../../common/effects"
import Quickshell
import "../../common/Colors.js" as CP

Column {
    id: root

    spacing: 18

    readonly property color fg: "#d8e0e8"
    readonly property string name: {
        const u = Quickshell.env("USER") || ""
        return u === "" ? "" : u[0].toUpperCase() + u.slice(1)
    }

    // %1 is the user's name
    readonly property var lines: [
        "What are we building today, %1?",
        "Hi %1. Where should we start?",
        "Back again, %1. What's on your mind?",
        "Good to see you, %1. Anything I can untangle?",
        "%1, bring me a bug, a question or a half-formed idea.",
        "Your shell, your rules, %1. What are we tweaking?",
        "How can I help you today?",
        "What would you like to think through?",
        "Fresh context, clear head. What's first?",
        "Ask me anything. I'll say so if I don't know.",
        "Let's make something good.",
        "Got a stubborn QML binding? I like those.",
        "Plan, search, build. Your call."
    ]

    property string greeting: ""
    property int shown: 0

    function pick() {
        const h = new Date().getHours()
        const timed = h < 5 ? "Burning the midnight oil, %1?"
            : h < 12 ? "Good morning, %1."
            : h < 18 ? "Good afternoon, %1."
            : "Good evening, %1."
        // The time of day is the single most likely line, as on claude.ai
        const pool = root.lines.concat([timed, timed, timed])
        let g = root.greeting
        while (pool.length > 1 && g === root.greeting)
            g = pool[Math.floor(Math.random() * pool.length)].replace("%1", root.name)
        root.greeting = g
        root.shown = 0
    }

    onVisibleChanged: if (visible) pick()
    Component.onCompleted: pick()

    Timer {
        interval: 28
        repeat: true
        running: root.visible && root.shown < root.greeting.length
        onTriggered: root.shown++
    }

    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: clawd.width + 48
        height: clawd.height + 3

        AiClawd {
            id: clawd
            anchors.horizontalCenter: parent.horizontalCenter
            hole: CP.void2
        }

        // Something to stand on: without it the hop reads as floating
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: CP.alpha(CP.magenta, 0.30)
        }
    }

    Text {
        width: root.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        textFormat: Text.StyledText
        text: root.greeting.slice(0, root.shown)
            + "<font color='#00000000'>" + root.greeting.slice(root.shown) + "</font>"
        font.family: "Oxanium"
        font.pixelSize: 16
        font.letterSpacing: 0.5
        color: root.fg
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "AWAITING INPUT"
        font.family: "Oxanium"
        font.pixelSize: 9
        font.letterSpacing: 3
        color: CP.magenta

        opacity: awaitPulse.k
        Pulse { id: awaitPulse; running: root.visible; from: 0.55; to: 0.18; halfMs: 1700; sine: true }
    }
}
