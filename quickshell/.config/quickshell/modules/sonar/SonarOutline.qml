// SonarOutline.qml -- the Sonar's frame, closed or open: the minimap's stepped left edge
// and a small cut at the bottom left.
import QtQuick
import QtQuick.Shapes

Shape {
    id: root

    property color fillColor: "transparent"
    property color strokeColor: "transparent"

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: root.fillColor
        strokeColor: root.strokeColor
        strokeWidth: 1
        joinStyle: ShapePath.MiterJoin
        PathPolyline {
            path: {
                const i = 0.5, r = root.width - i, b = root.height - i
                const top = i + 3, mid = i + 7, cut = 8
                const step1 = 34, step2 = root.height - 50
                return [
                    Qt.point(top, i), Qt.point(r, i), Qt.point(r, b),
                    Qt.point(i + cut, b), Qt.point(i, b - cut),
                    Qt.point(i, step2), Qt.point(mid, step2 - 6),
                    Qt.point(mid, step1 + 4), Qt.point(top, step1), Qt.point(top, i)
                ]
            }
        }
    }
}
