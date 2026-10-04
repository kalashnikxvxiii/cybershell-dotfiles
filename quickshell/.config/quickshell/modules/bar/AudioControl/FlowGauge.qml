// FlowGauge.qml — Horizontal volume bar with 4 flow particles animating left→right.
// Signature visual of the Signal Flow audio concept (replaces canonical 16px slider in master/header).
// Usage:
//   FlowGauge {
//       width: 356; height: 14
//       fillPercent: audio.volume        // 0..1.5
//       active: !audio.muted && playing
//       muted: audio.muted
//       accent: Colours.accentPrimary
//       onVolumeRequested: pct => AudioControlState.setVolume(node, pct)
//       onScrollRequested: dir => AudioControlState.setVolume(node, audio.volume + dir * 0.02)
//   }
import "../../../common/Colors.js" as CP
import "../../../common"
import QtQuick
import QtQuick.Effects

Item {
    id: root

    // -- Public API ---------------------------------------
    property real  fillPercent: 0
    property bool  active:      true
    property bool  muted:       false
    property color accent:      Colours.accentPrimary
    signal volumeRequested(real pct)
    signal scrollRequested(int direction)

    implicitHeight: 14

    // -- Content cutted by the shape ------------------------
    Item {
        id: masked
        anchors.fill: parent

        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: gaugeMask
        }

        // Track background (only fill: stroke stays out of the mask)
        CutShape {
            anchors.fill: parent
            fillColor: CP.alpha(CP.void2, 0.6)
            cutBottomRight: 8
        }

        // Volume fill (horizontal gradient)
        Rectangle {
            id: fill
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 2
            width: Math.max(0, (parent.width - 4) * Math.min(1.0, root.fillPercent))
            Behavior on width { Anim { duration: 120 } }

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: muted ? CP.alpha(Colours.textMuted, 0.30) : CP.alpha(root.accent, 0.50) }
                GradientStop { position: 1.0; color: muted ? CP.alpha(Colours.textMuted, 0.50) : CP.alpha(root.accent, 0.90) }
            }
            Behavior on opacity { CAnim {} }
        }

        // 4 particles (left → right loop)
        Repeater {
            model: 4
            delegate: Rectangle {
                required property int index
                width: 3
                height: 3
                color: muted ? Colours.textMuted : root.accent
                opacity: muted ? 0 : (1.0 - index * 0.2)
                anchors.verticalCenter: parent.verticalCenter

                NumberAnimation on x {
                    from: -3
                    to: root.width
                    duration: 1800
                    loops: Animation.Infinite
                    running: root.active && !root.muted && root.visible
                }
                Component.onCompleted: x = -3 + (index * (root.width / 4))
                Behavior on opacity { CAnim {} }
            }
        }
    }

    // -- Maschera: stessa forma del track --------------------
    CutShape {
        id: gaugeMask
        layer.enabled: true
        visible: false
        width: parent.width
        height: parent.height
        fillColor: "white"
        cutBottomRight: 8
    }

    // -- Bordo, fuori dalla maschera: stroke pieno e non tagliato --------
    CutShape {
        id: track
        anchors.fill: parent
        fillColor: "transparent"
        strokeColor: muted ? CP.alpha(Colours.textMuted, 0.4) : CP.alpha(root.accent, 0.35)
        strokeWidth: 1
        inset: 0.5
        cutBottomRight: 8
        Behavior on strokeColor { CAnim {} }
    }

    // -- Interaction: drag, click, wheel --------------------------
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => _setFromX(mouse.x)
        onPositionChanged: mouse => { if (pressed) _setFromX(mouse.x) }
        onWheel: wheel => {
            root.scrollRequested(wheel.angleDelta.y > 0 ? 1 : -1)
            wheel.accepted = true
        }
        function _setFromX(x) {
            if (width <= 0) return
            var pct = Math.max(0, Math.min(1.5, x / width * 1.5))
            // Snap to 100% within ±2%
            if (Math.abs(pct - 1.0) < 0.02) pct = 1.0
            root.volumeRequested(pct)
        }
    }
}
