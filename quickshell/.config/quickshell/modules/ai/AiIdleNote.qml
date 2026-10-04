// AiIdleNote.qml - what the transcript says under its last turn once the
// prompt cache is gone.
//
// The extension's line, the same facts: how long the chat has been idle and
// how many tokens the next message will send again, or that a compacted
// conversation is not cached at all. Under it, the CLI's recap for a user
// coming back: what the goal was and what comes next
import QtQuick
import "../../common"
import "../../common/Colors.js" as CP
import "AiHighlight.js" as Hl

Item {
    id: root

    property var chat: null

    readonly property bool shown: root.chat !== null && root.chat.cacheExpired
        && !root.chat.session.busy && root.chat.live === null && root.chat.messages.length > 0

    // The last thing that happened was a compaction: the summary that
    // replaced the conversation has never been cached
    readonly property bool compacted: {
        const m = root.chat?.messages ?? []
        const parts = m.length > 0 ? m[m.length - 1].parts : []
        return parts.length > 0 && parts[parts.length - 1].kind === "compact"
    }

    property real _now: Date.now()

    // The extension's format: minutes, then hours and minutes, then days
    function span(ms) {
        const m = Math.max(0, Math.floor(ms / 60000))
        if (m < 60) return m + "M"
        const h = Math.floor(m / 60)
        if (h < 24) return h + "H " + (m % 60) + "M"
        return Math.floor(h / 24) + "D " + (h % 24) + "H"
    }

    function tokens(n) {
        if (n >= 1e6) return (n / 1e6).toFixed(1) + "M"
        if (n >= 1000) return Math.round(n / 1000) + "K"
        return String(n)
    }

    readonly property string line: {
        if (!root.shown) return ""
        if (root.compacted) return "CONVERSATION COMPACTED \u00b7 THE NEXT MESSAGE RE-CACHES IT"
        const k = root.chat.session.contextTokens
        return "IDLE " + root.span(root._now - root.chat.cacheStamp)
            + " \u00b7 PROMPT CACHE LIKELY EXPIRED \u00b7 THE NEXT MESSAGE RE-CACHES "
            + (k > 0 ? "~" + root.tokens(k) + " TOKENS" : "THE CONVERSATION")
    }

    visible: root.shown
    implicitHeight: root.shown ? col.implicitHeight : 0
    height: implicitHeight

    // Minutes are all the line shows: twice a minute is plenty
    Timer {
        interval: 30000
        repeat: true
        triggeredOnStart: true
        running: root.shown
        onTriggered: root._now = Date.now()
    }

    Column {
        id: col
        width: parent.width
        spacing: 6

        Rectangle {
            width: parent.width
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: CP.alpha(CP.yellow, 0.45) }
                GradientStop { position: 1; color: "transparent" }
            }
        }

        Text {
            width: parent.width
            text: "\u25e2 " + root.line
            wrapMode: Text.Wrap
            font.family: "Oxanium"
            font.pixelSize: 9
            font.letterSpacing: 1.4
            lineHeight: 1.3
            color: CP.alpha(CP.yellow, 0.7)
        }

        Text {
            id: writing
            visible: root.chat?.recapping ?? false
            text: "\u203b RECAP \u00b7 WRITING\u2026"
            font.family: "Oxanium"
            font.pixelSize: 9
            font.letterSpacing: 1.4
            color: CP.magenta
            opacity: pulse.k

            QtObject { id: pulse; property real k: 1 }

            SequentialAnimation {
                running: writing.visible
                loops: Animation.Infinite
                onStopped: pulse.k = 1
                NumberAnimation { target: pulse; property: "k"; from: 1.0; to: 0.5; duration: 600 }
                NumberAnimation { target: pulse; property: "k"; from: 0.5; to: 1.0; duration: 600 }
            }
        }

        Row {
            visible: (root.chat?.recap ?? "") !== ""
            width: parent.width
            spacing: 6

            Text {
                id: mark
                text: "\u203b"
                font.family: "Oxanium"
                font.pixelSize: 12
                color: CP.magenta
            }

            AiRichText {
                width: parent.width - mark.width - parent.spacing
                html: '<span style="color:' + CP.magenta + '">RECAP</span>&nbsp; '
                    + Hl.esc(root.chat?.recap ?? "")
                font.pixelSize: 11
                font.italic: true
                color: CP.alpha("#d8e0e8", 0.75)
            }
        }
    }
}
