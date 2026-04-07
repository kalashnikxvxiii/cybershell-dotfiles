// CAnim.qml — Standard color animation
//
// Use in Behavior on color {} for smooth color transitions.
//
// CP2077 design guide:
//   Color transitions:  ~120ms — smooth enough (it's not a live number)
//   Urgent/critical states: use a shorter duration (60–80ms) via inline override.
//   Ambient fade (glow pulse): use NumberAnimation on opacity instead of ColorAnimation.
//
// Inline overrides:
//   CAnim { duration: 80 }   — urgent states, snappier
//   CAnim { duration: 200 }  — more gradual fade (ambient)

import QtQuick

ColorAnimation {
    duration: 120
}
