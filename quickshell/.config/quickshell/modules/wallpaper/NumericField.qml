import "../../common/Colors.js" as CP
import "../../common"
import QtQuick

Item {
    id: root

    property string label: ""
    property string suffix: ""
    property real   value: 0
    property real   minValue: 0
    property real   maxValue: 1000
    property int    decimals: 0
    property bool   isInt: true

    signal valueEdited(real newValue)

    implicitWidth: 260
    implicitHeight: 28

    Text {
        id: lbl
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 90
        text: root.label.toUpperCase()
        font.family: "Oxanium"
        font.pixelSize: 9
        font.letterSpacing: 1.5
        color: Colours.textMuted
    }

    CutShape {
        id: inputBg
        anchors.left: lbl.right
        anchors.right: parent.right
        height: 24
        anchors.verticalCenter: parent.verticalCenter
        fillColor: CP.alpha(CP.cyan, 0.06)
        strokeColor: input.activeFocus
            ? CP.alpha(CP.cyan, 0.85)
            : CP.alpha(CP.cyan, 0.35)
        strokeWidth: 1
        inset: 0.5
        cutTopLeft: 3
        cutBottomRight: 3
        Behavior on strokeColor { ColorAnimation { duration: 150 } }
    }

    TextInput {
        id: input
        anchors.left: inputBg.left
        anchors.leftMargin: 8
        anchors.right: suffixLbl.left
        anchors.rightMargin: 4
        anchors.verticalCenter: inputBg.verticalCenter
        verticalAlignment: TextInput.AlignVCenter
        font.family: "Oxanium"
        font.pixelSize: 10
        color: Colours.textPrimary
        selectByMouse: true
        validator: root.isInt ? intVal : dblVal

        onEditingFinished: {
            var v = root.isInt ? parseInt(text) : parseFloat(text)
            if (!isNaN(v)) {
                v = Math.max(root.minValue, Math.min(root.maxValue, v))
                root.valueEdited(v)
            }
        }
        Keys.onEscapePressed: function(event) {
            input.focus = false
            event.accepted = false
        }
    }

    // Keep input.text in sync with root.value when not editing
    Binding {
        target: input
        property: "text"
        value: root.isInt
            ? Math.round(root.value).toString()
            : root.value.toFixed(root.decimals)
        when: !input.activeFocus
    }

    IntValidator    { id: intVal; bottom: Math.round(root.minValue); top: Math.round(root.maxValue) }
    DoubleValidator { id: dblVal; bottom: root.minValue; top: root.maxValue; decimals: root.decimals }

    Text {
        id: suffixLbl
        anchors.right: inputBg.right
        anchors.rightMargin: 6
        anchors.verticalCenter: inputBg.verticalCenter
        text: root.suffix
        font.family: "Oxanium"
        font.pixelSize: 8
        font.letterSpacing: 1
        color: Colours.textMuted
    }
}
