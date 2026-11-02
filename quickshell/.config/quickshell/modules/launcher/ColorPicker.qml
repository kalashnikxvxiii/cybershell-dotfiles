// ColorPicker.qml -- saturation/value square, hue bar, optional alpha bar, hex and RGB(A) fields,
// before/after swatch and a screen eyedropper (hyprpicker). Set `color` from outside; every
// change made here is reported through picked(color).
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../common/Colors.js" as CP
import "../../common"

ColumnLayout {
    id: root

    property color color: "white"
    // The color the role had when the editor opened, shown next to the new one
    property color original: color
    property bool alphaEnabled: false
    signal picked(color c)

    // The working values: hue survives a pass through grey or black, where it has none
    property real h: 0
    property real s: 0
    property real v: 1
    property real a: 1

    spacing: 8

    function _fromColor(c) {
        const k = Qt.color(c)
        if (k.hsvHue >= 0)
            root.h = k.hsvHue
        root.s = k.hsvSaturation
        root.v = k.hsvValue
        root.a = k.a
    }
    // Only when the change comes from outside: re-reading our own result would drop the hue
    onColorChanged: if (!Qt.colorEqual(root.color, root._current())) root._fromColor(root.color)
    Component.onCompleted: root._fromColor(root.color)

    function _current() { return Qt.hsva(root.h, root.s, root.v, root.alphaEnabled ? root.a : 1) }
    function _emit() { root.picked(root._current()) }
    function set(c) {
        root._fromColor(c)
        if (!root.alphaEnabled)
            root.a = 1
        root._emit()
    }

    function hex(c) {
        const k = Qt.color(c)
        const two = x => ("0" + Math.round(x * 255).toString(16)).slice(-2)
        return "#" + (root.alphaEnabled ? two(k.a) : "") + two(k.r) + two(k.g) + two(k.b)
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        // Saturation (left to right) and value (bottom to top) at the current hue
        Item {
            id: sv
            Layout.fillWidth: true
            Layout.preferredHeight: 170

            Rectangle {
                anchors.fill: parent
                color: Qt.hsva(root.h, 1, 1, 1)
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "white" }
                    GradientStop { position: 1; color: "transparent" }
                }
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: "black" }
                }
            }
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: CP.alpha(Theme.cyan, 0.5)
            }
            // Cursor: a square, no soft edges
            Rectangle {
                x: root.s * sv.width - 6
                y: (1 - root.v) * sv.height - 6
                width: 12
                height: 12
                color: "transparent"
                border.color: root.v > 0.5 ? "black" : "white"
                border.width: 2
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.CrossCursor
                preventStealing: true
                function pick(m) {
                    root.s = Math.max(0, Math.min(1, m.x / width))
                    root.v = Math.max(0, Math.min(1, 1 - m.y / height))
                    root._emit()
                }
                onPressed: m => pick(m)
                onPositionChanged: m => { if (pressed) pick(m) }
            }
        }

        Bar {
            id: hueBar
            value: root.h
            onMoved: x => { root.h = x; root._emit() }
            Gradient {
                id: hues
                GradientStop { position: 0.000; color: "#ff0000" }
                GradientStop { position: 0.167; color: "#ffff00" }
                GradientStop { position: 0.333; color: "#00ff00" }
                GradientStop { position: 0.500; color: "#00ffff" }
                GradientStop { position: 0.667; color: "#0000ff" }
                GradientStop { position: 0.833; color: "#ff00ff" }
                GradientStop { position: 1.000; color: "#ff0000" }
            }
            fill: hues
        }

        Bar {
            visible: root.alphaEnabled
            // Opaque at the top
            value: 1 - root.a
            onMoved: x => { root.a = 1 - x; root._emit() }
            Gradient {
                id: alphas
                GradientStop { position: 0; color: Qt.hsva(root.h, root.s, root.v, 1) }
                GradientStop { position: 1; color: "transparent" }
            }
            fill: alphas
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        // Before / after
        Row {
            Rectangle { width: 22; height: 28; color: root.original }
            Rectangle { width: 22; height: 28; color: root._current() }
        }

        Field {
            Layout.preferredWidth: root.alphaEnabled ? 104 : 86
            label: "#"
            text: root.hex(root._current()).slice(1)
            onCommitted: t => {
                const x = t.trim().replace("#", "")
                // 3, 6 or 8 hex digits; anything else is ignored
                if ([3, 6, 8].indexOf(x.length) >= 0 && x.split("").every(ch => "0123456789abcdefABCDEF".indexOf(ch) >= 0))
                    root.set("#" + x)
            }
        }
        Repeater {
            model: root.alphaEnabled ? ["R", "G", "B", "A"] : ["R", "G", "B"]
            Field {
                id: channel
                required property string modelData
                Layout.preferredWidth: 46
                label: modelData
                text: {
                    const k = root._current()
                    return String(Math.round(255 * (modelData === "R" ? k.r : modelData === "G" ? k.g : modelData === "B" ? k.b : k.a)))
                }
                onCommitted: t => {
                    const n = parseInt(t)
                    if (isNaN(n) || n < 0 || n > 255)
                        return
                    const k = root._current()
                    const c = [k.r, k.g, k.b, k.a]
                    c["RGBA".indexOf(channel.modelData)] = n / 255
                    root.set(Qt.rgba(c[0], c[1], c[2], c[3]))
                }
            }
        }
        Item { Layout.fillWidth: true }

        // Eyedropper: a color from anywhere on screen. In an Item: a CutShape sized by the
        // layout itself loops on its own path
        Item {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 28
            CutShape {
                anchors.fill: parent
                cutBottomRight: 7
                fillColor: dropperHit.containsMouse || dropper.running ? CP.alpha(Theme.cyan, 0.2) : "transparent"
                strokeColor: Theme.cyan
                inset: 0.5
            }
            Text {
                anchors.centerIn: parent
                text: "\uf1fb"
                color: Theme.cyan
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
            }
            MouseArea {
                id: dropperHit
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: dropper.running = true
            }
        }
    }

    Process {
        id: dropper
        command: ["hyprpicker", "-f", "hex", "-b", "-q"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim()
                if (t.length === 7 && t[0] === "#")
                    root.set(root.alphaEnabled ? Qt.rgba(Qt.color(t).r, Qt.color(t).g, Qt.color(t).b, root.a) : t)
            }
        }
    }

    // Vertical bar, value 0 at the top
    component Bar: Item {
        id: bar
        property real value: 0
        property Gradient fill
        signal moved(real x)
        Layout.preferredWidth: 18
        Layout.preferredHeight: 170

        Rectangle {
            anchors.fill: parent
            gradient: bar.fill
            border.color: CP.alpha(Theme.cyan, 0.5)
        }
        Rectangle {
            x: -3
            y: bar.value * bar.height - 2
            width: bar.width + 6
            height: 4
            color: "white"
            border.color: "black"
        }
        MouseArea {
            anchors.fill: parent
            preventStealing: true
            function pick(m) { bar.moved(Math.max(0, Math.min(1, m.y / height))) }
            onPressed: m => pick(m)
            onPositionChanged: m => { if (pressed) pick(m) }
        }
    }

    component Field: Item {
        id: field
        property string label
        property string text
        signal committed(string t)
        implicitHeight: 28

        CutShape {
            anchors.fill: parent
            cutBottomRight: 7
            strokeColor: input.activeFocus ? Theme.cyan : CP.alpha(Theme.cyan, 0.5)
            inset: 0.5
        }
        Text {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            text: field.label
            color: CP.alpha(Theme.cyan, 0.7)
            font { family: Theme.font; pixelSize: 10 }
        }
        TextInput {
            id: input
            x: 20
            width: parent.width - 26
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            selectByMouse: true
            color: "#e6f7ff"
            font { family: Theme.font; pixelSize: 12 }
            // Follows the color unless it's being typed into
            Binding on text { value: field.text; when: !input.activeFocus }
            onEditingFinished: field.committed(text)
        }
    }
}
