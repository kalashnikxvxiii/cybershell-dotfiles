// RadioportHeader.qml -- a Radioport panel's title strip: code above, a thick band beside
// a dark frame with its corner cut.
import QtQuick
import "../../common/Colors.js" as CP
import "../../common"

Item {
    id: root

    property string code
    property string title
    // Overrides the frame's color during a glitch
    property color tint: "transparent"
    property alias titleShift: shift
    default property alias content: slot.data

    height: 52

    Text {
        text: root.code
        color: CP.alpha(Theme.red, 0.7)
        font { family: Theme.font; pixelSize: 10; letterSpacing: 1 }
    }
    CutShape {
        y: 18
        width: 8
        height: 34
        cutTopLeft: 2
        cutBottomLeft: 2
        fillColor: CP.alpha(Theme.red, 0.75)
    }
    CutShape {
        x: 10
        y: 18
        width: root.width - 10
        height: 34
        cutBottomRight: 10
        fillColor: Qt.rgba(0.07, 0.02, 0.05, 0.75)
        strokeColor: root.tint.a > 0 ? root.tint : CP.alpha(Theme.red, 0.8)
        inset: 0.5
    }
    Text {
        x: 26
        y: 18
        height: 34
        verticalAlignment: Text.AlignVCenter
        text: root.title
        color: Theme.cyan
        transform: Translate { id: shift }
        font { family: Theme.font; pixelSize: 19; letterSpacing: 1 }
    }
    Item {
        id: slot
        x: 10
        y: 18
        width: root.width - 10
        height: 34
    }
}
