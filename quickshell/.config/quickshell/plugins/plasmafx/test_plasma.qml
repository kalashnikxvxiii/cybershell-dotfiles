import QtQuick
import PlasmaFX

Rectangle {
    width: 200; height: 300
    color: "black"

    PlasmaFlowItem {
        id: plasma
        anchors.fill: parent
        baseColor: "#39ff14"
        glowColor: "#00ff41"
        power: powerAnim.value
    }

    // Continuous loop: 0 → 1 → 0 over 10 seconds
    SequentialAnimation {
        id: powerAnim
        property real value: 0.0
        loops: Animation.Infinite
        running: true

        NumberAnimation {
            target: powerAnim; property: "value"
            from: 0.0; to: 1.0; duration: 5000
        }
        NumberAnimation {
            target: powerAnim; property: "value"
            from: 1.0; to: 0.0; duration: 5000
        }
    }

    // Current power readout
    Text {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 8
        text: (powerAnim.value * 100).toFixed(0) + "% power"
        color: "white"
        font.pixelSize: 12
        font.family: "Oxanium"
    }
}
