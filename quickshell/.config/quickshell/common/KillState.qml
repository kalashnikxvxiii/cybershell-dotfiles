pragma Singleton
// KillState.qml -- kill mode: the windows that can be picked, and the kill itself.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool open: false
    property var clients: []

    function start() {
        if (root.open)
            return
        reader.running = true
    }

    function stop() {
        root.open = false
    }

    // What is on top under a point: floating windows first, then the most recently focused
    function windowAt(monitor, x, y) {
        const hits = root.clients.filter(c => c.monitor === monitor && x >= c.x && x < c.x + c.w && y >= c.y && y < c.y + c.h)
        hits.sort((a, b) => (b.floating - a.floating) || (a.focus - b.focus))
        return hits.length > 0 ? hits[0] : null
    }

    function kill(client) {
        Sounds.play("kill", "kill.ogg")
        HL.dispatch('hl.dsp.window.kill({ window = "address:' + client.address + '" })')
        root.stop()
    }

    Process {
        id: reader
        command: ["sh", "-c", "echo \"$(hyprctl monitors -j)\" \"$(hyprctl clients -j)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                // Two arrays, one after the other
                const cut = text.indexOf("] [")
                const monitors = JSON.parse(text.slice(0, cut + 1))
                const clients = JSON.parse(text.slice(cut + 2))
                const shown = {}
                for (const m of monitors) {
                    shown[m.activeWorkspace.id] = m
                    if (m.specialWorkspace.id !== 0)
                        shown[m.specialWorkspace.id] = m
                }
                root.clients = clients.filter(c => c.mapped && !c.hidden && shown[c.workspace.id]).map(c => {
                    const m = shown[c.workspace.id]
                    return {
                        address: c.address,
                        monitor: m.name,
                        x: c.at[0] - m.x,
                        y: c.at[1] - m.y,
                        w: c.size[0],
                        h: c.size[1],
                        title: c.title,
                        cls: c.class,
                        pid: c.pid,
                        floating: c.floating ? 1 : 0,
                        focus: c.focusHistoryID
                    }
                })
                root.open = true
            }
        }
    }
}
