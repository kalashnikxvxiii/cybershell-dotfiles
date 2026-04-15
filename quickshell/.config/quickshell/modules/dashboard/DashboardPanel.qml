// DashboardPanel.qml — dashboard panel with border effects and scanlines

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import "../../common/Colors.js" as CP
import "../../common"
import "../../common/effects"
import "."

Item {
    id: root

    required property DrawerState drawerState

    property int    panelWidth:     dashContent.implicitWidth
    property int    panelHeight:    dashContent.implicitHeight

    readonly property int inputHeight: drawerState.dashboardOpen ? panelHeight : 0
    // Lyrics drawer extent (for interactions hit area)
    readonly property real lyricsDrawerExtent: lyricsDrawer.visible ? -lyricsDrawer.x : 0
    readonly property real lyricsDrawerRelY: lyricsDrawer.y
    readonly property real lyricsDrawerRelH: lyricsDrawer.height
    readonly property PersistentProperties dashState: PersistentProperties {
        property int currentTab: 0
        property var currentDate: new Date()
        reloadableId: "dashboardState"
    }

    implicitWidth: panelWidth
    implicitHeight: 0
    visible: height > 0

    states: State {
        name: "visible"
        when: root.drawerState.dashboardOpen
        PropertyChanges { root.implicitWidth: root.panelWidth; root.implicitHeight: root.panelHeight }
    }

    transitions: [
        Transition {
            from: ""; to: "visible"
            Anim { target: root; property: "implicitHeight"; duration: 260 }
        },
        Transition {
            from: "visible"; to: ""
            Anim { target: root; property: "implicitHeight"; duration: 200; easing.type: Easing.InCubic }
        },
        Transition {
            from: ""; to: "visible"
            Anim { target: root; property: "implicitWidth"; duration: 260 }
        },
        Transition {
            from: "visible"; to: ""
            Anim { target: root; property: "implicitWidth"; duration: 200; easing.type: Easing.InCubic }
        }
    ]

    // Masked content (background + scanlines + dashboard)
    Item {
        id: panelContent
        anchors.fill: parent

        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: shapeMask
        }

        // Background
        CutShape {
            anchors.fill: parent
            fillColor: Colours.moduleBg
            cutTopRight: 32; cutBottomLeft: 32
        }

        // Content
        DashboardContent {
            id: dashContent
            anchors.fill: parent
            drawerState: root.drawerState
            dashState: root.dashState
        }

        // Scanlines
        Item {
            anchors.fill: parent
            clip: true
            opacity: 0.08
            ScanlineOverlay { opacity: 0.08 }
        }

        // VHS scanline band
        Item {
            id: vhsOverlay
            anchors.fill: parent
            clip: true
            opacity: 0.045

            Item {
                id: vhsBand
                width: parent.width
                height: 42

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0;  color: "transparent" }
                        GradientStop { position: 0.28; color: Qt.rgba(0.08, 0.92, 0.84) }
                        GradientStop { position: 0.72; color: Qt.rgba(0.06, 0.75, 0.68) }
                        GradientStop { position: 1.0;  color: "transparent" }
                    }
                }
            }

            SequentialAnimation {
                running: root.drawerState.dashboardOpen
                loops: Animation.Infinite

                // Pass 1: smooth scroll, no glitch
                PropertyAction  { target: vhsBand; property: "y"; value: -vhsBand.height }
                NumberAnimation { target: vhsBand; property: "y"; to: vhsOverlay.height + vhsBand.height; duration: 3200; easing.type: Easing.Linear }
                PauseAnimation  { duration: 480 }

                // Pass 2: forward jump mid-run
                PropertyAction  { target: vhsBand; property: "y"; value: -vhsBand.height }
                NumberAnimation { target: vhsBand; property: "y"; to: vhsOverlay.height * 0.38; duration: 1900; easing.type: Easing.Linear }
                ScriptAction    { script: vhsBand.y = vhsOverlay.height * 0.65 }
                PauseAnimation  { duration: 38 }
                NumberAnimation { target: vhsBand; property: "y"; to: vhsOverlay.height + vhsBand.height; duration: 1100; easing.type: Easing.Linear }
                PauseAnimation  { duration: 350 }

                // Pass 3: backward jump (VHS tracking artifact)
                PropertyAction  { target: vhsBand; property: "y"; value: -vhsBand.height }
                NumberAnimation { target: vhsBand; property: "y"; to: vhsOverlay.height * 0.52; duration: 2100; easing.type: Easing.Linear }
                ScriptAction    { script: vhsBand.y = vhsOverlay.height * 0.18 }
                PauseAnimation  { duration: 45 }
                NumberAnimation { target: vhsBand; property: "y"; to: vhsOverlay.height + vhsBand.height; duration: 2400; easing.type: Easing.Linear }
                PauseAnimation  { duration: 420 }

                // Pass 4: double micro-jump forward
                PropertyAction  { target: vhsBand; property: "y"; value: -vhsBand.height }
                NumberAnimation { target: vhsBand; property: "y"; to: vhsOverlay.height * 0.27; duration: 1400; easing.type: Easing.Linear }
                ScriptAction    { script: vhsBand.y = vhsOverlay.height * 0.46 }
                PauseAnimation  { duration: 28 }
                NumberAnimation { target: vhsBand; property: "y"; to: vhsOverlay.height * 0.66; duration: 900; easing.type: Easing.Linear }
                ScriptAction    { script: vhsBand.y = vhsOverlay.height * 0.77 }
                PauseAnimation  { duration: 20 }
                NumberAnimation { target: vhsBand; property: "y"; to: vhsOverlay.height + vhsBand.height; duration: 620; easing.type: Easing.Linear }
                PauseAnimation  { duration: 600 }
            }
        }

        // Mask (same polygon filled white, invisible)
        CutShape {
            id: shapeMask
            layer.enabled: true
            visible: false
            width: parent.width
            height: parent.height
            fillColor: "white"
            cutTopRight: 32; cutBottomLeft: 32
        }
    }

    // Border (outside the mask — full stroke, not clipped)
    CutShape {
        anchors.fill: parent
        strokeColor: CP.yellow
        strokeWidth: 1
        inset: 0.5
        cutTopRight: 32; cutBottomLeft: 32
    }

    // CornerAccents — only on the NON-cut corners (top-left and bottom-right)
    CornerAccents {
        anchors.fill: parent
        accentColor:     CP.yellow
        size:            14
        showTopLeft:     true
        showTopRight:    false
        showBottomLeft:  false
        showBottomRight: true
        opacity:         0.75
    }

    // Lyrics drawer - slides left from the panel edge
    Item {
        id: lyricsDrawer

        readonly property bool isActive: root.drawerState.dashboardOpen
                                        && root.dashState.currentTab === 1
        readonly property int drawerW: 320
        readonly property int peekPx: 20
        property bool lyricsOpen: false
        property bool _savedOpen: false

        Timer {
            id: lyricsClosingTimer
            interval: 5000
            onTriggered: lyricsDrawer.lyricsOpen = false
        }

        anchors.right: parent.left
        anchors.rightMargin: -1
        anchors.top: parent.top
        anchors.topMargin: 38
        height: Math.max(0, parent.height - 12 - 320)
        width: root.dashState.currentTab === 1 ? (lyricsOpen ? drawerW : peekPx) : 0
        z: -1
        visible: root.dashState.currentTab === 1
        onVisibleChanged: {
            if (!visible) {
                _savedOpen = lyricsOpen
                lyricsClosingTimer.restart()
            } else {
                if (lyricsClosingTimer.running) {
                    lyricsOpen = _savedOpen
                    lyricsClosingTimer.stop()
                }
            }
        }

        Behavior on width { Anim { duration: 240 } }

        Item{
            id: lyricsContent
            anchors.fill: parent
            //clip: true

            transform: Translate {
                x: openHandle.containsMouse && !lyricsDrawer.lyricsOpen ? -10 : 0
                Behavior on x { NumberAnimation { duration: 350; easing.type: Easing.OutBounce } }
            }

            // Content anchored left -> slide emerges from the right edge (of the panel border)
            Item {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: lyricsDrawer.drawerW

                CutShape {
                    anchors.fill: parent
                    fillColor: CP.alpha(CP.white, 0.12)
                    cutTopLeft: 20
                    cutBottomLeft: 20
                }

                CutShape {
                    anchors.fill: parent
                    fillColor: CP.moduleBg
                    strokeColor: CP.yellow
                    strokeWidth: 2
                    inset: 0.5
                    cutTopLeft: 20
                    cutBottomLeft: 20
                    showRight: false
                }

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: CP.alpha(CP.cyan, 0.05)
                    shadowBlur: 0.7
                    shadowOpacity: 0.3
                    shadowHorizontalOffset: 10
                    shadowVerticalOffset: 15
                }
            }
            // Lyrics content (outside layer/MultiEffect so text doesn't get the glow treatment)
            DashLyricsView {
                id: lyricsView
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.top: parent.top
                anchors.topMargin: 16
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 16
                width: lyricsDrawer.drawerW - 32
                active: lyricsDrawer.isActive && lyricsDrawer.lyricsOpen
                player: Players.active
                fontSize: Math.min((lyricsDrawer.drawerW - 32) * 0.12, height * 0.12)
                topFraction: 0.04
                bottomMarginPx: 12
            }

            // Scanlines
            Item {
                anchors.fill: parent
                clip: true
                opacity: 0.08
                ScanlineOverlay { opacity: 0.08 }
            }
        }

        // Clickable handle - opens the drawer
        MouseArea {
            id: openHandle
            visible: !lyricsDrawer.lyricsOpen
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: lyricsDrawer.peekPx
            z: 10
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: lyricsDrawer.lyricsOpen = true

            Item {
                anchors.fill: parent
                opacity: parent.containsMouse ? 0.15 : 0
                Behavior on opacity { NumberAnimation { duration: 100 } }

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: openHandleMask
                }

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Colours.accentPrimary }
                    }
                }
                CutShape {
                    id: openHandleMask
                    visible: false
                    layer.enabled: true
                    anchors.fill: parent
                    fillColor: "white"
                    cutTopLeft: 20
                    cutBottomLeft: 20
                }
            }
        }

        // Clickable handle - closes the drawer
        MouseArea {
            visible: lyricsDrawer.lyricsOpen
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: lyricsDrawer.peekPx
            z: 10
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: lyricsDrawer.lyricsOpen = false

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Colours.accentPrimary }
                }
                opacity: parent.containsMouse ? 0.15 : 0
                Behavior on opacity { NumberAnimation { duration: 100 } }
            }
        }
    }
}
