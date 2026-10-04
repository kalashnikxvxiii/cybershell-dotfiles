// AiIconButton.qml - the square glyph button of the composer rail: attach,
// dictate, command palette. Same 120ms hover as the rest of the system.
import QtQuick
import "../../common"
import "../../common/Colors.js" as CP

Item {
    id: root

    property string glyph: ""
    property color accent: CP.magenta
    property bool on: false         // latched, e.g. while the mic is recording
    property bool busy: false       // working, e.g. while transcribing
    // Bare mode: no frame, no fill, just the glyph. For a button that sits
    // INSIDE another surface, where a second outline would read as nested box
    property bool frame: true
    property int glyphSize: 10

    signal triggered()

    implicitWidth: 18
    implicitHeight: 18
    width: implicitWidth
    height: implicitHeight
    opacity: root.enabled ? 1 : 0.3
    Behavior on opacity { NumberAnimation { duration: 120 } }

    readonly property color live: root.on ? CP.red : root.accent

    CutShape {
        anchors.fill: parent
        fillColor: root.on ? CP.alpha(CP.red, 0.18)
            : (ma.containsMouse ? CP.alpha(root.accent, 0.12) : "transparent")
        strokeColor: root.frame
            ? CP.alpha(root.live, (root.on || ma.containsMouse) ? 0.70 : 0.30)
            : "transparent"
        strokeWidth: 1
        inset: 0.5
        cutBottomLeft: 6
        Behavior on fillColor { ColorAnimation { duration: 120 } }
        Behavior on strokeColor { ColorAnimation { duration: 120 } }
    }

    // The pulse drives a plain number, not `opacity` directly: an animation
    // written ON a property leaves it stuck at its last value when it stops
    QtObject { id: pulse; property real k: 1 }

    SequentialAnimation {
        running: root.on || root.busy
        loops: Animation.Infinite
        onStopped: pulse.k = 1
        NumberAnimation { target: pulse; property: "k"; from: 1.0; to: 0.35; duration: 520 }
        NumberAnimation { target: pulse; property: "k"; from: 0.35; to: 1.0; duration: 520 }
    }

    Text {
        anchors.centerIn: parent
        text: root.glyph
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: root.glyphSize
        opacity: pulse.k
        color: (ma.containsMouse || root.on) ? root.live : CP.alpha(root.live, 0.60)
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggered()
    }
}
