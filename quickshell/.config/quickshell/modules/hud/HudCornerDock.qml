// HudCornerDock.qml -- bottom left: the tilted cluster of shortcuts, laid out like the
// in-game quick slots: two small ones stacked, two big ones side by side.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Pipewire
import "../../common"

Item {
    id: root

    required property var screen

    readonly property alias row: row

    anchors.fill: parent

    // PulseModule tracks it too, but only as long as the bar is up
    PwObjectTracker { objects: [Pipewire.preferredDefaultAudioSink] }
    readonly property var sink: Pipewire.preferredDefaultAudioSink

    function run(id) {
        switch (id) {
            case "audio": AudioControlState.requestToggle(root.screen.name); break
            case "night": Quickshell.execDetached(["sh", "-c", "pgrep hyprsunset && pkill hyprsunset || hyprsunset -t 4500"]); break
            case "notif": NotifState.togglePanel(); break
            case "media": LauncherState.toggleMedia(); break
        }
    }

    // Outlines, as fractions of the tile's side: the outer edge and the dark panel inside it
    readonly property var smallOuter: [[.10, .02], [.33, .02], [.36, .05], [1, .05], [1, .82], [.82, 1], [.12, 1], [0, .88], [0, .12], [.10, .02]]
    readonly property var smallInner: [[.08, .16], [.50, .16], [.57, .08], [.93, .08], [.93, .78], [.78, .93], [.14, .93], [.08, .87], [.08, .16]]
    readonly property var bigOuter: [[.12, 0], [.82, 0], [1, .18], [1, .95], [.95, 1], [.07, 1], [0, .94], [0, .10], [.12, 0]]
    readonly property var bigInner: [[.12, .10], [.80, .10], [.90, .20], [.92, .92], [.18, .92], [.06, .78], [.12, .72], [.12, .10]]

    component Slot: Shape {
        id: slot
        property var outer: []
        property var inner: []
        property color stroke
        property color panel
        preferredRendererType: Shape.CurveRenderer

        function scaled(points) {
            return points.map(p => Qt.point(p[0] * (slot.width - 1) + 0.5, p[1] * (slot.height - 1) + 0.5))
        }

        ShapePath {
            strokeColor: slot.stroke
            strokeWidth: 1
            fillColor: Qt.rgba(slot.stroke.r, slot.stroke.g, slot.stroke.b, 0.28)
            joinStyle: ShapePath.MiterJoin
            PathPolyline { path: slot.scaled(slot.outer) }
        }
        ShapePath {
            strokeColor: Qt.rgba(slot.stroke.r, slot.stroke.g, slot.stroke.b, 0.45)
            strokeWidth: 1
            fillColor: slot.panel
            joinStyle: ShapePath.MiterJoin
            PathPolyline { path: slot.scaled(slot.inner) }
        }
    }

    // A font glyph, or the radioport's equalizer bars when there is none
    component Glyph: Item {
        id: mark
        property string glyph: ""
        property color color
        property real side: 38
        width: mark.side
        height: mark.side

        Text {
            anchors.centerIn: parent
            visible: mark.glyph !== ""
            text: mark.glyph
            color: mark.color
            font { family: HudState.icons; pixelSize: Math.round(mark.side * 0.42) }
        }
        Row {
            anchors.centerIn: parent
            visible: mark.glyph === ""
            spacing: Math.max(1, Math.round(mark.side * 0.05))
            Repeater {
                model: [0.4, 0.5, 0.18, 0.3]
                Rectangle {
                    required property real modelData
                    anchors.bottom: parent.bottom
                    width: Math.round(mark.side * 0.09)
                    height: Math.round(mark.side * modelData)
                    color: mark.color
                }
            }
            height: Math.round(mark.side * 0.5)
        }
    }

    component Tile: Item {
        id: tile
        property string glyph: ""
        property string action: ""
        readonly property bool big: width > 40
        readonly property var outer: big ? root.bigOuter : root.smallOuter
        readonly property var inner: big ? root.bigInner : root.smallInner

        // One ghost's step, in this tile's own tilted plane: along the line that leaves
        // the desktop's center and passes through the tile
        property point step: Qt.point(0, 0)

        function aim() {
            const cx = tile.width / 2, cy = tile.height / 2
            const c = tile.mapToItem(root, cx, cy)
            const dx = c.x - root.width / 2, dy = c.y - root.height / 2
            const len = Math.hypot(dx, dy) || 1
            const end = tile.mapFromItem(root, c.x + dx / len * 8, c.y + dy / len * 8)
            tile.step = Qt.point(end.x - cx, end.y - cy)
        }
        Component.onCompleted: Qt.callLater(tile.aim)
        Connections {
            target: root
            function onWidthChanged() { tile.aim() }
            function onHeightChanged() { tile.aim() }
        }

        // Ghosts, fainter the further out
        Repeater {
            model: 2
            Item {
                required property int index
                x: tile.step.x * (index + 1)
                y: tile.step.y * (index + 1)
                width: tile.width
                height: tile.height
                z: -index
                opacity: 0.4 - index * 0.2

                Slot {
                    anchors.fill: parent
                    outer: tile.outer
                    inner: tile.inner
                    stroke: HudState.tech
                    panel: "transparent"
                }
                Glyph {
                    glyph: tile.glyph
                    color: HudState.tech
                    side: tile.width
                }
            }
        }

        Slot {
            anchors.fill: parent
            outer: tile.outer
            inner: tile.inner
            // Opaque, or the ghosts would show through the tile
            panel: Qt.tint("#030a0e", HudState.alpha(HudState.tech, area.containsMouse ? 0.3 : 0.06))
            stroke: tileGlitch.running ? tint.color : HudState.tech
        }
        // GlitchAnim writes colors imperatively: into this holder, not into a binding
        QtObject {
            id: tint
            property color color: HudState.wallust
        }
        Glyph {
            glyph: tile.glyph
            color: tileGlitch.running ? tint.color : HudState.wallust
            side: tile.width
            transform: Translate { id: glyphShift }
        }
        GlitchAnim {
            id: tileGlitch
            labelTarget: tint
            shiftTarget: glyphShift
            baseColor: HudState.wallust
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.run(tile.action)
            onContainsMouseChanged: if (containsMouse) tileGlitch.restart()
        }

        // The volume's number, across the bottom edge
        Rectangle {
            visible: tile.action === "audio"
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - 9
            width: volume.implicitWidth + 8
            height: 15
            color: "#030a0e"
            border.color: HudState.paper
            Text {
                id: volume
                anchors.centerIn: parent
                text: root.sink?.audio?.muted ? "M" : Math.round((root.sink?.audio?.volume ?? 0) * 100)
                color: HudState.paper
                font { family: HudState.font; pixelSize: 10; bold: true }
            }
        }
    }

    Item {
        id: row
        // 20px of margin all around, for the ghosts
        x: -4
        y: parent.height - height - 4
        width: 204
        height: 121
        transform: Tilt { w: row.width; h: row.height; yaw: 12; pitch: -12; roll: -2; focal: 1050 }

        // Flat at twice the size, then tilted as one texture (see HudPlate)
        layer.enabled: true
        layer.smooth: true
        layer.textureSize: Qt.size(width * 2, height * 2)

        // Each tile above the next, so the ghosts going left stay behind their neighbour
        Repeater {
            model: [
                ["\uf10b", "notif", 20, 20, 38],
                ["", "media", 20, 63, 38],
                ["\uf185", "night", 76, 49, 52],
                ["\uf028", "audio", 132, 49, 52]
            ]
            Tile {
                required property var modelData
                required property int index
                glyph: modelData[0]
                action: modelData[1]
                x: modelData[2]
                y: modelData[3]
                width: modelData[4]
                height: modelData[4]
                z: 4 - index
            }
        }
    }
}
