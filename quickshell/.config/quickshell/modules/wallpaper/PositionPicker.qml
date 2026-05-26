import "../../common/Colors.js" as CP
import "../../common"
import QtQuick

Item {
    id: root

    property string pos: "center"
    signal posEdited(string newPos)

    property real _px: 0.5
    property real _py: 0.5

    onPosChanged: _parse()
    Component.onCompleted: _parse()

    function _parse() {
        if (pos === "center" || pos === "") {
            _px = 0.5; _py = 0.5
        } else {
            var p = pos.split(",")
            if (p.length === 2) {
                var x = parseFloat(p[0])
                var y = parseFloat(p[1])
                if (!isNaN(x) && !isNaN(y)) {
                    _px = Math.max(0, Math.min(1, x))
                    _py = Math.max(0, Math.min(1, y))
                }
            }
        }
        canvas.requestPaint()
    }

    function _emit() {
        canvas.requestPaint()
        root.posEdited(_px.toFixed(2) + "," + _py.toFixed(2))
    }

    implicitWidth: 200
    implicitHeight: 130

    Item {
        id: pickerArea
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.bottomMargin: 4

        CutShape {
            anchors.fill: parent
            fillColor: CP.alpha(CP.void2, 0.55)
            strokeColor: CP.alpha(CP.magenta, 0.45)
            strokeWidth: 1
            inset: 0.5
            cutTopLeft: 3
            cutBottomRight: 3
        }

        Canvas {
            id: canvas
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var pad = 4

                // 5x5 grid
                ctx.strokeStyle = "rgba(234, 0, 217, 0.10)"
                ctx.lineWidth = 1
                for (var i = 1; i < 5; i++) {
                    var x = pad + (i / 5) * (width - 2*pad)
                    var y = pad + (i / 5) * (height - 2*pad)
                    ctx.beginPath(); ctx.moveTo(x, pad); ctx.lineTo(x, height-pad); ctx.stroke()
                    ctx.beginPath(); ctx.moveTo(pad, y); ctx.lineTo(width-pad, y); ctx.stroke()
                }

                // Center reference
                var ccx = pad + 0.5 * (width - 2*pad)
                var ccy = pad + 0.5 * (height - 2*pad)
                ctx.strokeStyle = "rgba(234, 0, 217, 0.28)"
                ctx.lineWidth = 1
                ctx.beginPath(); ctx.moveTo(ccx - 5, ccy); ctx.lineTo(ccx + 5, ccy); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(ccx, ccy - 5); ctx.lineTo(ccx, ccy + 5); ctx.stroke()

                // Position
                var px = pad + root._px * (width - 2*pad)
                var py = pad + root._py * (height - 2*pad)

                // Crosshair dashed
                ctx.strokeStyle = "rgba(234, 0, 217, 0.42)"
                ctx.lineWidth = 1
                ctx.setLineDash([3, 3])
                ctx.beginPath(); ctx.moveTo(pad, py); ctx.lineTo(width-pad, py); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(px, pad); ctx.lineTo(px, height-pad); ctx.stroke()
                ctx.setLineDash([])

                // Marker (filled circle + glow)
                ctx.strokeStyle = "rgba(234, 0, 217, 0.40)"
                ctx.lineWidth = 4
                ctx.beginPath(); ctx.arc(px, py, 5, 0, 2 * Math.PI); ctx.stroke()

                ctx.fillStyle = "rgba(234, 0, 217, 1.0)"
                ctx.beginPath(); ctx.arc(px, py, 4, 0, 2 * Math.PI); ctx.fill()
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPressed: function(mouse) { _setXY(mouse.x, mouse.y) }
            onPositionChanged: function(mouse) {
                if (pressed) _setXY(mouse.x, mouse.y)
            }

            function _setXY(x, y) {
                var pad = 4
                var w = pickerArea.width - 2*pad
                var h = pickerArea.height - 2*pad
                root._px = Math.max(0, Math.min(1, (x - pad) / w))
                root._py = Math.max(0, Math.min(1, (y - pad) / h))
                root._emit()
            }
        }
    }

    Row {
        id: footer
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 12

        Text {
            text: "X " + root._px.toFixed(2)
            font.family: "Oxanium"
            font.pixelSize: 8
            font.letterSpacing: 1
            color: Colours.accentMem
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: "Y " + root._py.toFixed(2)
            font.family: "Oxanium"
            font.pixelSize: 8
            font.letterSpacing: 1
            color: Colours.accentMem
            anchors.verticalCenter: parent.verticalCenter
        }
        Item { width: 6; height: 1 }
        Item {
            width: 50; height: 18
            anchors.verticalCenter: parent.verticalCenter

            CutShape {
                anchors.fill: parent
                fillColor: resetPosMa.containsMouse
                        ? CP.alpha(CP.magenta, 0.25)
                        : CP.alpha(CP.magenta, 0.10)
                strokeColor: CP.alpha(CP.magenta, 0.6)
                strokeWidth: 1
                inset: 0.5
                cutTopLeft: 2
                cutBottomRight: 2
                Behavior on fillColor { ColorAnimation { duration: 120 } }
            }
            Row {
                anchors.centerIn: parent
                spacing: 4
                Text {
                    text: "⟲"
                    color: Colours.accentMem
                    font.pixelSize: 11
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "RESET"
                    font.family: "Oxanium"
                    font.pixelSize: 8
                    font.letterSpacing: 1.5
                    font.bold: true
                    color: Colours.accentMem
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MouseArea {
                id: resetPosMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root._px = 0.5; root._py = 0.5
                    root._emit()
                }
            }
        }
    }
}
