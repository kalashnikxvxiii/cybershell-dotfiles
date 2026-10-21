// GlitchReveal.qml — glitchy pop-in / pop-out wrapper, ported from
// AndreaNec/Cyberpunk-quickshell (GlitchReveal.qml). Steps on the FrameClock
// (~33 ms a step) instead of its own 28 ms Timer.
import QtQuick

Item {
    id: root

    property bool shown: false
    property real intensity: 14      // max horizontal jitter in px
    property int frames: 9           // number of glitch steps

    default property alias content: holder.data

    property int _frame: 0
    property bool _running: false

    // stays visible until the exit glitch has finished
    visible: shown || _running

    onShownChanged: {
        _frame = 0
        _running = true
    }

    Item {
        id: holder
        anchors.fill: parent
        opacity: root.shown ? 1 : 0

        transform: [
            Translate { id: tr },
            Scale {
                id: sc
                origin.x: holder.width / 2
                origin.y: holder.height / 2
            }
        ]
    }

    Ticker {
        running: root._running
        onTicked: {
            root._frame++
            if (root._frame >= root.frames) {
                root._running = false
                tr.x = 0
                sc.xScale = 1
                sc.yScale = 1
                holder.opacity = root.shown ? 1 : 0
                return
            }

            const p = root._frame / root.frames      // 0 -> 1
            const k = root.shown ? 1 - p : p         // glitch strength
            const r = () => Math.random() * 2 - 1    // -1 .. 1

            tr.x = r() * root.intensity * k
            sc.xScale = 1 + r() * 0.08 * k
            sc.yScale = Math.random() < k * 0.5 ? 0.02 + Math.random() * 0.3 : 1 // occasional squash

            // flicker; fully gone by the last frames when hiding
            if (root.shown)
                holder.opacity = Math.random() > k * 0.6 ? 1 : 0.15
            else
                holder.opacity = Math.random() > k * 0.9 ? 1 : 0.1
        }
    }
}
