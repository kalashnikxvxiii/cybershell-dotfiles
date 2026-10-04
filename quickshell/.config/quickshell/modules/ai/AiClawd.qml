// AiClawd.qml - Claude's pixel mascot, alive enough to read as a standby light.
//
// Rebuilt from the CLI's own block-glyph sprite: on an 18x5 pixel grid the body
// is one 12x4 slab, arms and legs are single pixels hanging off it and the eyes
// are holes punched through it. Every move is a whole step on a PauseAnimation
// timeline, never a curve: the same mechanical cadence as the rest of the shell
import QtQuick

Item {
    id: root

    // One sprite pixel. Taller than wide on purpose: the sprite is drawn with
    // quadrant glyphs, and a terminal cell is twice as tall as it is wide
    property int px: 7
    property int py: 12
    property color body: "#d97757"          // Claude's terracotta
    property color hole: "#05070d"          // what the eyes are punched through to
    readonly property bool running: visible

    // The whole pose. Offsets are in sprite pixels, the hop in half pixels
    property real bob: 0                    // 0 or 0.5: the idle breathing
    property int hop: 0                     // lift of the whole figure
    property int look: 0                    // -1 / 0 / 1: where the eyes point
    property bool blink: false
    property bool wave: false               // right arm up
    property int stride: -1                 // lifted legs: 0 / 1 one pair, 2 both

    implicitWidth: 18 * px
    implicitHeight: 5 * py

    component Px: Rectangle {
        property real cx: 0
        property real cy: 0
        property real cw: 1
        property real ch: 1
        x: cx * root.px
        y: cy * root.py
        width: cw * root.px
        height: ch * root.py
        color: root.body
    }

    // Says hello every time it comes into view
    onRunningChanged: {
        if (root.running) waveAnim.restart()
        else {
            // Out of view mid-act: park every pose, or it comes back frozen
            for (const a of [lookAnim, waveAnim, hopAnim, marchAnim, blinkAnim]) a.stop()
            root.hop = 0; root.look = 0; root.wave = false; root.blink = false; root.stride = -1
        }
    }

    Item {
        id: fig
        width: root.width
        height: root.height
        y: -root.hop * root.py / 2

        Px { cx: 4;  cy: 4; ch: root.stride === 0 || root.stride === 2 ? 0.5 : 1 }
        Px { cx: 11; cy: 4; ch: root.stride === 0 || root.stride === 2 ? 0.5 : 1 }
        Px { cx: 6;  cy: 4; ch: root.stride === 1 || root.stride === 2 ? 0.5 : 1 }
        Px { cx: 13; cy: 4; ch: root.stride === 1 || root.stride === 2 ? 0.5 : 1 }

        // Body, arms and eyes ride the breathing; the legs stay planted
        Item {
            width: fig.width
            height: fig.height
            y: root.bob * root.py

            Px { cx: 3; cy: 0; cw: 12; ch: 4 }
            Px { cx: 1; cy: 2; cw: 2 }
            Px { cx: 15; cy: 2; cw: 2; visible: !root.wave }
            // Raised: a diagonal off the shoulder
            Px { cx: 15; cy: 1; visible: root.wave }
            Px { cx: 16; cy: 0; visible: root.wave }

            Px { cx: 5 + root.look;  cy: 1; color: root.hole; visible: !root.blink }
            Px { cx: 12 + root.look; cy: 1; color: root.hole; visible: !root.blink }
        }
    }

    SequentialAnimation {
        running: root.running
        loops: Animation.Infinite
        PropertyAction { target: root; property: "bob"; value: 0.5 }
        PauseAnimation { duration: 520 }
        PropertyAction { target: root; property: "bob"; value: 0 }
        PauseAnimation { duration: 780 }
    }

    // Blinks on its own clock, so a blink can land in the middle of anything
    Timer {
        running: root.running
        repeat: true
        interval: 3000
        onTriggered: { interval = 1800 + Math.random() * 4200; blinkAnim.restart() }
    }

    // One small act every few seconds. Never the same one twice in a row
    Timer {
        property int last: -1
        running: root.running
        repeat: true
        interval: 3500
        onTriggered: {
            interval = 2600 + Math.random() * 3800
            const acts = [lookAnim, waveAnim, hopAnim, marchAnim]
            let k = Math.floor(Math.random() * acts.length)
            if (k === last) k = (k + 1) % acts.length
            last = k
            acts[k].restart()
        }
    }

    SequentialAnimation {
        id: blinkAnim
        PropertyAction { target: root; property: "blink"; value: true }
        PauseAnimation { duration: 120 }
        PropertyAction { target: root; property: "blink"; value: false }
    }

    SequentialAnimation {
        id: lookAnim
        PropertyAction { target: root; property: "look"; value: -1 }
        PauseAnimation { duration: 700 }
        PropertyAction { target: root; property: "look"; value: 1 }
        PauseAnimation { duration: 700 }
        PropertyAction { target: root; property: "look"; value: 0 }
    }

    SequentialAnimation {
        id: waveAnim
        loops: 3
        PropertyAction { target: root; property: "wave"; value: true }
        PauseAnimation { duration: 200 }
        PropertyAction { target: root; property: "wave"; value: false }
        PauseAnimation { duration: 200 }
    }

    SequentialAnimation {
        id: hopAnim
        loops: 2
        PropertyAction { target: root; property: "stride"; value: 2 }
        PropertyAction { target: root; property: "hop"; value: 1 }
        PauseAnimation { duration: 70 }
        PropertyAction { target: root; property: "hop"; value: 2 }
        PauseAnimation { duration: 160 }
        PropertyAction { target: root; property: "hop"; value: 1 }
        PauseAnimation { duration: 70 }
        PropertyAction { target: root; property: "hop"; value: 0 }
        PropertyAction { target: root; property: "stride"; value: -1 }
        PauseAnimation { duration: 140 }
    }

    // Marching on the spot
    SequentialAnimation {
        id: marchAnim
        SequentialAnimation {
            loops: 5
            PropertyAction { target: root; property: "stride"; value: 0 }
            PauseAnimation { duration: 150 }
            PropertyAction { target: root; property: "stride"; value: 1 }
            PauseAnimation { duration: 150 }
        }
        PropertyAction { target: root; property: "stride"; value: -1 }
    }
}
