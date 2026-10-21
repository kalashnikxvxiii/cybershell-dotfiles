// StreamFlowNode.qml — Per-app audio stream visualized as a flow node.
// Layout (392×58):
//   [ICON]  APP NAME                                [VOL SLIDER]
//   [BOX ]  PID 8924  STREAM /pw.45:7  S16LE              100%
//   [    ]  ──•──•──•──→                                  -3.2dB
//           [██████████████░░░] (inline level meter under flow line)
import "../../../common/Colors.js" as CP
import "../../../common"
import "../../../common/effects"
import QtQuick
import CyberAudio.Services

Item {
    id: root

    // -- API --------------------------------
    property var   streamNode: null
    property color accent: Colours.accentPrimary

    // -- Derived ---------------------------
    readonly property bool muted: streamNode && streamNode.audio ? streamNode.audio.muted : false
    readonly property int  volPercent: streamNode && streamNode.audio ? Math.round(streamNode.audio.volume * 100) : 0
    readonly property string appName: {
        if (!streamNode) return "—"
        var p = streamNode.properties || ({})
        return (p["application.name"] || streamNode.description || streamNode.name || "UNKNOWN").toUpperCase()
    }
    readonly property string streamPath: {
        if (!streamNode) return ""
        var p = streamNode.properties || ({})
        return p["node.name"] || p["object.path"] || ""
    }
    readonly property string streamFormat: {
        if (!streamNode) return ""
        var p = streamNode.properties || ({})
        return p["audio.format"] || "S16LE"
    }
    readonly property int streamPid: {
        if (!streamNode) return 0
        var p = streamNode.properties || ({})
        return Number(p["application.process.id"] || 0)
    }

    // -- VU reale dello stream applicativo ---------------------
    readonly property string nodeTarget: streamNode && streamNode.properties
                                        ? (streamNode.properties["node.name"] || "") : ""

    // dBFS → 0-1, fondoscala −60dB
    function _vu(v) {
        if (v <= 0.001) return 0
        var db = 20 * Math.log(v) / Math.LN10
        return Math.max(0, Math.min(1, (db + 60) / 60))
    }

    NodeLevelProvider {
        id: nodeLevel
        target: root.nodeTarget
        captureSink: false
    }
    ServiceRef { service: root.visible ? nodeLevel : null }

    // The meter follows the provider (~90 updates a second) through a 30Hz
    // sample, eased toward the target the way the 60ms Behavior it replaces
    // did. Binding the bar straight to the provider kept the popup rendering at
    // the monitor's refresh rate for as long as anything played
    property real _level: 0
    Ticker {
        running: root.visible && !root.muted
        onTicked: {
            const target = root._vu(nodeLevel.peak)
            const next = root._level + (target - root._level) * 0.65
            root._level = Math.abs(next - target) < 0.004 ? target : next
        }
    }

    // App category icon glyph (based on application.name heuristics)
    readonly property string iconGlyph: {
        var n = (appName || "").toLowerCase()
        if (n.indexOf("spotify") >= 0 || n.indexOf("mpd") >= 0 || n.indexOf("mpv") >= 0) return "♫"
        if (n.indexOf("firefox") >= 0 || n.indexOf("chrome") >= 0 || n.indexOf("brave") >= 0) return "▣"
        if (n.indexOf("discord") >= 0 || n.indexOf("telegram") >= 0) return "💬"
        return "◆"
    }
    readonly property string iconCategory: {
        var n = (appName || "").toLowerCase()
        if (n.indexOf("spotify") >= 0 || n.indexOf("mpd") >= 0 || n.indexOf("mpv") >= 0) return "MEDIA"
        if (n.indexOf("firefox") >= 0 || n.indexOf("chrome") >= 0 || n.indexOf("brave") >= 0) return "BROWSER"
        if (n.indexOf("discord") >= 0 || n.indexOf("telegram") >= 0) return "COMM"
        return "APP"
    }

    implicitHeight: 58

    // ── Background card ──────────────────────────────────────────
    CutShape {
        anchors.fill: parent
        fillColor: muted ? CP.alpha(CP.red, 0.05) : (rowMa.containsMouse ? CP.alpha(root.accent, 0.10) : CP.alpha(root.accent, 0.05))
        strokeColor: muted ? CP.alpha(CP.red, 0.4) : CP.alpha(root.accent, 0.5)
        strokeWidth: 1
        inset: 0.5
        cutBottomRight: 16
        Behavior on fillColor   { CAnim {} }
        Behavior on strokeColor { CAnim {} }
    }

    // ── Icon container (left, 46×46) ─────────────────────────────
    Item {
        id: iconBox
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 6
        width: 46; height: 46
        CutShape {
            anchors.fill: parent
            fillColor: muted ? CP.alpha(CP.void2, 0.5) : CP.alpha(root.accent, 0.15)
            strokeColor: muted ? CP.alpha(Colours.textMuted, 0.4) : CP.alpha(root.accent, 0.55)
            strokeWidth: 0.7
            inset: 0.5
            cutTopRight: 8
        }
        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -4
            text: muted ? "🔇" : root.iconGlyph
            font.pixelSize: 20
            color: muted ? Colours.textMuted : root.accent
        }
        Text {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 3
            text: root.iconCategory
            font.family: "Oxanium"
            font.pixelSize: 8
            font.letterSpacing: 1
            color: muted ? Colours.textMuted : CP.alpha(root.accent, 0.65)
        }
    }

    // ── Name + metadata + flow line + level meter ────────────────
    Item {
        id: mid
        anchors.left: iconBox.right
        anchors.leftMargin: 6
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: volBox.left
        anchors.rightMargin: 8
        anchors.topMargin: 6
        anchors.bottomMargin: 6

        Text {
            id: appNameTxt
            anchors.top: parent.top
            anchors.left: parent.left
            text: root.appName
            font.family: "Oxanium"
            font.pixelSize: 11
            font.letterSpacing: 1
            font.bold: true
            color: muted ? Colours.textMuted : root.accent
            elide: Text.ElideRight
            width: parent.width
        }
        Text {
            id: appMeta
            anchors.top: appNameTxt.bottom
            anchors.left: parent.left
            anchors.topMargin: 2
            text: {
                if (root.muted) return "PID " + root.streamPid + "  STREAM " + root.streamPath + "  MUTED"
                return "PID " + root.streamPid + "  STREAM " + root.streamPath + "  " + root.streamFormat
            }
            font.family: "Oxanium"
            font.pixelSize: 8
            font.letterSpacing: 0.5
            color: Colours.textMuted
        }

        // Flow line container (with particles)
        Item {
            id: flowLine
            anchors.top: appMeta.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 6
            height: 8
            visible: !root.muted

            // Line stroke
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 6
                height: 1.2
                color: CP.alpha(root.accent, 0.75)
            }
            // Arrow
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "→"
                font.pixelSize: 8
                color: root.accent
            }
            // 2 particles
            Ticker { id: flowTick; running: !root.muted && root.visible }
            Repeater {
                model: 2
                delegate: Rectangle {
                    required property int index
                    width: 2; height: 2
                    radius: 1
                    color: root.accent
                    opacity: 1.0 - index * 0.4
                    anchors.verticalCenter: parent.verticalCenter
                    x: flowTick.elapsed > 0
                        ? (flowLine.width - 6) * ((flowTick.elapsed % 1800) / 1800)
                        : index * (flowLine.width / 2)
                }
            }
        }

        // Muted state: "SIGNAL CUT" placeholder
        Item {
            visible: root.muted
            anchors.top: appMeta.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 6
            height: 8
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 0.8
                color: CP.alpha(CP.red, 0.4)
            }
            Text {
                anchors.centerIn: parent
                text: "— SIGNAL CUT —"
                font.family: "Oxanium"
                font.pixelSize: 9
                font.letterSpacing: 1.5
                font.bold: true
                color: CP.alpha(CP.red, 0.7)
            }
        }

        // Inline level meter (under flow line, only if not muted)
        Rectangle {
            visible: !root.muted
            anchors.top: flowLine.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 2
            anchors.rightMargin: 6
            height: 2
            color: CP.alpha(CP.void2, 0.7)
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * root._level
                color: CP.alpha(root.accent, 0.9)
            }
        }
    }

    // -- Volume slider (right, 100×14) + % --------------------
    Item {
        id: volBox
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 6
        width: 100
        height: 40

        // Volume slider canonical (16px → ridotto a 14 per compattezza)
        Item {
            id: sliderArea
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 4
            height: 14

            CutShape {
                id: sliderTrack
                anchors.fill: parent
                fillColor: CP.alpha(CP.void2, 0.6)
                strokeColor: CP.alpha(root.accent, 0.30)
                strokeWidth: 0.6
                inset: 0.5
                cutBottomRight: 6
            }
            Rectangle {
                anchors.left: sliderTrack.left
                anchors.top: sliderTrack.top
                anchors.bottom: sliderTrack.bottom
                anchors.margins: 2
                width: Math.max(0, (sliderTrack.width - 4) * Math.min(1.0, root.volPercent / 100))
                color: muted ? CP.alpha(Colours.textMuted, 0.35) : CP.alpha(root.accent, 0.45)
                Behavior on color { CAnim {} }
            }
            // Thumb
            Item {
                width: 6; height: 18
                x: Math.max(0, Math.min(sliderTrack.width - width, sliderTrack.width * Math.min(1.0, root.volPercent / 100) - width / 2))
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent
                    color: muted ? Colours.textMuted : root.accent
                    border.color: "white"
                    border.width: 0.7
                }
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => _set(mouse.x)
                onPositionChanged: mouse => { if (pressed) _set(mouse.x) }
                onWheel: wheel => {
                    if (!root.streamNode || !root.streamNode.audio) return
                    AudioControlState.setVolume(root.streamNode, root.streamNode.audio.volume + (wheel.angleDelta.y > 0 ? 0.02 : -0.02))
                    wheel.accepted = true
                }
                function _set(x) {
                    if (sliderTrack.width <= 0) return
                    var pct = Math.max(0, Math.min(1.5, x / sliderTrack.width * 1.5))
                    if (Math.abs(pct - 1.0) < 0.02) pct = 1.0
                    AudioControlState.setVolume(root.streamNode, pct)
                }
            }
        }

        // Volume %
        Text {
            id: volPctTxt
            anchors.top: sliderArea.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 3
            text: muted ? "MUTE" : (root.volPercent + "%")
            font.family: "Oxanium"
            font.pixelSize: 10
            font.bold: true
            color: muted ? Colours.textMuted : root.accent
        }
    }

    // ── Click on left half toggles mute ──────────────────────────
    MouseArea {
        id: rowMa
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: volBox.left
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: AudioControlState.toggleMute(root.streamNode)
    }
}
