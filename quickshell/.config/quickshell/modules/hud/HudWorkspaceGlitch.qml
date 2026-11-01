// HudWorkspaceGlitch.qml -- a short glitch over one screen whenever its workspace changes:
// a frame of the screen, torn by the shell's glitch shader. Takes no input.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../common"

Scope {
    id: root
    required property var screen

    readonly property int wsId: Hyprland.monitorFor(root.screen)?.activeWorkspace?.id ?? -1
    property int _last: -1

    // The shell's entrance: once its surfaces are up
    Timer {
        interval: 600
        running: true
        onTriggered: if (HudState.enabled) root.burst()
    }

    onWsIdChanged: {
        if (HudState.enabled && root._last !== -1 && root.wsId !== -1)
            root.burst()
        root._last = root.wsId
    }

    function burst() {
        anim.restart()
    }

    PanelWindow {
        id: win
        screen: root.screen
        // Mapped only for the burst: an idle overlay would still sit above fullscreen games
        visible: false
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-ws-glitch"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}

        ScreencopyView {
            id: view
            anchors.fill: parent
            captureSource: root.screen
            live: false
            layer.enabled: true
            visible: true
            opacity: 0
        }
        ShaderEffectSource {
            id: frame
            sourceItem: view
            hideSource: false
            live: true
        }
        ShaderEffect {
            id: fx
            anchors.fill: parent
            visible: false
            property var source: frame
            property real iTime: 0
            fragmentShader: "../../shaders/glitch.frag.qsb"
        }
    }

    SequentialAnimation {
        id: anim
        PropertyAction { target: win; property: "visible"; value: true }
        ScriptAction { script: view.captureFrame() }
        // The view shows its previous frame until the new one lands
        PauseAnimation { duration: 40 }
        PropertyAction { target: fx; property: "visible"; value: true }
        NumberAnimation { target: fx; property: "iTime"; from: 0; to: 8; duration: 130; easing.type: Easing.InCubic }
        NumberAnimation { target: fx; property: "iTime"; from: 8; to: 0; duration: 150; easing.type: Easing.OutCubic }
        PropertyAction { target: fx; property: "visible"; value: false }
        PropertyAction { target: win; property: "visible"; value: false }
    }
}
