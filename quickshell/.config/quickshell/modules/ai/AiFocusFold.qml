// AiFocusFold.qml - a run of reasoning and tool calls, in focus view.
//
// The extension's fold row, label for label: everything the model did
// between two pieces of text is one line saying how many calls it took and
// how many failed, or how long it thought when it only thought. While the
// step runs, the line names what is being waited on. Unfolded, it lists the
// steps one by one, reasoning and calls interleaved as they happened, and
// ends with a row that folds it back
import QtQuick
import "../../common"
import "../../common/Colors.js" as CP

Item {
    id: root

    // { parts, calls, fails, ms, running, streaming, thinkingOnly, steps }
    required property var fold
    // The step at the tail of the reply in flight
    property bool live: false
    // The running tool is held at the permission card
    property bool waiting: false
    // Prefix of the keys its own blocks open under, in AiChat.openFolds
    property string keyBase: ""
    property bool expanded: false

    signal toggled()
    
    readonly property color fg: "#d8e0e8"

    readonly property string runningLabel: {
        if (!root.live) return ""
        if (root.fold.running !== "")
            return root.waiting ? "WAITING FOR PERMISSION\u2026"
            : "RUNNING " + String(root.fold.running).toUpperCase() + "\u2026"
        return root.fold.streaming ? "THINKING\u2026" : ""
    }

    readonly property string label: {
        const f = root.fold
        if (f.calls > 0)
            return f.calls + (f.calls === 1 ? " TOOL CALL" : " TOOL CALLS")
                + (f.fails > 0 ? " \u00b7 " + f.fails + " FAILED" : "")
        if (f.thinkingOnly)
            return f.streaming ? "THINKING\u2026"
                : f.ms > 0 ? "THOUGHT FOR " + Math.max(1, Math.round(f.ms / 1000)) + "S"
                : "THINKING"
        const n = Math.max(f.steps, 1)
        return n + (n === 1 ? " HIDDEN STEP" : " HIDDEN STEPS")
    }

    // The gutter marker of the step takes this: in progress, failed, done
    readonly property color dot: (root.runningLabel !== "" || (root.live && root.fold.streaming))
        ? CP.yellow : root.fold.fails > 0 ? CP.red : CP.neon

    implicitHeight: col.implicitHeight
    height: implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 4

        // -- The fold line ----------------------------------------
        Item {
            width: parent.width
            height: 17

            Row {
                id: head
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Text {
                    visible: root.runningLabel !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.runningLabel
                    font.family: "Oxanium"
                    font.pixelSize: 9
                    font.letterSpacing: 1.5
                    font.bold: true
                    opacity: pulse.k
                    color: CP.yellow
                }

                Text {
                    visible: root.runningLabel === "" || root.fold.calls > 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.label
                    font.family: "Oxanium"
                    font.pixelSize: 9
                    font.letterSpacing: 1.5
                    color: ma.containsMouse ? CP.cyan : CP.alpha(CP.cyan, 0.62)
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.expanded ? "\uf077" : "\uf078"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 8
                    color: CP.alpha(CP.cyan, ma.containsMouse ? 1 : 0.55)
                }
            }

            QtObject { id: pulse; property real k: 1 }

            SequentialAnimation {
                running: root.runningLabel !== ""
                loops: Animation.Infinite
                onStopped: pulse.k = 1
                NumberAnimation { target: pulse; property: "k"; from: 1.0; to: 0.55; duration: 600 }
                NumberAnimation { target: pulse; property: "k"; from: 0.55; to: 1.0; duration: 600 }
            }

            MouseArea {
                id: ma
                width: head.width + 8
                height: parent.height
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggled()
            }
        }
        // -- What it folds: each step of the run, in order --------------------
        Item {
            visible: root.expanded
            width: parent.width
            height: visible ? inner.implicitHeight : 0

            Rectangle {
                x: 3
                width: 1
                height: parent.height
                color: CP.alpha(CP.cyan, 0.22)
            }

            Column {
                id: inner
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 14
                spacing: 4

                Repeater {
                    model: root.expanded ? root.fold.parts : []

                    Loader {
                        id: sub
                        required property var modelData
                        required property int index
                        readonly property string key: root.keyBase + ":" + index

                        width: inner.width
                        sourceComponent: sub.modelData.kind === "tool" ? subTool : subThought

                        Component {
                            id: subTool
                            AiToolRow { call: sub.modelData }
                        }

                        Component {
                            id: subThought
                            AiThoughtBlock {
                                streaming: sub.modelData.streaming === true
                                text: streaming ? AiState.liveThought : (sub.modelData.text ?? "")
                                ms: sub.modelData.ms ?? 0
                                expanded: AiState.chat?.isOpen(sub.key) ?? false
                                onToggled: AiState.chat.toggleOpen(sub.key)
                            }
                        }
                    }
                }

                // The extension closes a long fold from its end too: the
                // header may have scrolled out of sight by then
                Item {
                    width: inner.width
                    height: 16

                    Row {
                        id: endRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "COLLAPSE"
                            font.family: "Oxanium"
                            font.pixelSize: 9
                            font.letterSpacing: 1.5
                            color: endMa.containsMouse ? CP.cyan : CP.alpha(CP.cyan, 0.45)
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\uf077"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 8
                            color: CP.alpha(CP.cyan, endMa.containsMouse ? 1 : 0.45)
                        }
                    }

                    MouseArea {
                        id: endMa
                        width: endRow.width + 8
                        height: parent.height
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggled()
                    }
                }
            }
        }
    }
}
