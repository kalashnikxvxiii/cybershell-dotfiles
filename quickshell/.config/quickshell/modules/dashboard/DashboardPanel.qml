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
                y: vhsOverlay.bandY(vhsTicker.elapsed)

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

            // The band's pass timeline as [duration ms, y from, y to] segments
            // (equal from/to = hold). Stepped by a Ticker: as NumberAnimations
            // these passes rendered the dashboard at the monitor's full refresh
            // rate, for a band drawn at 4.5% opacity
            Ticker { id: vhsTicker; running: root.drawerState.dashboardOpen }

            function bandY(t) {
                const H = vhsOverlay.height
                const top = -vhsBand.height
                const bot = H + vhsBand.height
                const segs = [
                    // Pass 1: smooth scroll, no glitch
                    [3200, top, bot], [480, bot, bot],
                    // Pass 2: forward jump mid-run
                    [1900, top, 0.38 * H], [38, 0.65 * H, 0.65 * H], [1100, 0.65 * H, bot], [350, bot, bot],
                    // Pass 3: backward jump (VHS tracking artifact)
                    [2100, top, 0.52 * H], [45, 0.18 * H, 0.18 * H], [2400, 0.18 * H, bot], [420, bot, bot],
                    // Pass 4: double micro-jump forward
                    [1400, top, 0.27 * H], [28, 0.46 * H, 0.46 * H], [900, 0.46 * H, 0.66 * H],
                    [20, 0.77 * H, 0.77 * H], [620, 0.77 * H, bot], [600, bot, bot]
                ]
                let total = 0
                for (let i = 0; i < segs.length; i++) total += segs[i][0]
                let r = t % total
                for (let i = 0; i < segs.length; i++) {
                    if (r < segs[i][0])
                        return segs[i][1] + (segs[i][2] - segs[i][1]) * (r / segs[i][0])
                    r -= segs[i][0]
                }
                return bot
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
        height: Math.max(0, parent.height - 38 - 32 - 4)
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

        // Clip at the panel edge: the closed drawer must not show through the translucent panel.
        // Extra room: 10px left for the hover slide, 20px bottom for the shadow
        Item {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -20
            width: parent.width + 10
            clip: true

            Item{
                id: lyricsContent
                anchors.right: parent.right
                anchors.top: parent.top
                width: lyricsDrawer.width
                height: lyricsDrawer.height

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
