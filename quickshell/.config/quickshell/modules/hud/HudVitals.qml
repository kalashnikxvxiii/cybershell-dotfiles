// HudVitals.qml -- top left: workspace badge, disk, CPU, RAM chips, GPU.
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell.Hyprland
import "../../common"

Item {
    id: root

    required property var screen

    // split-monitor-workspaces numbers each monitor's slots in blocks of ten
    readonly property int wsId: Hyprland.monitorFor(root.screen)?.activeWorkspace?.id ?? 1
    readonly property real memFrac: HudState.memUsedGb / HudState.memTotalGb

    // 20px of margin all around the content, for the glows and the ghosts
    width: 510
    height: 136
    transform: Tilt { w: root.width; h: root.height; yaw: 24; pitch: 5; roll: 3; focal: 2100 }

    // Flat at twice the size, then tilted as one texture (see HudPlate)
    layer.enabled: true
    layer.smooth: true
    layer.textureSize: Qt.size(root.width * 2, root.height * 2)
    layer.effect: DarkHalo {}

    // Its content with a neon halo of its own color
    component Glow: Item {
        id: halo
        property color glow
        layer.enabled: true
        layer.textureSize: Qt.size(width * 2, height * 2)
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: halo.glow
            shadowBlur: 0.5
            blurMax: 12
            shadowOpacity: 0.7
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            autoPaddingEnabled: true
        }
    }

    // A filled polygon, in the item's own pixels
    component Poly: Shape {
        id: poly
        property var points: []
        property color fill
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillColor: poly.fill
            PathPolyline { path: poly.points.map(p => Qt.point(p[0], p[1])) }
        }
    }

    HudGhosts {
        target: shapes
    }

    // The shapes, which the ghosts repeat
    Item {
        id: shapes
        x: 20
        y: 20
        width: 470
        height: 96

        CutShape {
            y: 2
            width: 38
            height: 44
            cutBottomLeft: 14
            fillColor: HudState.alpha(HudState.tech, 0.06)
            strokeColor: HudState.tech
            strokeWidth: 1.5
            inset: 1

            Text {
                anchors.centerIn: parent
                text: ((root.wsId - 1) % 10) + 1
                color: HudState.tech
                font { family: HudState.font; pixelSize: 17; bold: true }
            }
        }

        // Disk: the thin "experience" bar, as long as the CPU's
        Rectangle {
            x: 50
            y: 3
            width: 345
            height: 4
            color: HudState.track(HudState.tech)
        }
        Glow {
            x: 50
            y: 3
            glow: HudState.tech
            width: 345 * HudState.diskUsedGb / HudState.diskTotalGb
            height: 4
            Rectangle {
                anchors.fill: parent
                color: HudState.tech
            }
        }

        // CPU: the health bar, its far corner cut
        Item {
            id: cpu
            x: 50
            y: 10
            width: 345
            height: 20

            readonly property real cut: 12
            readonly property real fillTo: cpu.width * HudState.cpu

            Poly {
                anchors.fill: parent
                fill: HudState.track(HudState.danger)
                points: [[0, 0], [cpu.width, 0], [cpu.width, cpu.height - cpu.cut], [cpu.width - cpu.cut, cpu.height], [0, cpu.height], [0, 0]]
            }
            Glow {
                anchors.fill: parent
                glow: HudState.danger
                Poly {
                    anchors.fill: parent
                    fill: HudState.alpha(HudState.danger, 0.85)
                    // Past the start of the cut the bar's end follows it
                    points: {
                        const x = cpu.fillTo, over = Math.max(0, x - (cpu.width - cpu.cut))
                        return [[0, 0], [x, 0], [x, cpu.height - over], [x - over, cpu.height], [0, cpu.height], [0, 0]]
                    }
                }
            }
        }

        // RAM: a row of chips, lit in proportion
        Row {
            x: 50
            y: 33
            spacing: 2
            Repeater {
                model: 14
                Glow {
                    id: chip
                    required property int index
                    readonly property bool lit: chip.index < Math.round(root.memFrac * 14)
                    width: 9
                    height: 16
                    glow: chip.lit ? HudState.mem : "transparent"
                    Poly {
                        anchors.fill: parent
                        fill: chip.lit ? HudState.mem : HudState.track(HudState.mem)
                        points: [[0, 0], [9, 0], [9, 13], [6, 16], [3, 16], [3, 8], [0, 6], [0, 0]]
                    }
                }
            }
        }

        // GPU takes the stamina bar: this machine has no battery
        Text {
            x: 8
            y: 57
            text: "\uf0e7"
            color: HudState.ok
            font { family: HudState.icons; pixelSize: 11 }
        }
        Item {
            id: gpu
            x: 22
            y: 58
            width: 400
            height: 8

            readonly property real slant: 4
            readonly property real fillTo: gpu.slant + (gpu.width - gpu.slant) * HudState.gpu

            Poly {
                anchors.fill: parent
                fill: HudState.track(HudState.ok)
                points: [[0, 0], [gpu.width, 0], [gpu.width, gpu.height], [gpu.slant, gpu.height], [0, 0]]
            }
            Glow {
                anchors.fill: parent
                glow: HudState.ok
                Poly {
                    anchors.fill: parent
                    fill: HudState.alpha(HudState.ok, 0.85)
                    points: [[0, 0], [gpu.fillTo, 0], [gpu.fillTo, gpu.height], [gpu.slant, gpu.height], [0, 0]]
                }
            }
        }
    }

    // The writing, with ghosts of its own
    HudGhosts {
        target: writing
    }

    Item {
        id: writing
        x: 20
        y: 20
        width: 470
        height: 96

        // Disk figures and CPU percentage
        Text {
            x: 405
            y: 3
            text: HudState.diskUsedGb.toFixed(0) + "/" + HudState.diskTotalGb.toFixed(0)
            color: HudState.tech
            font { family: HudState.font; pixelSize: 9 }
        }
        Text {
            x: 405
            y: 15
            text: Math.round(HudState.cpu * 100) + "%"
            color: HudState.dangerSoft
            font { family: HudState.font; pixelSize: 27; bold: true }
        }
        Text {
            x: 216
            y: 35
            text: HudState.memUsedGb.toFixed(1) + " / " + HudState.memTotalGb.toFixed(0) + " GB"
            color: HudState.mem
            font { family: HudState.font; pixelSize: 12; bold: true }
        }
        Text {
            x: 422 - width
            y: 68
            text: "GPU " + Math.round(HudState.gpu * 100) + "%  " + HudState.gpuTemp + "\u00b0"
            color: HudState.ok
            font { family: HudState.font; pixelSize: 10 }
        }
    }
}
