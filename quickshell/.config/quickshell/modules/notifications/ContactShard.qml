// ContactShard.qml -- the contact's data shard, turned away from the viewer. Shows a picture or
// a generic glyph; "ghost" leaves just the slab, for the ones stacked behind it.
import QtQuick
import "../../common"

Item {
    id: root

    property string picture: ""
    property bool ghost: false

    width: 62
    height: 84
    // Narrowed and sheared rather than rotated, so its long sides stay parallel
    transform: Matrix4x4 {
        matrix: Qt.matrix4x4(0.64, 0, 0, 0,
                             0.36, 1, 0, 0,
                             0, 0, 1, 0,
                             0, 0, 0, 1)
    }

    CutShape {
        anchors.fill: parent
        cutBottomRight: 7
        fillColor: HudState.alpha(HudState.danger, 0.5)
        strokeColor: HudState.danger
        strokeWidth: 1.5
        inset: 0.75
    }
    // Ridge along the top, sticking out on the far side
    Rectangle {
        x: 3
        y: 4
        width: parent.width + 1
        height: 2
        color: HudState.danger
    }
    Rectangle {
        x: 3
        y: 8
        width: parent.width + 1
        height: 1
        color: HudState.danger
    }
    Rectangle {
        visible: !root.ghost
        x: 6
        y: 13
        width: 50
        height: 63
        color: HudState.alpha("#00060e", 0.35)

        Image {
            id: avatar
            anchors.fill: parent
            source: root.ghost ? "" : root.picture
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(100, 126)
            visible: status === Image.Ready
        }
        Text {
            anchors.centerIn: parent
            visible: !avatar.visible
            text: ""
            color: HudState.alpha(HudState.paper, 0.55)
            font { family: HudState.icons; pixelSize: 34 }
        }
    }
}
