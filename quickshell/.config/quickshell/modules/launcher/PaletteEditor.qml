// PaletteEditor.qml -- the menu's form for one user palette: its name and its ten colors. While it
// is open the whole shell previews the palette (Theme.preview); Cancel drops it, Save stores it.
import QtQuick
import QtQuick.Layouts
import "../../common/Colors.js" as CP
import "../../common"

ColumnLayout {
    id: root

    // { name, roles, isNew }: a new palette starts as a copy, with an empty name
    property var draft: null
    signal closed()

    property var work: ({})
    property string role: "cyan"
    property bool deleteArmed: false
    readonly property string error: Theme.nameError(nameInput.text.trim(), root.draft && !root.draft.isNew ? root.draft.name : "")

    readonly property var labels: ({
        cyan: "TECH", yellow: "PRIMARY", red: "DANGER", magenta: "MEMORY", neon: "OK",
        amber: "WARNING", void_: "BACKGROUND", void2: "DEEP BG", moduleBg: "PANEL", moduleBgAlt: "PANEL ALT"
    })
    // Backgrounds are see-through: they get the alpha bar
    readonly property bool translucent: ["moduleBg", "moduleBgAlt"].indexOf(root.role) >= 0

    spacing: 10

    onDraftChanged: {
        root.deleteArmed = false
        if (!draft)
            return
        root.work = Object.assign({}, draft.roles)
        root.role = "cyan"
        nameInput.text = draft.name
        Theme.preview = root.work
        nameInput.forceActiveFocus()
    }
    onVisibleChanged: if (!visible) Theme.preview = null

    function setColor(c) {
        const w = Object.assign({}, root.work)
        w[root.role] = String(c)
        root.work = w
        Theme.preview = w
    }
    function cancel() {
        Theme.preview = null
        root.closed()
    }
    function save() {
        if (Theme.store(nameInput.text.trim(), root.work, root.draft.isNew ? "" : root.draft.name))
            root.closed()
    }

    // Name
    Item {
        Layout.fillWidth: true
        implicitHeight: 40
        CutShape {
            anchors.fill: parent
            cutBottomRight: 10
            strokeColor: nameInput.activeFocus ? Theme.cyan : CP.alpha(Theme.cyan, 0.5)
            strokeWidth: nameInput.activeFocus ? 2 : 1
            inset: strokeWidth / 2
        }
        Text {
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            text: "NAME"
            color: CP.alpha(Theme.cyan, 0.7)
            font { family: Theme.font; pixelSize: 10 }
        }
        TextInput {
            id: nameInput
            x: 90
            width: parent.width - 104
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            selectByMouse: true
            color: "#e6f7ff"
            font { family: Theme.font; pixelSize: 14 }
            Keys.onEscapePressed: root.cancel()
            Keys.onReturnPressed: root.save()
            Keys.onEnterPressed: root.save()
        }
    }

    // The ten roles: pick one, then its color below
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 8
        rowSpacing: 6
        Repeater {
            model: Theme.roles
            Item {
                id: chip
                required property string modelData
                readonly property bool selected: root.role === modelData
                Layout.fillWidth: true
                implicitHeight: 26

                CutShape {
                    anchors.fill: parent
                    cutBottomRight: 7
                    fillColor: chip.selected ? CP.alpha(Theme.cyan, 0.15) : "transparent"
                    strokeColor: chip.selected ? Theme.cyan : CP.alpha(Theme.cyan, 0.35)
                    strokeWidth: chip.selected ? 2 : 1
                    inset: strokeWidth / 2
                }
                Rectangle {
                    x: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30
                    height: 14
                    color: root.work[chip.modelData] || "transparent"
                    border.color: CP.alpha("#ffffff", 0.3)
                }
                Text {
                    x: 44
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.labels[chip.modelData]
                    color: chip.selected ? CP.white : "#aab4c8"
                    font { family: Theme.font; pixelSize: 11; bold: true; letterSpacing: 1 }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.role = chip.modelData
                }
            }
        }
    }

    ColorPicker {
        Layout.fillWidth: true
        alphaEnabled: root.translucent
        color: root.work[root.role] || "white"
        original: root.draft && root.draft.roles[root.role] ? root.draft.roles[root.role] : "white"
        onPicked: c => root.setColor(c)
    }

    Text {
        Layout.fillWidth: true
        visible: text !== ""
        text: root.deleteArmed ? "Click DELETE again to remove " + root.draft.name.toUpperCase() : root.error
        color: Theme.red
        wrapMode: Text.WordWrap
        font { family: Theme.font; pixelSize: 12 }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Button {
            label: "SAVE"
            accent: Theme.cyan
            enabled: root.error === ""
            onClicked: root.save()
        }
        Button {
            // Only user palettes, never the fixed ones
            visible: root.draft !== null && !root.draft.isNew
            label: root.deleteArmed ? "CLICK AGAIN" : "DELETE"
            accent: Theme.red
            onClicked: {
                if (!root.deleteArmed) {
                    root.deleteArmed = true
                    return
                }
                Theme.preview = null
                Theme.remove(root.draft.name)
                root.closed()
            }
        }
        Button {
            label: "CANCEL"
            accent: Theme.cyan
            onClicked: root.cancel()
        }
        Item { Layout.fillWidth: true }
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
            font { family: Theme.font; pixelSize: 12; bold: true }
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
