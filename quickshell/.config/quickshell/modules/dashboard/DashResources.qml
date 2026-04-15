import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../common/Colors.js" as CP
import "../../common"

// Vertical bars for CPU / RAM / Disk

Row {
    id: root

    height: parent.height
    padding: 8
    spacing: 2

    // -- CPU reading (from /proc/stat) --
    property real cpuPerc: 0
    property string _cpuPrev: ""

    readonly property real fontSize: Math.min(width * 0.12, height * 0.12)

    Timer {
        interval: 2000; running: root.visible; repeat: true; triggeredOnStart: true
        onTriggered: cpuProc.running = true
    }
    Process {
        id: cpuProc
        command: ["bash", "-c",
            "read _ u n s id iw irq si _ < /proc/stat; " +
            "echo $((u+n+s+id+iw+irq+si)) $((u+n+s+irq+si))"
        ]
        running: false
        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split(" ")
                if (parts.length < 2) return
                const total  = parseInt(parts[0])
                const active = parseInt(parts[1])
                const prev   = root._cpuPrev.split(" ")
                if (prev.length === 2) {
                    const dt = total  - parseInt(prev[0])
                    const da = active - parseInt(prev[1])
                    root.cpuPerc = dt > 0 ? da / dt : 0
                }
                root._cpuPrev = total + " " + active
            }
        }
    }

    // -- RAM reading (from /proc/meminfo) --
    property real memPerc: 0

    Timer {
        interval: 2000; running: root.visible; repeat: true; triggeredOnStart: true
        onTriggered: memProc.running = true
    }
    Process {
        id: memProc
        command: ["bash", "-c",
            "awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf \"%.4f\", (t-a)/t}' /proc/meminfo"
        ]
        running: false
        stdout: SplitParser {
            onRead: data => { root.memPerc = parseFloat(data.trim()) || 0 }
        }
    }

    // -- Disk reading (df /) --
    property real diskPerc: 0

    Timer {
        interval: 10000; running: root.visible; repeat: true; triggeredOnStart: true
        onTriggered: diskProc.running = true
    }
    Process {
        id: diskProc
        command: ["bash", "-c",
            "df / | awk 'NR==2{gsub(/%/,\"\",$5); printf \"%.4f\", $5/100}'"
        ]
        running: false
        stdout: SplitParser {
            onRead: data => { root.diskPerc = parseFloat(data.trim()) || 0 }
        }
    }

    // -- Vertical bar component --
    component Resource: Item {
        id: res

        required property string icon
        required property real value
        required property color colour

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 12
        implicitWidth: labelWrapper.implicitWidth

        // Vertical bar
        Rectangle {
            id: trackBar
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.top: labelWrapper.bottom
            anchors.topMargin: 8
            implicitWidth: 16
            radius: 4
            color: Qt.rgba(res.colour.r, res.colour.g, res.colour.b, 0.2)
            clip: true

            property real prevValue: res.value

            readonly property int _N: 10
            readonly property real tension: 0.025
            readonly property real damping: 0.985
            property var _h: (function(){ var a=[]; for(var i=0;i<10;i++) a.push(0); return a })()
            property var _v: (function(){ var a=[]; for(var i=0;i<10;i++) a.push(0); return a })()
            property bool _simActive: false

            Timer {
                interval: 16
                running: trackBar._simActive
                repeat: true
                onTriggered: { trackBar._step(); waveCanvas.requestPaint() }
            }

            function _step() {
                const amp = waveCanvas.waveAmp
                let anyActive = false
                for (let i = 0; i < _N; i++) {
                    const l = _h[i > 0 ? i - 1 : i]
                    const r = _h[i < _N-1 ? i + 1 : i]
                    _v[i] += tension * (l + r - 2 * _h[i])
                    _v[i] *= damping
                    _h[i] += _v[i]
                    _h[i] = Math.max(-amp, Math.min(amp, _h[i]))
                    if (Math.abs(_h[i]) > 0.05 || Math.abs(_v[i]) > 0.01) anyActive = true
                }
                _simActive = anyActive
            }

            function _disturb(delta) {
                const kick = delta * waveCanvas.waveAmp * 3
                for (let i = 0; i < _N; i++) _v[i] += kick
                _simActive = true
            }

            // Fill body (below the wavy surface)
            Rectangle {
                id: fillBody
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: res.value * parent.height - waveCanvas.waveAmp
                color: res.colour
                bottomRightRadius: 4
                bottomLeftRadius: 4

                Behavior on height {
                    Anim { duration: 600 }
                }
            }

            // Wavy surface — this took way too long to get right
            Canvas {
                id: waveCanvas
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: fillBody.top
                anchors.bottomMargin: -1
                height: waveAmp * 2 + 1

                readonly property real waveAmp: 2.5

                onWidthChanged:  requestPaint()
                onHeightChanged: requestPaint()

                Connections {
                    target: res
                    function onValueChanged() {
                        const delta = res.value - trackBar.prevValue
                        trackBar.prevValue = res.value
                        trackBar._disturb(delta)
                    }
                }

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const N = trackBar._N
                    const h = trackBar._h
                    const amp = waveAmp

                    ctx.beginPath()
                    ctx.moveTo(0, height)
                    ctx.lineTo(0, amp - h[0])

                    for (let i = 1; i <= N; i++) {
                        const x1 = ((i - 1) / (N - 1)) * width
                        const y1 = amp - h[i - 1]
                        const x2 = (i / (N - 1)) * width
                        const y2 = amp - h[i]
                        ctx.quadraticCurveTo(x1, y1, (x1 + x2) / 2, (y1 + y2) / 2)
                    }

                    ctx.lineTo(width, amp - h[N - 1])
                    ctx.lineTo(width, height)
                    ctx.closePath()
                    ctx.fillStyle = Qt.rgba(res.colour.r, res.colour.g, res.colour.b, 1)
                    ctx.fill()
                }
            }
        }

        Item {
            id: labelWrapper
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            implicitWidth: label.implicitWidth
            implicitHeight: label.implicitHeight
        
            // Icon/label at the top
            Text {
                id: label
                anchors.centerIn: parent
                rotation: 90
                text: res.icon
                font.family: "Oxanium"
                font.pixelSize: root.fontSize
                color: res.colour
            }
        }
    }

    Resource { icon: "CPU"; value: root.cpuPerc; colour: Colours.accentSecondary }
    Resource { icon: "RAM"; value: root.memPerc; colour: Colours.accentPrimary }
    Resource { icon: "DSK"; value: root.diskPerc; colour: CP.magenta }
}
