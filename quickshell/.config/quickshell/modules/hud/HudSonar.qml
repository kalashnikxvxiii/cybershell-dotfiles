// HudSonar.qml -- the radar reduced to a tile: it shows only what is linked right
// now, scans nothing, and sweeps while the pointer is over it. The full Sonar grows
// out of this tile (SonarPanel), opened from here or from the dock.
import QtQuick
import "../../common"
import "../sonar"

Item {
    id: root

    required property var screen

    readonly property var entries: {
        const netRev = SonarState.netRev, btRev = SonarState.btRev
        const out = []
        const wired = SonarState.wiredDevice
        if (wired && wired.connected)
            out.push({ key: "wired:" + wired.name, label: wired.name.toUpperCase(), ring: 0.1, connected: true })
        if (SonarState.activeSsid !== "")
            out.push({ key: "wifi:" + SonarState.activeSsid, label: SonarState.activeSsid, ring: 0.45, connected: true })
        const bt = SonarState.connectedBtDevice()
        if (bt)
            out.push({ key: "bt:" + bt.address, label: bt.name, ring: 0.75, connected: true })
        return out
    }

    width: 220
    height: 210

    SonarOutline {
        anchors.fill: parent
        fillColor: Qt.rgba(0.01, 0.04, 0.06, 0.72)
        strokeColor: HudState.alpha(HudState.wallust, hover.hovered ? 0.9 : 0.5)
    }

    // GlitchAnim writes colors imperatively: into this holder, not into a binding
    QtObject {
        id: tint
        property color color: HudState.wallust
    }
    GlitchAnim {
        id: glitch
        labelTarget: tint
        shiftTarget: labelShift
        baseColor: HudState.wallust
    }

    Text {
        x: 14
        y: 8
        text: "SONAR"
        color: glitch.running ? tint.color : HudState.wallust
        transform: Translate { id: labelShift }
        font { family: HudState.font; pixelSize: 11; bold: true; letterSpacing: 2 }
    }
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 12
        y: 9
        text: root.entries.length + " LINK"
        color: HudState.alpha(HudState.wallust, 0.7)
        font { family: HudState.font; pixelSize: 9; letterSpacing: 1 }
    }

    SonarDisplay {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 28
        width: 176
        height: 176
        accent: HudState.wallust
        entries: root.entries
        sweeping: hover.hovered
        active: hover.hovered && HudState.enabled
        revision: SonarState.netRev + SonarState.btRev
    }

    HoverHandler {
        id: hover
        onHoveredChanged: if (hovered) glitch.restart()
    }

    // Above the display, whose own MouseArea picks contacts
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: SonarState.toggleFrom(root.screen.name, "net")
    }
}
