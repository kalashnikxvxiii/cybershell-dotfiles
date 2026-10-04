// SonarModule.qml — one bar module for both radios, and the way into the
// Sonar panel.
//
// Two segments in one module: the network on the left, bluetooth on the right,
// each with its own colour, which is why this does not reuse CyberpunkModule —
// that one paints a single label in a single accent.
//
//   left click   — Sonar panel, network view
//   right click  — Sonar panel, bluetooth view
//   middle click — blueman, for everything the panel does not cover
import QtQuick
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import "../../common/Colors.js" as CP
import "../../common"
import "../../common/effects"

Item {
    id: root

    property bool showBackground: true

    // ── Network segment ──────────────────────────────────────────────────
    readonly property bool wired: !!SonarState.wiredDevice && SonarState.wiredDevice.connected
    readonly property bool wifiUp: !!SonarState.wifiDevice && SonarState.wifiDevice.connected
    readonly property bool online: wired || wifiUp

    readonly property string netText: {
        if (root.wired) return "ETH"
        if (root.wifiUp) return SonarState.activeSsid !== "" ? SonarState.activeSsid.toUpperCase()
                                                             : "WIFI"
        return "NET OFF"
    }
    readonly property color netColor: root.online ? CP.cyan : CP.red

    // ── Bluetooth segment ────────────────────────────────────────────────
    // Three states, not two: a linked device, the adapter on with nothing
    // linked, and the adapter off. Before this the segment looked dead
    // whenever nothing happened to be connected.
    readonly property var btLink: SonarState.connectedBtDevice()
    readonly property bool btOn: !!SonarState.adapter && SonarState.adapter.enabled
    readonly property string btText: root.btLink
        ? (root.btLink.deviceName || root.btLink.name || "BT").toUpperCase()
        : (root.btOn ? "BT" : "BT OFF")
    readonly property color btColor: root.btLink ? CP.magenta
                                    : root.btOn  ? CP.alpha(CP.magenta, 0.55)
                                                 : Qt.rgba(0.45, 0.45, 0.5, 1)

    implicitHeight: 24
    implicitWidth: labels.implicitWidth + 24

    // Off the network: the whole module breathes, as the old network module did.
    PulseAnim on opacity { running: !root.online; duration: 700 }

    CutShape {
        visible: root.showBackground
        anchors.fill: parent
        fillColor: CP.moduleBg
        strokeColor: "transparent"
        cutBottomLeft: 8

        Rectangle {
            width: 2; height: parent.height
            color: root.netColor
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width; height: 1
            color: CP.alpha(root.netColor, 0.55)
        }
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            width: parent.width; height: 1
            color: CP.alpha(root.netColor, 0.22)
        }
    }

    Row {
        id: labels
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 12
        spacing: 7
        transform: Translate { id: labelShift }

        Text {
            id: netLabel
            anchors.verticalCenter: parent.verticalCenter
            text: root.netText
            font.family: "Oxanium"
            font.pixelSize: 12
            // GlitchAnim writes .color imperatively, which would kill a binding
            // here: after the first hover the label stopped turning red when the
            // link dropped. It writes into netTint instead, read only mid-glitch.
            color: glitchAnim.running ? netTint.color : root.netColor
        }

        // Divider, not a bullet: the two halves are separate readings.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1; height: 10
            color: CP.alpha(CP.cyan, 0.3)
        }

        Text {
            id: btLabel
            anchors.verticalCenter: parent.verticalCenter
            text: root.btText
            font.family: "Oxanium"
            font.pixelSize: 12
            color: root.btColor
        }
    }

    // Glow under the pair, same trick as the other modules: two offset copies
    // at low alpha rather than a real shadow.
    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 1
        anchors.left: parent.left
        anchors.leftMargin: 12
        text: root.netText
        font: netLabel.font
        color: CP.alpha(root.netColor, 0.42)
        z: -1
    }

    // ── Hover glitch ─────────────────────────────────────────────────────
    QtObject {
        id: netTint
        property color color: root.netColor
    }

    GlitchAnim {
        id: glitchAnim
        labelTarget: netTint
        shiftTarget: labelShift
        baseColor: root.netColor
        c1: CP.magenta
        c3: root.netColor
    }

    HoverHandler { id: hoverHandler; onHoveredChanged: if (hovered) glitchAnim.restart() }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)        SonarState.toggleView("net")
            else if (mouse.button === Qt.RightButton)  SonarState.toggleView("bt")
            else if (mouse.button === Qt.MiddleButton) blueman.running = true
        }
    }

    Process { id: blueman; command: ["blueman-manager"]; running: false }
}
