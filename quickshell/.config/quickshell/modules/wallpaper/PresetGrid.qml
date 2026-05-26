import "../../common/Colors.js" as CP
import "../../common"
import "BezierPresets.js" as Presets
import QtQuick

Item {
    id: root

    property string currentBezier: ""
    signal presetSelected(string bezierString)

    readonly property var allPresets: {
        var combined = []
        for (var i = 0; i < Presets.PRESETS.length; i++) {
            var p = Presets.PRESETS[i]
            combined.push({ name: p.name, x1: p.x1, y1: p.y1, x2: p.x2, y2: p.y2, isUser: false })
        }
        for (var j = 0; j < TransitionConfig.userPresets.length; j++) {
            var up = TransitionConfig.userPresets[j]
            combined.push({ name: up.name, x1: up.x1, y1: up.y1, x2: up.x2, y2: up.y2, isUser: true })
        }
        return combined
    }

    implicitHeight: flow.implicitHeight

    Flow {
        id: flow
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 6

        Repeater {
            model: root.allPresets
            delegate: Item {
                id: chip
                required property var modelData
                readonly property bool selectedActive:
                    Presets.tolerantMatch(root.currentBezier, modelData)
                readonly property bool _isUser: modelData.isUser

                property bool pendingDelete: false

                Timer {
                    id: deleteTimer
                    interval: 2500
                    repeat: false
                    onTriggered: chip.pendingDelete = false
                }

                width: (flow.width - flow.spacing * 2) / 3
                height: 32

                CutShape {
                    anchors.fill: parent
                    fillColor: chip.selectedActive
                        ? CP.alpha(chip._isUser ? CP.neon : CP.cyan, 0.20)
                        : (ma.containsMouse
                            ? CP.alpha(chip._isUser ? CP.neon : CP.cyan, 0.10)
                            : CP.alpha(CP.void2, 0.55))
                    strokeColor: chip.selectedActive
                        ? (chip._isUser ? CP.neon : CP.cyan)
                        : CP.alpha(chip._isUser ? CP.neon : CP.cyan, 0.30)
                    strokeWidth: chip.selectedActive ? 1.5 : 1
                    inset: 0.5
                    cutTopLeft: 2
                    cutBottomRight: 2
                    Behavior on fillColor   { ColorAnimation { duration: 120 } }
                    Behavior on strokeColor { ColorAnimation { duration: 120 } }
                }

                // User-preset marker dot (top-left)
                Rectangle {
                    visible: chip._isUser
                    width: 4; height: 4
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 3
                    color: CP.neon
                }

                // Pulsing red overlay when in delete-confirm state
                CutShape {
                    id: pulseOverlay
                    anchors.fill: parent
                    visible: chip.pendingDelete
                    fillColor: CP.alpha(CP.red, 0.15)
                    strokeColor: CP.red
                    strokeWidth: 2
                    inset: 0.5
                    cutTopLeft: 2
                    cutBottomRight: 2

                    SequentialAnimation on opacity {
                        running: pulseOverlay.visible
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.35; duration: 250 }
                        NumberAnimation { from: 0.35; to: 1.0; duration: 250 }
                    }
                }

                Canvas {
                    id: mini
                    x: 5
                    y: 5
                    width: 22
                    height: 22
                    property color curveColor:
                        chip.selectedActive
                            ? (chip._isUser ? CP.neon : CP.cyan)
                            : CP.alpha(CP.yellow, 0.85)
                    onCurveColorChanged: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        var pad = 2
                        var w = width, h = height
                        var yMin = -0.6, yMax = 1.6
                        function tc(mx, my) {
                            var px = pad + mx * (w - 2*pad)
                            var yN = (my - yMin) / (yMax - yMin)
                            var py = pad + (1 - yN) * (h - 2*pad)
                            return [px, py]
                        }
                        var p0 = tc(0, 0), p3 = tc(1, 1)
                        var c1 = tc(chip.modelData.x1, chip.modelData.y1)
                        var c2 = tc(chip.modelData.x2, chip.modelData.y2)

                        ctx.strokeStyle = "rgba(252, 236, 12, 0.15)"
                        ctx.lineWidth = 1
                        ctx.strokeRect(pad, pad, w - 2*pad, h - 2*pad)

                        ctx.strokeStyle = mini.curveColor.toString()
                        ctx.lineWidth = 1.4
                        ctx.beginPath()
                        ctx.moveTo(p0[0], p0[1])
                        ctx.bezierCurveTo(c1[0], c1[1], c2[0], c2[1], p3[0], p3[1])
                        ctx.stroke()
                    }
                }

                Text {
                    anchors.left: mini.right
                    anchors.leftMargin: 5
                    anchors.right: deleteBtn.visible ? deleteBtn.left : parent.right
                    anchors.rightMargin: 5
                    anchors.verticalCenter: parent.verticalCenter
                    text: chip.modelData.name
                    elide: Text.ElideRight
                    font.family: "Oxanium"
                    font.pixelSize: 8
                    font.letterSpacing: 0.3
                    color: chip.selectedActive
                        ? (chip._isUser ? CP.neon : CP.cyan)
                        : Colours.textMuted
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (chip.pendingDelete) {
                            // Click on chip during pending -> cancel the confirmation
                            chip.pendigDelete = false
                            deleteTimer.stop()
                            return
                        }
                        root.presetSelected(
                            Presets.formatBezier(
                                chip.modelData.x1, chip.modelData.y1,
                                chip.modelData.x2, chip.modelData.y2))
                    }
                }

                // Delete X (only on user presets, on hover)
                Item {
                    id: deleteBtn
                    visible: chip._isUser && (ma.containsMouse || delMa.containsMouse)
                    width: 14; height: 14
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 4

                    CutShape {
                        anchors.fill: parent
                        fillColor: delMa.containsMouse ? CP.red : CP.alpha(CP.red, 0.75)
                        strokeColor: "white"
                        strokeWidth: 1
                        inset: 0.5
                        cutTopLeft: 2
                        cutBottomRight: 2
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 8
                        font.bold: true
                        color: "white"
                    }

                    MouseArea {
                        id: delMa
                        anchors.fill: parent
                        anchors.margins: -2
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (chip.pendingDelete) {
                                // Second click -> confirm delete
                                TransitionConfig.deleteUserPreset(chip.modelData.name)
                            } else {
                                // First click -> go in pending, start timer
                                chip.pendingDelete = true
                                deleteTimer.restart()
                            }
                        }
                    }
                }
            }
        }
    }
}
