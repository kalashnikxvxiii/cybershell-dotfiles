// HudGhosts.qml -- two fainter copies of `target`, a step apart toward the desktop's edge, along
// the line that leaves the desktop's center and passes through the target (the same ghosts that
// HudCornerDock and HudUpdates draw by hand). Declare it before the target, in the same tilted
// plane, so the ghosts stay behind. `ghost` draws one copy at the target's size; without it the
// target is copied as it is, colors and all.
pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root

    required property Item target
    property Component ghost: null

    // Room around the target for two steps, flat at twice the size like HudPlate
    readonly property real pad: 20
    property point step: Qt.point(0, 0)
    // The desktop's center in the window's coordinates, for windows smaller than the screen
    property point center: Qt.point(NaN, NaN)
    onCenterChanged: root.aim()

    function aim() {
        if (!root.target || !root.parent)
            return
        let d = root
        while (d.parent)
            d = d.parent
        const o = root.target.mapToItem(root.parent, 0, 0)
        root.x = o.x - root.pad
        root.y = o.y - root.pad
        const cx = root.target.width / 2, cy = root.target.height / 2
        const c = root.target.mapToItem(d, cx, cy)
        const mx = isNaN(root.center.x) ? d.width / 2 : root.center.x
        const my = isNaN(root.center.y) ? d.height / 2 : root.center.y
        const dx = c.x - mx, dy = c.y - my
        const len = Math.hypot(dx, dy) || 1
        const end = root.target.mapFromItem(d, c.x + dx / len * 8, c.y + dy / len * 8)
        root.step = Qt.point(end.x - cx, end.y - cy)
    }

    width: root.target.width + root.pad * 2
    height: root.target.height + root.pad * 2

    layer.enabled: true
    layer.smooth: true
    layer.textureSize: Qt.size(width * 2, height * 2)

    // Anchors place the target and its ancestors late (a frame anchored right moves once the
    // window has its size): re-aim whenever any of them moves or resizes
    property var _watched: []
    function watch() {
        for (let a = root.target; a; a = a.parent) {
            if (root._watched.indexOf(a) >= 0)
                continue
            a.xChanged.connect(root.aim)
            a.yChanged.connect(root.aim)
            a.widthChanged.connect(root.aim)
            a.heightChanged.connect(root.aim)
            root._watched.push(a)
        }
    }

    Component.onCompleted: {
        root.watch()
        Qt.callLater(root.aim)
    }

    // Fainter the further out
    Repeater {
        model: 2
        Item {
            id: copy
            required property int index
            x: root.pad + root.step.x * (copy.index + 1)
            y: root.pad + root.step.y * (copy.index + 1)
            z: -copy.index
            width: root.target.width
            height: root.target.height
            opacity: 0.4 - copy.index * 0.2

            Loader {
                anchors.fill: parent
                active: root.ghost !== null
                sourceComponent: root.ghost
            }
            ShaderEffectSource {
                anchors.fill: parent
                visible: root.ghost === null
                sourceItem: visible ? root.target : null
                textureSize: Qt.size(width * 2, height * 2)
                smooth: true
            }
        }
    }
}
