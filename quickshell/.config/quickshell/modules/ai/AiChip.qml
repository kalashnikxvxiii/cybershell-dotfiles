// AiChip.qml — the pill the composer toolbar is made of.
//
// Cursor keeps every chat control in one row under the input instead of a
// header, so the transcript gets the full width of the panel. This is that row's
// unit: model, timing, cost, and the actions that used to sit in the header.
import QtQuick
import "../../common"
import "../../common/Colors.js" as CP

Item {
    id: root

    property string label: ""
    property string glyph: ""       // optional leading mark
    property int    glyphSize: 9
    property color  accent: CP.cyan
    property bool   interactive: true
    property bool   enabled: true
    property bool   filled: false   // solid, for the primary action
    property bool   frame: true     // the outline; the hover plate stays either way

    signal triggered()

    implicitWidth: row.implicitWidth + 14
    implicitHeight: 18
    width: implicitWidth
    height: implicitHeight
    opacity: root.enabled ? 1 : 0.3
    Behavior on opacity { NumberAnimation { duration: 120 } }

    CutShape {
        anchors.fill: parent
        fillColor: root.filled
            ? CP.alpha(root.accent, ma.containsMouse ? 0.32 : 0.18)
            : (ma.containsMouse ? CP.alpha(root.accent, 0.12) : "transparent")
        strokeColor: root.frame
            ? CP.alpha(root.accent, ma.containsMouse ? 0.70 : 0.32)
            : "transparent"
        strokeWidth: 1
        inset: 0.5
        cutBottomLeft: 6
        Behavior on fillColor { ColorAnimation { duration: 120 } }
        Behavior on strokeColor { ColorAnimation { duration: 120 } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            visible: root.glyph !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: root.glyphSize
            color: CP.alpha(root.accent, 0.8)
        }

        // A glyph-only chip has no label: an empty Text would still take
        // the row's spacing and push the glyph off centre
        Text {
            visible: root.label !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font.family: "Oxanium"
            font.pixelSize: 9
            font.letterSpacing: 1.2
            color: (ma.containsMouse && root.interactive)
                ? root.accent : CP.alpha(root.accent, 0.58)
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: root.interactive
        enabled: root.interactive && root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggered()
    }
}
