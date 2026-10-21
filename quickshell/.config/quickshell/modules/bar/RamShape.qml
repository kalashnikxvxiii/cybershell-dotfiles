// RamShape.qml — workspace tile outline, ported from AndreaNec/Cyberpunk-quickshell
// (stats/RamShape.qml). Same profile: bottom-right chamfer and a stepped notch
// on the lower left edge. Details rescaled for the 24px bar; width is free so
// the tile can hold app icons.

import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property color color: "#00ffd2"
    property bool filled: true
    property real strokeWidth: 1

    property real chamfer: 4          // bottom-right diagonal
    property real notchW: 2           // how far the left step goes in
    property real stepFromBottom: height * 0.5
    property real footH: 2            // vertical part at the bottom-left
    property real leadH: 1            // small diagonal lead-in
    property real foot: 0.5           // inset of the bottom-left foot

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.filled ? root.color : "transparent"
            strokeColor: root.strokeWidth > 0 ? root.color : "transparent"
            strokeWidth: root.strokeWidth
            joinStyle: ShapePath.MiterJoin

            startX: 0
            startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height - root.chamfer }
            PathLine { x: root.width - root.chamfer; y: root.height }
            PathLine { x: root.foot; y: root.height }
            PathLine { x: root.foot; y: root.height - root.footH }
            PathLine { x: root.notchW; y: root.height - root.footH - root.leadH }
            PathLine { x: root.notchW; y: root.height - root.stepFromBottom }
            PathLine { x: 0; y: root.height - root.stepFromBottom }
            PathLine { x: 0; y: 0 }
        }
    }
}
