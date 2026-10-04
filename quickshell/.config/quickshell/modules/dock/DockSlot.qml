// DockSlot.qml — one dock icon.
//
// The icon does not travel. It sits at a fixed point inside the bulge and is
// revealed in place: opacity and scale ride `reveal`, and a short burst (glitch
// plus a scale overshoot) marks the moment it lands. Riding x on reveal as well
// made the icon swing along an arc as the wave went past, which read as a
// carousel rather than as an app coming online.
import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/Colors.js" as CP

Item {
    id: root

    required property string iconId
    required property color  accent
    required property bool   active
    required property bool   rightSide
    required property real   reveal        // 0..1, how much the wave is on us
    required property real   centerOffset  // px from the border, clamped by Docl
    required property real   artSize       // glyph size on the 24-grid, px
    required property real   artScale      // driven by Dock: it does the clamping

    signal activated()

    // Active panels go yellow, matching WallpaperBarModule's convention.
    readonly property color liveAccent: root.active ? CP.yellow : root.accent

    property bool _greeted: false

    visible: root.reveal > 0.01
    opacity: root.reveal

    // Fixed distance from the border: the wave moves, the icon only fades and
    // scales. centerOffset is derived from maxDepth, not from the live depth.
    x: (root.rightSide ? parent.width : 0)
        + (root.rightSide ? -1 : 1) * root.centerOffset
        - width / 2

    // Scale overshoot fired with the glitch, so the icon snaps in instead of
    // easing up linearly with the wave.
    property real burst: 0
    SequentialAnimation {
        id: pop
        NumberAnimation { target: root; property: "burst"; to: 1
                        duration: 90;  easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "burst"; to: 0
                        duration: 190; easing.type: Easing.InOutQuad }
    }

    // Fire once, as the icon crosses into view. Re-arms only after the wave has
    // properly left, so travelling back and forth does not stutter.
    onRevealChanged: {
        if (root.reveal > 0.5 && !root._greeted) {
            root._greeted = true
            glitch.restart()
            pop.restart()
        } else if (root.reveal < 0.22) {
            root._greeted = false
        }
    }

    // GlitchAnim assigns .color imperatively, which would permanently break a
    // binding on the glyph itself. It writes into this holder instead, and the
    // glyph only reads it while the burst is running — so the icon always falls
    // back to the live accent, even after the write has killed this binding.
    QtObject {
        id: tint
        property color color: root.liveAccent
    }

    Item {
        id: box
        anchors.fill: parent
        scale: root.artScale * (1 + 0.16 * root.burst)

        DockGlyph {
            id: art
            anchors.centerIn: parent
            iconId: root.iconId
            iconSize: root.artSize
            strokeWidth: 1.7
            color: glitch.running ? tint.color : root.liveAccent
            transform: Translate { id: shift }
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        // 2px underline: the only marker that a panel is already open.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: art.bottom
            anchors.topMargin: 4
            width: root.active ? 16 : 0
            height: 2
            color: CP.yellow
            Behavior on width { Anim { duration: 140 } }
        }

        layer.enabled: root.reveal > 0.35 || root.active
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: CP.alpha(root.liveAccent, 0.55)
            shadowBlur: 0.7
            shadowOpacity: 0.6
        }
    }

    GlitchAnim {
        id: glitch
        labelTarget: tint
        shiftTarget: shift
        baseColor: root.liveAccent
        intensity: 0.7
        shortMode: true
        finalPause: 174
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.reveal > 0.45
        hoverEnabled: false      // the wave already is the hover feedback
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
