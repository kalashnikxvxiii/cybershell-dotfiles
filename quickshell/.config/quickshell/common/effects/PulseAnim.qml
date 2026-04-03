// PulseAnim.qml — Animazione pulse opacity (fade in/out loop)
// Uso:
//   PulseAnim on opacity { running: root.critical; minOpacity: 0.4; duration: 600 }

import QtQuick

SequentialAnimation {
    id: root

    property real minOpacity: 0.4
    property real maxOpacity: 1.0
    property int duration: 600

    loops: Animation.Infinite

    NumberAnimation { to: root.minOpacity; duration: root.duration }
    NumberAnimation { to: root.maxOpacity; duration: root.duration }
}
