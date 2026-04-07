// Anim.qml — Standard numeric animation
//
// Drop-in compact replacement for NumberAnimation in Behaviors and Transitions.
//
// CP2077 design guide:
//   Panel slide-in:  150–200ms OutQuart  (fast deceleration, snappy)
//   Panel slide-out: 100–130ms InQuart   (accelerates out, vanishes quick)
//   Data values:     0ms                  (instant update — never tween live numbers)
//   Colors:          300ms InOutQuad      (use CAnim for that)
//
// Easing.OutQuart → heavier deceleration than OutCubic:
//   things slam to a stop, no gentle gliding here.
//
// Inline overrides:
//   Anim { duration: 400 }
//   Anim { duration: 260; easing.type: Easing.InCubic }
//   Anim { target: root; property: "implicitHeight"; duration: 260 }

import QtQuick

NumberAnimation {
    duration:    200
    easing.type: Easing.OutQuart
}
