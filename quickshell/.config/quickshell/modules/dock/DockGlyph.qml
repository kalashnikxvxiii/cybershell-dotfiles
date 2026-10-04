// DockGlyph.qml - vector dock icons.
//
// The bar uses geometric Unicode glyphs because it has 24px of room; the dock
// has a whole bulge, so the icons are drawn instead. Everything is authored on a
// 24x24 grid and scaled, so one number controls the size and the stroke stays
// proportional. MiterJoin + FlatCap keep the 90-degree/diagonal language: no
// rounded line ends anywhere
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    required property string iconId
    property color color: "#ffffff"
    property real strokeWidth: 1.7
    property real iconSize: 22

    implicitWidth: root.iconSize
    implicitHeight: root.iconSize

    // Outline subpaths and solid subpaths, concatenated: PathSvg takes several
    // "M" segments in one string, so each icon needs only two ShapePaths
    // regardless of how many strokes it is made of
    readonly property var art: ({
        // Netrunner: nested diamonds, a signal propagating out of a node
        "ai": {
            stroke: "M12 1.6 L22.4 12 L12 22.4 L1.6 12 Z"
                + " M12 6.2 L17.8 12 L12 17.8 L6.2 12 Z",
            fill: "M12 9.9 L14.1 12 L12 14.1 L9.9 12 Z"
        },
        // Wallpaper: notched frame, horizon line, sun
        "wallpaper": {
            stroke: "M3.4 5.2 H16.8 L20.6 9 V18.8 H3.4 Z"
                + " M16.8 5.2 V9 H20.6"
                + " M5.6 16.4 L9.8 10.8 L12.9 14.4 L15.1 11.5 L18.4 15.8",
            fill: "M7.8 7.2 L9.3 8.7 L7.8 10.2 L6.3 8.7 Z"
        },
        // Sonar: three sweeps out of an emitter in the corner
        "sonar": {
            stroke: "M10.4 19.4 A 5.4 5.4 0 0 0 5 14"
                + " M15 19.4 A 10 10 0 0 0 5 9.4"
                + " M19.6 19.4 A 14.6 14.6 0 0 0 5 4.8",
            fill: "M5 17.6 L6.8 19.4 L5 21.2 L3.2 19.4 Z"
        },
        // Manga: open volume seen from the spine, with a clasp
        "manga": {
            stroke: "M11.4 6.8 L3.4 4.2 V18.4 L11.4 21 Z"
                + " M12.6 6.8 L20.6 4.2 V18.4 L12.6 21 Z",
            fill: "M12 3.1 L13.3 4.4 L12 5.7 L10.7 4.4 Z"
        }
    })

    readonly property var shape: root.art[root.iconId] ?? root.art["ai"]

    Shape {
        width: 24
        height: 24
        anchors.centerIn: parent
        scale: root.iconSize / 24
        preferredRendererType: Shape.CurveRenderer
        asynchronous: false

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            joinStyle: ShapePath.MiterJoin
            capStyle: ShapePath.FlatCap
            PathSvg { path: root.shape.stroke }
        }

        ShapePath {
            fillColor: root.color
            strokeWidth: -1
            PathSvg { path: root.shape.fill }
        }
    }
}