// AiToolGroup.qml — consecutive tool calls, folded into one line.
//
// The tools are how the answer was produced, not the answer: expanded by
// default they turn a three-line reply into a wall of machinery. Folded, the
// group still reports the only two things that matter at a glance — how many,
// and whether any of them is still running or has failed.
import QtQuick
import "../../common/effects"
import "../../common"
import "../../common/Colors.js" as CP

Item {
    id: root

    required property var calls     // [{ name, input, id, state }]
    // Owned by the transcript, which outlives this row: see AiChat.openFolds
    property bool expanded: false

    signal toggled()

    readonly property bool anyRunning: {
        for (const c of root.calls) if (c.state === "running") return true
        return false
    }
    readonly property bool anyError: {
        for (const c of root.calls) if (c.state === "error") return true
        return false
    }
    readonly property int failed: root.calls.filter(c => c.state === "error").length
    // The one being waited on, named the way the CLI's own line does
    readonly property string running: {
        for (const c of root.calls) if (c.state === "running") return c.name
        return ""
    }
    readonly property color accent: root.anyError ? CP.red
        : root.anyRunning ? CP.yellow : CP.cyan

    implicitHeight: col.implicitHeight
    height: implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 2

        Item {
            id: summary
            width: parent.width
            height: 17
            opacity: summaryPulse.k

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.expanded ? "\u25be" : "\u25b8"
                    font.family: "Oxanium"
                    font.pixelSize: 9
                    color: root.accent
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.running !== ""
                        ? "RUNNING " + String(root.running).toUpperCase() + "\u2026 \u00b7 " : "")
                        + root.calls.length
                        + (root.calls.length === 1 ? " TOOL CALL" : " TOOL CALLS")
                        + (root.failed > 0 ? " \u00b7 " + root.failed + " FAILED" : "")
                    font.family: "Oxanium"
                    font.pixelSize: 9
                    font.letterSpacing: 1.5
                    color: ma.containsMouse
                        ? root.accent : CP.alpha(root.accent, 0.72)
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
            }

            // Only the summary pulses: animating the expanded rows as well would
            // turn the transcript into a strobe
            Pulse { id: summaryPulse; running: root.visible && root.anyRunning; from: 1.0; to: 0.6; halfMs: 600 }

            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggled()
            }
        }

        Repeater {
            model: root.expanded ? root.calls : []

            AiToolRow {
                required property var modelData
                x: 14
                width: col.width - 14
                call: modelData
            }
        }
    }
}
