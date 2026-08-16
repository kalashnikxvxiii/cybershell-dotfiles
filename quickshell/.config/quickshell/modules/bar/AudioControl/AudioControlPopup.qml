// ~/dotfiles/quickshell/.config/quickshell/modules/bar/AudioControl/AudioControlPopup.qml
// Signal Flow root popup — INTENTIONAL DEVIATION from §1 canonical:
// border + CornerAccents + glow follow ACTIVE TAB color (cyan/magenta/yellow/neon).
// In compact mode, always cyan.
import "../../../common/Colors.js" as CP
import "../../../common"
import "../../../common/effects"
import "tabs" as Tabs
import QtQuick
import QtQuick.Effects

FocusScope {
    id: root
    signal closeRequested()

    // ── Sizing ───────────────────────────────────────────────────
    readonly property int compactW:  220
    readonly property int compactH:  140
    readonly property int expandedW: 420
    readonly property int expandedH: 620

    width:  AudioControlState.expanded ? expandedW : compactW
    height: AudioControlState.expanded ? expandedH : compactH

    Behavior on width  { Anim { duration: AudioControlState.expanded ? 260 : 200; easing.type: AudioControlState.expanded ? Easing.OutQuart : Easing.InCubic } }
    Behavior on height { Anim { duration: AudioControlState.expanded ? 260 : 200; easing.type: AudioControlState.expanded ? Easing.OutQuart : Easing.InCubic } }

    // ── Tab-aware accent ─────────────────────────────────────────
    readonly property color tabAccent: {
        if (!AudioControlState.expanded) return Colours.accentSecondary   // cyan in compact
        switch (AudioControlState.activeTab) {
        case "outputs": return Colours.accentSecondary    // cyan
        case "inputs":  return CP.magenta
        case "apps":    return Colours.accentPrimary       // yellow
        case "eq":      return CP.neon
        }
        return Colours.accentSecondary
    }

    // ── Enter animation ──────────────────────────────────────────
    opacity: 0
    property real slideY: -20
    Component.onCompleted: {
        enterOpacityAnim.start()
        enterSlideAnim.start()
    }
    NumberAnimation {
        id: enterOpacityAnim
        target: root; property: "opacity"
        from: 0; to: 1; duration: 180; easing.type: Easing.OutQuart
    }
    NumberAnimation {
        id: enterSlideAnim
        target: root; property: "slideY"
        from: -20; to: 0; duration: 200; easing.type: Easing.OutQuart
    }

    // ── Card background ──────────────────────────────────────────
    Item {
        id: card
        x: 0; y: root.slideY
        width: parent.width
        height: parent.height

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Colours.glowFor(root.tabAccent)
            shadowBlur: 0.7
            shadowOpacity: Colours.glowOpacity
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }

        CutShape {
            anchors.fill: parent
            fillColor: Colours.moduleBg
            strokeColor: Colours.panelBorder(root.tabAccent)
            strokeWidth: 1
            inset: 0.5
            cutTopRight: 20
            cutBottomLeft: 20
            Behavior on strokeColor { CAnim {} }
        }
    }

    // ── CornerAccents (tab-aware) ────────────────────────────────
    CornerAccents {
        x: 0; y: root.slideY
        width: parent.width
        height: parent.height
        accentColor: root.tabAccent
        size: 12
        thickness: 1
        showTopLeft: true
        showTopRight: false
        showBottomLeft: false
        showBottomRight: true
        opacity: 0.85
        Behavior on accentColor { CAnim {} }
    }

    // ── Scanlines ────────────────────────────────────────────────
    ScanlineOverlay {
        x: 0; y: root.slideY
        width: parent.width
        height: parent.height
        opacity: 0.08
    }

    // ── Content ──────────────────────────────────────────────────
    Item {
        id: content
        x: 0; y: root.slideY
        width: parent.width
        height: parent.height

        // Close button
        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            text: "✕"
            font.pixelSize: 24
            color: CP.red
            z: 10
            HoverHandler { id: closeHover }
            opacity: closeHover.hovered ? 1 : 0.7
            Behavior on opacity { CAnim {} }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeRequested()
            }
        }

        // Header (always visible)
        AudioHeader {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 4
            anchors.rightMargin: 24
            expanded: AudioControlState.expanded
            onExpandToggleRequested: AudioControlState.expanded = !AudioControlState.expanded
            onCloseRequested: root.closeRequested()
        }

        // Tab bar (only when expanded)
        AudioTabBar {
            id: tabBar
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 8
            anchors.topMargin: 6
            opacity: AudioControlState.expanded ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }

        // Tab content (lazy via Loader)
        Loader {
            id: tabLoader
            anchors.top: tabBar.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 8
            anchors.bottomMargin: 24
            anchors.topMargin: 14
            active: AudioControlState.expanded
            opacity: active ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            sourceComponent: {
                if (AudioControlState.activeTab === "outputs") return outputsComp
                if (AudioControlState.activeTab === "inputs")  return inputsComp
                if (AudioControlState.activeTab === "apps")    return appsComp
                return eqComp
            }
        }

        Component { id: outputsComp; Tabs.OutputsTab {} }
        Component { id: inputsComp;  Tabs.InputsTab  {} }
        Component { id: appsComp;    Tabs.AppsTab    {} }
        Component { id: eqComp;      Tabs.EqualizerTab {} }
    }

    // ── Keyboard shortcuts ───────────────────────────────────────
    focus: true
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.closeRequested()
            event.accepted = true
        } else if (event.key === Qt.Key_E) {
            AudioControlState.expanded = !AudioControlState.expanded
            event.accepted = true
        } else if (event.key === Qt.Key_Space || event.key === Qt.Key_M) {
            if (AudioControlState.defaultSink) {
                AudioControlState.toggleMute(AudioControlState.defaultSink)
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            if (AudioControlState.defaultSink && AudioControlState.defaultSink.audio) {
                AudioControlState.setVolume(AudioControlState.defaultSink, AudioControlState.defaultSink.audio.volume - 0.02)
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            if (AudioControlState.defaultSink && AudioControlState.defaultSink.audio) {
                AudioControlState.setVolume(AudioControlState.defaultSink, AudioControlState.defaultSink.audio.volume + 0.02)
            }
            event.accepted = true
        } else if (event.key === Qt.Key_1) { AudioControlState.activeTab = "outputs"; event.accepted = true }
        else if (event.key === Qt.Key_2) { AudioControlState.activeTab = "inputs";  event.accepted = true }
        else if (event.key === Qt.Key_3) { AudioControlState.activeTab = "apps";    event.accepted = true }
        else if (event.key === Qt.Key_4) { AudioControlState.activeTab = "eq";      event.accepted = true }
        else if (event.key === Qt.Key_Tab) {
            var idx = ["outputs","inputs","apps","eq"].indexOf(AudioControlState.activeTab)
            var dir = (event.modifiers & Qt.ShiftModifier) ? -1 : 1
            AudioControlState.activeTab = ["outputs","inputs","apps","eq"][(idx + dir + 4) % 4]
            event.accepted = true
        }
    }
}
