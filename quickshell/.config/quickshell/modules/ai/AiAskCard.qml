// AiAskCard.qml - the AskUserQuestion tool as a form.
//
// The CLI blocks the turn on a can_use_tool request whose input is a list of
// questions, each with a few options. The answer goes back inside the same
// input, as `answers`: question text -> chosen label, several joined by ", ".
// A free-text "other" answer is just that text. Verified on CLI 2.1.295
import QtQuick
import "../../common"
import "../../common/Colors.js" as CP

Item {
    id: root

    // The pendingPermission object from AiSession, or null
    property var request: null
    // Taller than this and the form scrolls
    property real maxHeight: 400

    signal submitted(var answers)
    signal cancelled()

    readonly property bool pending: root.request !== null
    readonly property var questions: root.request?.input?.questions ?? []

    // Per question: { picked: [labels], other: "" }
    property var sel: []
    // Read from the request, not from `questions`: that binding may not have
    // been re-evaluated yet when this runs
    onRequestChanged: root.sel = (root.request?.input?.questions ?? [])
        .map(() => ({ picked: [], other: "" }))

    function _answer(i) {
        const s = root.sel[i]
        if (!s) return ""
        const o = s.other.trim()
        return s.picked.concat(o !== "" ? [o] : []).join(", ")
    }

    readonly property bool complete: root.questions.length > 0
        && root.questions.every((q, i) => root._answer(i) !== "")

    function pick(i, label) {
        const s = root.sel.slice()
        const cur = s[i].picked
        const multi = root.questions[i].multiSelect === true
        s[i] = { picked: !multi ? [label]
                : cur.indexOf(label) >= 0 ? cur.filter(l => l !== label) : cur.concat([label]),
            other: multi ? s[i].other : "" }
        root.sel = s
    }

    function setOther(i, text) {
        const s = root.sel.slice()
        const multi = root.questions[i].multiSelect === true
        // One answer only: typing one replaces the pick
        s[i] = { picked: multi ? s[i].picked : [], other: text }
        root.sel = s
    }

    function submit() {
        if (!root.complete) return
        const a = {}
        root.questions.forEach((q, i) => { a[q.question] = root._answer(i) })
        root.submitted(a)
    }

    implicitHeight: root.pending ? Math.min(content.implicitHeight + 24, root.maxHeight) : 0
    height: implicitHeight
    visible: height > 0
    clip: true

    CutShape {
        anchors.fill: parent
        fillColor: CP.alpha(CP.cyan, 0.06)
        strokeColor: CP.cyan
        strokeWidth: 1.5
        inset: 0.75
        cutTopLeft: 6
        cutBottomRight: 6
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: 12
        contentHeight: content.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: content
            width: flick.width
            spacing: 10

            Text {
                text: "\u25e2 CLAUDE IS ASKING"
                font.family: "Oxanium"
                font.pixelSize: 10
                font.letterSpacing: 2
                font.bold: true
                color: CP.cyan
            }

            Repeater {
                model: root.questions

                Column {
                    id: q
                    required property var modelData
                    required property int index
                    readonly property bool multi: q.modelData.multiSelect === true

                    width: content.width
                    spacing: 5

                    Text {
                        width: parent.width
                        text: String(q.modelData.header ?? "").toUpperCase()
                            + (q.multi ? "  \u00b7  SELECT ANY" : "")
                        elide: Text.ElideRight
                        font.family: "Oxanium"
                        font.pixelSize: 8
                        font.letterSpacing: 2
                        font.bold: true
                        color: CP.magenta
                    }

                    Text {
                        width: parent.width
                        text: q.modelData.question ?? ""
                        wrapMode: Text.Wrap
                        font.family: "Oxanium"
                        font.pixelSize: 12
                        color: "#e8f0f4"
                    }

                    Repeater {
                        model: q.modelData.options ?? []

                        Item {
                            id: opt
                            required property var modelData
                            readonly property bool on: (root.sel[q.index]?.picked ?? [])
                                .indexOf(opt.modelData.label) >= 0

                            width: q.width
                            height: Math.max(24, texts.implicitHeight + 10)

                            Rectangle {
                                anchors.fill: parent
                                color: opt.on ? CP.alpha(CP.cyan, 0.14)
                                    : (om.containsMouse ? CP.alpha(CP.cyan, 0.07) : "transparent")
                                border.width: 1
                                border.color: CP.alpha(CP.cyan, opt.on ? 0.70 : 0.22)
                            }

                            // Square for "any of these", diamond for "one of these"
                            Rectangle {
                                x: 9
                                y: 9
                                width: 7
                                height: 7
                                rotation: q.multi ? 0 : 45
                                color: opt.on ? CP.cyan : "transparent"
                                border.width: 1
                                border.color: CP.alpha(CP.cyan, 0.75)
                            }

                            Column {
                                id: texts
                                x: 28
                                y: 5
                                width: parent.width - 38
                                spacing: 1

                                Text {
                                    width: parent.width
                                    text: opt.modelData.label ?? ""
                                    wrapMode: Text.Wrap
                                    font.family: "Oxanium"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: opt.on ? CP.cyan : "#d8e0e8"
                                }

                                Text {
                                    width: parent.width
                                    visible: text !== ""
                                    text: opt.modelData.description ?? ""
                                    wrapMode: Text.Wrap
                                    font.family: "Oxanium"
                                    font.pixelSize: 9
                                    color: CP.alpha("#d8e0e8", 0.50)
                                }
                            }

                            MouseArea {
                                id: om
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!q.multi) other.text = ""
                                    root.pick(q.index, opt.modelData.label)
                                }
                            }
                        }
                    }

                    // Anything else
                    Item {
                        width: q.width
                        height: 26

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.width: 1
                            border.color: CP.alpha(CP.cyan, other.activeFocus ? 0.70 : 0.22)
                        }

                        TextInput {
                            id: other
                            anchors.fill: parent
                            anchors.leftMargin: 9
                            anchors.rightMargin: 9
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            clip: true
                            font.family: "Oxanium"
                            font.pixelSize: 11
                            color: "#d8e0e8"
                            selectionColor: CP.alpha(CP.cyan, 0.35)
                            onTextEdited: root.setOther(q.index, other.text)
                            onAccepted: root.submit()

                            Text {
                                visible: other.text === "" && !other.activeFocus
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Other\u2026"
                                font: other.font
                                color: CP.alpha("#d8e0e8", 0.30)
                            }
                        }
                    }
                }
            }

            Row {
                spacing: 6

                AiHeaderButton {
                    label: "SUBMIT"
                    accent: CP.neon
                    enabled: root.complete
                    onTriggered: root.submit()
                }

                AiHeaderButton {
                    label: "DISMISS"
                    accent: CP.red
                    onTriggered: root.cancelled()
                }
            }
        }
    }
}
