// HudStatusFrame.qml -- the tilted plane of the top right corner. The HUD and the
// Sonar card live on different surfaces: sharing this keeps them on the same plane.
import QtQuick
import "../../common"

Item {
    anchors.right: parent.right
    anchors.rightMargin: 14
    y: 50
    width: 330
    height: 340
    transform: Tilt { w: 330; h: 340; yaw: -16; pitch: 1; roll: -1.5; focal: 2600 }
}
