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
import Quickshell

FocusScope {
    id: root
    signal closeRequested()

    // -- Sizing -----------------------------------------
    readonly property int compactW:  220
    readonly property int compactH:  140
    readonly property int expandedW: 420
    readonly property int expandedMaxH: 620

    readonly property bool animating: closeT.running || collapseT.running || growT.running
    readonly property int chromeH: 4 + header.height + 6 + tabBar.height + 14 + 24
    readonly property Item currentTabItem: {
        switch (AudioControlState.activeTab) {
            case "outputs": return outTab.item
            case "inputs":  return inTab.item
            case "apps":    return appsTab.item
        }
        return eqTab.item
    }
    readonly property int expandedH: {
        var c = currentTabItem ? currentTabItem.implicitHeight : 0
        return Math.max(compactH, Math.min(expandedMaxH, chromeH + c))
    }
    property bool open: false
    readonly property int targetW: AudioControlState.expanded ? expandedW : compactW

    width:  targetW
    height: 0
    visible: height > 0

    // compact ... expanded while popup is still open
    Behavior on width  { Anim { duration: AudioControlState.expanded ? 260 : 200; easing.type: AudioControlState.expanded ? Easing.OutQuart : Easing.InCubic } }

    // apertura / chiusura - stessa cinetica di DashboardPanel
    states: [
        State {
            name: "compact"
            when: root.open && !AudioControlState.expanded
            PropertyChanges { root.height: root.compactH }
        },
        State {
            name: "expanded"
            when: root.open && AudioControlState.expanded
            PropertyChanges { root.height: root.expandedH }
        }
    ]

    Binding {
        target: AudioControlState
        property: "popupOpen"
        value: root.open
    }

    transitions: [
        // Closing, from any state
        Transition {
            id: closeT
            from: "*"; to: ""
            SequentialAnimation {
                Anim { target: root; property: "height"; duration: 200; easing.type: Easing.InCubic }
                ScriptAction { script: root._evictInactiveTabs() }
            }
        },
        // Collpsing, expanded -> compact
        Transition {
            id: collapseT
            from: "expanded"; to: "compact"
            Anim { target: root; property: "height"; duration: 200; easing.type: Easing.InCubic }
        },
        // Opening, and expansion compact -> expanded
        Transition {
            id: growT
            from: "*"; to: "*"
            Anim { target: root; property: "height"; duration: 260 }
        }
    ]

    function _evictInactiveTabs() {
        if (AudioControlState.activeTab !== "outputs") outTab.everShown = false
        if (AudioControlState.activeTab !== "inputs") inTab.everShown = false
        if (AudioControlState.activeTab !== "apps") appsTab.everShown = false
        if (AudioControlState.activeTab !== "eq") eqTab.everShown = false
    }

    // -- Tab-aware accent -------------------------------------
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

    // -- Card background --------------------------------------------
    Item {
        id: card
        x: 0; y: 0
        width: parent.width
        height: parent.height

        layer.enabled: !root.animating
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
            cutBottomLeft: 32
            Behavior on strokeColor { CAnim {} }
        }
    }

    // -- CornerAccents (tab-aware) --------------------------------
    CornerAccents {
        x: 0; y: 0
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

    // -- Scanlines ---------------------------------------
    ScanlineOverlay {
        x: 0; y: 0
        width: parent.width
        height: parent.height
        opacity: 0.08
    }

    // -- Content --------------------------------------------
    Item {
        id: content
        x: 0; y: 0
        width: parent.width
        height: parent.height

        // Header (always visible)
        AudioHeader {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 4
            anchors.rightMargin: 8
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
        Item {
            id: tabHost
            anchors.top: tabBar.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 8
            anchors.bottomMargin: 24
            anchors.topMargin: 14
            opacity: AudioControlState.expanded ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            Loader {
                id: outTab
                anchors.fill: parent
                property bool everShown: false
                visible: AudioControlState.activeTab === "outputs"
                onVisibleChanged: if (visible) everShown = true
                Component.onCompleted: if (visible) everShown = true
                active: everShown
                asynchronous: true
                sourceComponent: outputsComp
            }
            Loader {
                id: inTab
                anchors.fill: parent
                property bool everShown: false
                visible: AudioControlState.activeTab === "inputs"
                onVisibleChanged: if (visible) everShown = true
                active: everShown
                asynchronous: true
                sourceComponent: inputsComp
            }
            Loader {
                id: appsTab
                anchors.fill: parent
                property bool everShown: false
                visible: AudioControlState.activeTab === "apps"
                onVisibleChanged: if (visible) everShown = true
                active: everShown
                asynchronous: true
                sourceComponent: appsComp
            }
            Loader {
                id: eqTab
                anchors.fill: parent
                property bool everShown: false
                visible: AudioControlState.activeTab === "eq"
                onVisibleChanged: if (visible) everShown = true
                active: everShown
                asynchronous: true
                sourceComponent: eqComp
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
