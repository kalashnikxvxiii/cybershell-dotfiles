// BindStrip.qml -- the cheatsheet's own way to add a bind: a "+" beside the search that opens
// into one line, command and keys. The name comes from the command; a clash lights the row.
import QtQuick
import "../../common/Colors.js" as CP
import "../../common"
import "../launcher"

Item {
    id: root

    property var draft: null
    property var userBinds: []
    readonly property string conflictCombo: logic.conflict !== "" ? logic.keys : ""
    signal openRequested()
    signal closed()

    readonly property string message: logic.status !== "" ? logic.status
        : logic.conflict !== "" ? "Used by " + logic.conflict : ""

    width: draft ? line.width : 30
    height: 30

    onDraftChanged: {
        if (!draft)
            return
        command.text = draft.command
        command.forceActiveFocus()
    }

    function nameFor(text) {
        if (draft.index >= 0)
            return draft.name
        const base = text.trim().split(/\s+/)[0].split("/").pop()
        let name = base, n = 2
        while (userBinds.some(b => b.name === name))
            name = base + " " + n++
        return name
    }

    function save() {
        if (command.text.trim() !== "" && logic.keys !== "" && !logic.busy)
            logic.save(nameFor(command.text), command.text)
    }

    BindLogic {
        id: logic
        draft: root.draft
        onClosed: root.closed()
        onCaptureEnded: command.forceActiveFocus()
    }

    Small {
        visible: !root.draft
        label: "+"
        tone: CP.cyan
        onClicked: root.openRequested()
    }

    Row {
        id: line
        visible: !!root.draft
        spacing: 6

        Item {
            width: 230
            height: 30

            CutShape {
                anchors.fill: parent
                // cutBottomLeft: 8
                inset: 0.5
                fillColor: Qt.rgba(0.03, 0.045, 0.08, 0.9)
                strokeColor: CP.alpha(CP.cyan, command.activeFocus ? 1 : 0.45)
            }
            TextInput {
                id: command
                x: 12
                width: parent.width - 24
                height: parent.height
                clip: true
                activeFocusOnTab: true
                selectByMouse: true
                verticalAlignment: TextInput.AlignVCenter
                color: "#e8f2f4"
                font { family: "Oxanium"; pixelSize: 13 }
                Keys.onEscapePressed: logic.cancel()
                Keys.onReturnPressed: logic.keys === "" ? capture.begin() : root.save()
                Keys.onEnterPressed: logic.keys === "" ? capture.begin() : root.save()
            }
            Text {
                x: 12
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                visible: command.text === ""
                text: "COMMAND"
                color: "#7f9296"
                font { family: "Oxanium"; pixelSize: 11; letterSpacing: 2 }
            }
        }

        Item {
            id: capture
            width: 150
            height: 30
            activeFocusOnTab: true

            function begin() {
                capture.forceActiveFocus()
                logic.startCapture()
            }

            Keys.onPressed: e => {
                if (logic.capturing)
                    logic.capture(e.key, e.modifiers, e.nativeScanCode)
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)
                    capture.begin()
                else if (e.key === Qt.Key_Escape)
                    logic.cancel()
                else
                    return
                e.accepted = true
            }

            CutShape {
                anchors.fill: parent
                inset: 0.5
                fillColor: logic.capturing ? CP.alpha(CP.cyan, 0.15) : Qt.rgba(0.03, 0.045, 0.08, 0.9)
                strokeColor: logic.conflict !== "" ? CP.red : CP.alpha(CP.cyan, logic.capturing || capture.activeFocus ? 1 : 0.45)
            }
            Text {
                anchors.centerIn: parent
                width: parent.width - 12
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideLeft
                text: logic.capturing ? "PRESS KEYS" : logic.keys !== "" ? logic.keys : "KEYS"
                color: logic.keys !== "" && !logic.capturing ? "#e8f2f4" : "#7f9296"
                font { family: "Oxanium"; pixelSize: 11; letterSpacing: 1 }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (!logic.capturing) capture.begin()
            }
        }

        Small {
            label: "✓"
            tone: CP.cyan
            opacity: command.text.trim() !== "" && logic.keys !== "" ? 1 : 0.35
            onClicked: root.save()
        }
        // On an existing bind: delete, on the second click
        Small {
            visible: !!root.draft && root.draft.index >= 0
            label: logic.deleteArmed ? "?" : "−"
            tone: CP.red
            onClicked: logic.remove()
        }
        Small {
            label: "✕"
            tone: CP.red
            onClicked: logic.cancel()
        }
    }

    Text {
        anchors.top: line.bottom
        anchors.topMargin: 6
        visible: !!root.draft
        text: root.message
        color: CP.red
        font { family: "Oxanium"; pixelSize: 11; letterSpacing: 1 }
    }

    component Small: Item {
        id: small
        property string label
        property color tone
        signal clicked()
        width: 30
        height: 30

        CutShape {
            anchors.fill: parent
            cutBottomRight: 7
            inset: 0.5
            fillColor: Qt.rgba(small.tone.r, small.tone.g, small.tone.b, hit.containsMouse ? 0.3 : 0.08)
            strokeColor: Qt.rgba(small.tone.r, small.tone.g, small.tone.b, hit.containsMouse ? 1 : 0.55)
        }
        Text {
            anchors.centerIn: parent
            text: small.label
            color: small.tone
            font { family: "Oxanium"; pixelSize: 13; bold: true }
        }
        MouseArea {
            id: hit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: small.clicked()
        }
    }
}
