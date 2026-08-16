// ~/dotfiles/quickshell/.config/quickshell/modules/bar/AudioControl/AudioDeviceRow.qml
// Compact PipeWire node row — modes: "selectable" (alternatives) / "app" (legacy fallback).
// Hero mode removed → use EndpointCard.qml for default device cards.
// Layout (392×36):
//   ○ NAME OF DEVICE                  [mini level ════]  68%
//   DEV /alsa.X:Y  SR 48kHz/16b                          IDLE
import "../../../common/Colors.js" as CP
import "../../../common"
import QtQuick

Item {
    id: root

    // ── API ──────────────────────────────────────────────────────
    property var    node:        null
    property string mode:        "selectable"   // "selectable" | "app"
    property color  accent:      Colours.accentSecondary
    signal selectRequested()

    // ── Derived ──────────────────────────────────────────────────
    readonly property string displayName: {
        if (!node) return "—"
        var props = node.properties || ({})
        if (mode === "app")
            return ((props["application.name"] || node.description || node.name || "Unknown")).toUpperCase()
        return ((node.description || node.name || "Unknown")).toUpperCase()
    }
    readonly property string devPath: {
        if (!node || !node.properties) return ""
        var p = node.properties
        return p["node.name"] || p["api.alsa.path"] || p["object.path"] || ""
    }
    readonly property string sampleRate: {
        if (!node || !node.properties) return ""
        var r = node.properties["node.rate"] || node.properties["audio.rate"] || "48000"
        if (typeof r === "string" && r.indexOf("/") >= 0) r = r.split("/")[1]
        return Math.round(Number(r) / 1000) + "kHz/16b"
    }
    readonly property int  volPercent: node && node.audio ? Math.round(node.audio.volume * 100) : 0
    readonly property bool muted:      node && node.audio ? node.audio.muted : false
    readonly property bool isDefaultSink:   root.node && root.node === AudioControlState.defaultSink
    readonly property bool isDefaultSource: root.node && root.node === AudioControlState.defaultSource

    implicitHeight: 36

    // ── Background ───────────────────────────────────────────────
    CutShape {
        anchors.fill: parent
        anchors.margins: 1
        fillColor: muted
                   ? CP.alpha(CP.void2, 0.45)
                   : (rowMa.containsMouse ? CP.alpha(root.accent, 0.08) : "transparent")
        strokeColor: muted ? CP.alpha(Colours.textMuted, 0.4) : CP.alpha(root.accent, 0.25)
        strokeWidth: 0.7
        inset: 0.5
        cutTopLeft: 2
        cutBottomRight: 2
        Behavior on fillColor   { CAnim {} }
        Behavior on strokeColor { CAnim {} }
    }

    // ── Row icon (● default / ○ alternative / ◆ app / 🔇 muted) ─
    Text {
        id: rowIcon
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.top: parent.top
        anchors.topMargin: 4
        text: muted ? "🔇" : (mode === "app" ? "◆" : (root.isDefaultSink || root.isDefaultSource ? "●" : "○"))
        font.pixelSize: 9
        color: muted ? Colours.textMuted : CP.alpha(root.accent, 0.85)
    }

    // ── Name + dev metadata ──────────────────────────────────────
    Text {
        id: rowName
        anchors.left: rowIcon.right
        anchors.leftMargin: 4
        anchors.top: parent.top
        anchors.topMargin: 3
        anchors.right: levelMeter.left
        anchors.rightMargin: 6
        text: root.displayName
        font.family: "Oxanium"
        font.pixelSize: 9
        font.letterSpacing: 1
        font.bold: true
        color: muted ? Colours.textMuted : CP.alpha(root.accent, 0.85)
        elide: Text.ElideRight
    }
    Text {
        anchors.left: rowName.left
        anchors.top: rowName.bottom
        anchors.topMargin: 1
        anchors.right: rowName.right
        text: {
            var parts = []
            if (root.devPath) parts.push("DEV " + root.devPath)
            if (root.sampleRate) parts.push("SR " + root.sampleRate)
            return parts.join("  ")
        }
        font.family: "Oxanium"
        font.pixelSize: 6
        color: muted ? Colours.textMuted : CP.alpha(Colours.textMuted, 0.85)
        elide: Text.ElideRight
    }

    // ── Mini level meter (right side) ────────────────────────────
    Rectangle {
        id: levelMeter
        anchors.right: rowVolTxt.left
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -4
        width: 70
        height: 3
        color: CP.alpha(CP.void2, 0.6)
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * Math.min(1.0, root.volPercent / 100)
            color: muted ? CP.alpha(Colours.textMuted, 0.4) : CP.alpha(root.accent, 0.6)
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -3
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => _set(mouse.x + 3)
            onPositionChanged: mouse => { if (pressed) _set(mouse.x + 3) }
            onWheel: wheel => {
                if (!root.node || !root.node.audio) return
                AudioControlState.setVolume(root.node, root.node.audio.volume + (wheel.angleDelta.y > 0 ? 0.02 : -0.02))
                wheel.accepted = true
            }
            function _set(x) {
                if (levelMeter.width <= 0) return
                var pct = Math.max(0, Math.min(1.5, x / levelMeter.width * 1.5))
                if (Math.abs(pct - 1.0) < 0.02) pct = 1.0
                AudioControlState.setVolume(root.node, pct)
                if (root.muted) AudioControlState.toggleMute(root.node)
            }
        }
    }

    // ── Volume % + status sub-line ───────────────────────────────
    Text {
        id: rowVolTxt
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.top: parent.top
        anchors.topMargin: 3
        text: muted ? "MUTE" : (root.volPercent + "%")
        font.family: "Oxanium"
        font.pixelSize: 8
        font.bold: true
        color: muted ? Colours.textMuted : Colours.accentPrimary
    }
    Text {
        anchors.right: rowVolTxt.right
        anchors.top: rowVolTxt.bottom
        anchors.topMargin: 1
        text: muted ? "MUTE" : (volPercent > 0 ? "IDLE" : "OFF")
        font.family: "Oxanium"
        font.pixelSize: 6
        color: CP.alpha(Colours.textMuted, 0.85)
    }

    // ── Route arrow (visible on hover, selectable mode only) ────
    Text {
        visible: rowMa.containsMouse && mode === "selectable"
        anchors.right: parent.right
        anchors.rightMargin: -8
        anchors.verticalCenter: parent.verticalCenter
        text: "→"
        font.pixelSize: 12
        color: CP.alpha(root.accent, 0.7)
        opacity: rowMa.containsMouse ? 1 : 0
        Behavior on opacity { CAnim {} }
    }

    // ── Row click ────────────────────────────────────────────────
    MouseArea {
        id: rowMa
        anchors.left: parent.left
        anchors.right: levelMeter.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (mode === "selectable") root.selectRequested()
            else if (mode === "app")   AudioControlState.toggleMute(root.node)
        }
    }
}
