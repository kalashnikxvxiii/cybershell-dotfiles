// BindEditor.qml -- the menu's form for one personal keybind: name, command and keys.
// Capture and saving live in BindLogic.
import QtQuick
import QtQuick.Layouts
import "../../common/Colors.js" as CP
import "../../common"

ColumnLayout {
    id: root

    // { index, name, keys, command }; index -1 is a new bind
    property var draft: null
    signal closed()

    readonly property bool canSave: nameField.text.trim() !== "" && commandField.text.trim() !== "" && logic.keys !== ""

    spacing: 10

    onDraftChanged: {
        if (!draft)
            return
        nameField.text = draft.name
        commandField.text = draft.command
        if (draft.name === "")
            nameField.forceActiveFocus()
        else
            commandField.forceActiveFocus()
    }
    onVisibleChanged: if (!visible) logic.stopCapture()

    BindLogic {
        id: logic
        draft: root.draft
        onClosed: root.closed()
        onCaptureEnded: commandField.forceActiveFocus()
    }

    Field {
        id: nameField
        Layout.fillWidth: true
        label: "NAME"
    }
    Field {
        id: commandField
        Layout.fillWidth: true
        label: "COMMAND"
    }

    // Keys
    Item {
        id: captureBox
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        activeFocusOnTab: true

        Keys.onPressed: e => {
            if (logic.capturing)
                logic.capture(e.key, e.modifiers, e.nativeScanCode)
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)
                captureBox.begin()
            else if (e.key === Qt.Key_Escape)
                logic.cancel()
            else
                return
            e.accepted = true
        }

        function begin() {
            captureBox.forceActiveFocus()
            logic.startCapture()
        }

        CutShape {
            anchors.fill: parent
            cutBottomRight: 10
            fillColor: logic.capturing ? CP.alpha(CP.cyan, 0.15) : "transparent"
            strokeColor: logic.capturing || captureBox.activeFocus ? CP.cyan : CP.alpha(CP.cyan, 0.5)
            strokeWidth: logic.capturing ? 2 : 1
            inset: strokeWidth / 2
        }
        Text {
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            text: "KEYS"
            color: CP.alpha(CP.cyan, 0.7)
            font { family: "Oxanium"; pixelSize: 10 }
        }
        Text {
            x: 90
            anchors.verticalCenter: parent.verticalCenter
            text: logic.capturing ? "Press the combination, Esc to cancel"
                : logic.keys !== "" ? logic.keys : "Click or Enter to capture"
            color: logic.capturing || logic.keys !== "" ? CP.white : "#aab4c8"
            font { family: "Oxanium"; pixelSize: 14; bold: logic.keys !== "" && !logic.capturing }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (!logic.capturing) captureBox.begin()
        }
    }

    Text {
        Layout.fillWidth: true
        visible: text !== ""
        text: logic.status !== "" ? logic.status
            : logic.conflict !== "" ? "Already used by " + logic.conflict + ": both would fire"
            : ""
        color: CP.red
        wrapMode: Text.WordWrap
        font { family: "Oxanium"; pixelSize: 12 }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Button {
            label: "SAVE"
            accent: CP.cyan
            enabled: root.canSave && !logic.busy
            onClicked: logic.save(nameField.text, commandField.text)
        }
        Button {
            visible: root.draft !== null && root.draft.index >= 0
            label: logic.deleteArmed ? "CLICK AGAIN" : "DELETE"
            accent: CP.red
            enabled: !logic.busy
            onClicked: logic.remove()
        }
        Button {
            label: "CANCEL"
            accent: CP.cyan
            onClicked: logic.cancel()
        }
        Item { Layout.fillWidth: true }
    }

    component Field: Item {
        id: field
        property string label
        property alias text: input.text
        implicitHeight: 40

        function forceActiveFocus() { input.forceActiveFocus() }

        CutShape {
            anchors.fill: parent
            cutBottomRight: 10
            strokeColor: input.activeFocus ? CP.cyan : CP.alpha(CP.cyan, 0.5)
            strokeWidth: input.activeFocus ? 2 : 1
            inset: strokeWidth / 2
        }
        Text {
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            text: field.label
            color: CP.alpha(CP.cyan, 0.7)
            font { family: "Oxanium"; pixelSize: 10 }
        }
        TextInput {
            id: input
            x: 90
            width: parent.width - 104
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            selectByMouse: true
            activeFocusOnTab: true
            color: "#e6f7ff"
            font { family: "Oxanium"; pixelSize: 14 }
            Keys.onEscapePressed: logic.cancel()
        }
    }

    component Button: Item {
        id: button
        property string label
        property color accent
        signal clicked()
        implicitWidth: buttonText.implicitWidth + 28
        implicitHeight: 30
        opacity: enabled ? 1 : 0.35

        CutShape {
            anchors.fill: parent
            cutBottomRight: 8
            fillColor: hit.containsMouse ? CP.alpha(button.accent, 0.15) : "transparent"
            strokeColor: button.accent
            inset: 0.5
        }
        Text {
            id: buttonText
            anchors.centerIn: parent
            text: button.label
            color: button.accent
            font { family: "Oxanium"; pixelSize: 12; bold: true }
        }
        MouseArea {
            id: hit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }
}
