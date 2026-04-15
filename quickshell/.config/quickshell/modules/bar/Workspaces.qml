// Workspaces.qml — Hyprland workspaces cyberpunk HUD

import QtCore
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import "../../common/Colors.js" as CP
import "../../common"

Item {
    id: root
    property var barScreen

    implicitHeight: 24
    implicitWidth:  wsRow.implicitWidth + 12

    property var monitor: barScreen ? Hyprland.monitorFor(barScreen) : null
    // ID of the workspace currently visible on this monitor.
    property int activeWsId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1

    // Workspaces for this monitor, sorted by slot number ascending.
    property var workspaces: {
        var all = Hyprland.workspaces.values
        var result = []
        for (var i = 0; i < all.length; i++) {
            var ws = all[i]
            if (!root.monitor || (ws.monitor && ws.monitor.name === root.monitor.name))
                result.push(ws)
        }
        result.sort(function(a, b) {
            return (parseInt(a.name) || 0) - (parseInt(b.name) || 0)
        })
        return result
    }

    // ── Icon cache ──────────────────────────────────────────────────────
    // Map the class -> absolute path. "" = lookup completed with no results.
    // null = not required yet (not in the map).
    property var iconCache: ({})
    property int iconCacheVersion: 0
    property var lookupQueue: []
    property bool lookupBusy: false

    // ── Icon overrides from AppLauncher ──────────────────────────────
    property var iconOverrides: ({})

    Process {
        id: overrideLoader
        command: ["python3", "-c",
                "import json,sys\n" +
                "d=json.load(open(sys.argv[1]))\n" +
                "pairs=[]\n" +
                "for a in d.get('apps',[]):\n" +
                " i=a.get('icon','')\n" +
                " if not i: continue \n" +
                " for k in [a.get('appId',''), a.get('exec','')]:\n" +
                "   if k: pairs.append(k+'='+i)\n" +
                "print('|'.join(pairs))",
                Qt.resolvedUrl("../../modules/dashboard/applauncher-order.json").toString().replace("file://", "")]
        running: false
        stdout: SplitParser {
            onRead: data => {
                let map = {}
                let pairs = data.trim().split("|")
                for (let i = 0; i < pairs.length; i++) {
                    let kv = pairs[i].split("=")
                    if (kv.length >= 2) map[kv[0]] = kv.slice(1).join("=")
                }
                root.iconOverrides = map
                // Overrides the cachefor keys with absolute path override
                let keys = Object.keys(map)
                for (let k = 0; k < keys.length; k++) {
                    if (map[keys[k]].startsWith("/")) {
                        root.iconCache[keys[k]] = map[keys[k]]
                    }
                }
                root.iconCacheVersion++
            }
        }
    }

    Timer {
        interval: 5000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: overrideLoader.running = true
    }

    function requestIcon(cls) {
        if (!cls || cls.length === 0) return
        // Override check from AppLauncher
        if (cls in root.iconOverrides) {
            let ov = root.iconOverrides[cls]
            if (ov.startsWith("/")) {
                if (root.iconCache[cls] === ov) return
                root.iconCache[cls] = ov
                root.iconCacheVersion++
                return 
            }
            // If the override is a theme, use it as a lookup key
            cls = ov
        }
        if (cls in root.iconCache) return
        if (root.lookupQueue.indexOf(cls) >= 0) return
        root.iconCache[cls] = null // mark as "pending"
        root.lookupQueue.push(cls)
        root.drainQueue()
    }

    function drainQueue() {
        if (root.lookupBusy || root.lookupQueue.length === 0) return
        var cls = root.lookupQueue.shift()
        root.lookupBusy = true
        iconProc.pendingClass = cls
        iconProc.command = [
            "python3", 
            Qt.resolvedUrl("../../scripts/icon-lookup.py").toString().replace("file://", ""),
            cls
        ]
        iconProc.running = true
    }

    Process {
        id: iconProc
        property string pendingClass: ""
        running: false

        stdout: SplitParser {
            onRead: function(line) {
                var path = line.trim()
                root.iconCache[iconProc.pendingClass] = path
                root.iconCacheVersion++
            }
        }

        onExited: {
            // If the process exited with no output (icon not found),
            // bump the version counter anyway to unblock bindings.
            if (root.iconCache[iconProc.pendingClass] === null) {
                root.iconCache[iconProc.pendingClass] = ""
                root.iconCacheVersion++
            }
            root.lookupBusy = false
            root.drainQueue()
        }
    }

    // ── Layout ────────────────────────────────────────────────────────────
    Row {
        id: wsRow
        anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
        spacing: 4

        Repeater {
            model: root.workspaces

            delegate: Item {
                id: wsBtn
                // Glitch animation
                transform: Translate { id: wsBtnShift; x: 0 }

                required property var modelData

                // true when it has open windows and is not in urgent state
                property bool showIcons: !isUrgent && winCount > 0
                // isActive: this workspace is the active one ON THIS BAR'S MONITOR
                property bool isActive: modelData.id === root.activeWsId
                property bool isUrgent: modelData.urgent ?? false
                // Uses native HyprlandWorkspace toplevels (no polling needed)
                property int  winCount: modelData.toplevels.values.length
                property bool isEmpty: winCount === 0

                property string wsIcon:
                    isUrgent ? "⚡" :
                    isActive  ? "●" :
                    isEmpty   ? "○" : "·"

                property color baseColor:
                    isUrgent ? CP.red    :
                    isActive  ? CP.yellow :
                                CP.cyan

                implicitWidth: showIcons
                    ? Math.min(wsBtn.winCount, 3) * 10 + (Math.min(winCount, 3) - 1) * 2 + 16
                    : Math.max(wsLabel.implicitWidth + 24, Math.min(winCount, 5) * 6 + 30)
                implicitHeight: 16

                // Cut-corner shape (same pattern as the dashboard panel, cut=4)
                CutShape {
                    id: wsBg
                    anchors.fill: parent
                    fillColor: Qt.rgba(
                        wsBtn.baseColor.r, wsBtn.baseColor.g, wsBtn.baseColor.b,
                        hoverHandler.hovered ? 0.18 : (wsBtn.isActive ? 0.12 : 0.08)
                    )
                    strokeColor: Qt.rgba(
                        wsBtn.baseColor.r, wsBtn.baseColor.g, wsBtn.baseColor.b,
                        wsBtn.isActive ? 0.55 : 0.22
                    )
                    strokeWidth: 1
                    inset: 0.5
                    cutTopRight: 4
                    cutBottomLeft: 4
                }

                // ── Label (empty workspace or no icons) ──────────────────
                Text {
                    id: wsLabel
                    visible: !wsBtn.showIcons
                    anchors { top: parent.top; topMargin: 1; horizontalCenter: parent.horizontalCenter }
                    text:               wsBtn.wsIcon
                    font.family:        "Oxanium"
                    font.pixelSize:     11
                    font.letterSpacing: 2
                    color:              wsBtn.baseColor
                    transform: Translate { id: wsLabelShift; x: 0 }

                    // Simulated glow
                    Text {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: 1
                        anchors.verticalCenterOffset:   1
                        text:   wsLabel.text
                        font:   wsLabel.font
                        color:  Qt.rgba(Qt.color(wsBtn.baseColor).r, Qt.color(wsBtn.baseColor).g, Qt.color(wsBtn.baseColor).b, 0.35)
                        z: -1
                    }
                }

                // ── App icons ──────────────────────────────────────────
                Row {
                    id: iconsRow
                    visible: wsBtn.showIcons
                    anchors { verticalCenter: parent.verticalCenter; horizontalCenter: parent.horizontalCenter }
                    spacing: 2

                    Repeater {
                        model: Math.min(wsBtn.winCount, 3) // max 3 icons

                        delegate: Item {
                            id: iconSlot
                            required property int index
                            width: 14; height: 14

                            property string appClass: {
                                var win = wsBtn.modelData.toplevels.values[index]
                                return win && win.wayland ? win.wayland.appId : ""
                            }
                            
                            property string iconPath: {
                                var _ = root.iconCacheVersion // reactive dependency
                                return root.iconCache[appClass] || ""
                            }

                            Component.onCompleted: root.requestIcon(appClass)
                            onAppClassChanged: root.requestIcon(appClass)

                            Image {
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                source: iconSlot.iconPath.length > 0 ? "file://" + iconSlot.iconPath : ""
                                visible: status === Image.Ready
                                sourceSize.width: width
                                sourceSize.height: height
                            }
                        }
                    }
                }

                // ── Urgent blink ──────────────────────────────────────────
                SequentialAnimation on opacity {
                    running: wsBtn.isUrgent
                    loops:   Animation.Infinite
                    PropertyAction { value: 1.0 }
                    PauseAnimation { duration: 280 }
                    PropertyAction { value: 0.15 }
                    PauseAnimation { duration: 280 }
                }

                // ── Glitch on hover ───────────────────────────────────────
                SequentialAnimation {
                    id: btnGlitch
                    running: false; loops: 1

                    PropertyAction { target: wsBtn;      property: "baseColor"; value: wsBtn.baseColor }
                    PropertyAction { target: wsBtn;      property: "opacity"; value: 1.0 }
                    PropertyAction { target: wsBtnShift; property: "x";     value: 0 }
                    PauseAnimation { duration: 42 }
                    PropertyAction { target: wsBtn;      property: "baseColor"; value: CP.magenta }
                    PropertyAction { target: wsBtn;      property: "opacity"; value: 0.55 }
                    PropertyAction { target: wsBtnShift; property: "x";     value: 4 }
                    PauseAnimation { duration: 42 }
                    PropertyAction { target: wsBtn;      property: "baseColor"; value: CP.yellow }
                    PropertyAction { target: wsBtn;      property: "opacity"; value: 1.0 }
                    PropertyAction { target: wsBtnShift; property: "x";     value: -3 }
                    PauseAnimation { duration: 42 }
                    PropertyAction { target: wsBtn;      property: "baseColor"; value: wsBtn.baseColor }
                    PropertyAction { target: wsBtn;      property: "opacity"; value: 0.7 }
                    PropertyAction { target: wsBtnShift; property: "x";     value: 2 }
                    PauseAnimation { duration: 42 }
                    PropertyAction { target: wsBtn;      property: "baseColor"; value: CP.magenta }                    
                    PropertyAction { target: wsBtn;      property: "opacity"; value: 1.0 }
                    PropertyAction { target: wsBtnShift; property: "x";     value: -1 }
                    PauseAnimation { duration: 42 }
                    PropertyAction { target: wsBtn;      property: "baseColor"; value: wsBtn.baseColor }                    
                    PropertyAction { target: wsBtn;      property: "opacity"; value: 1.0 }
                    PropertyAction { target: wsBtnShift; property: "x";     value: 0 }
                    PauseAnimation { duration: 88 }
                }

                HoverHandler {
                    id: hoverHandler
                    onHoveredChanged: if (hovered && !btnGlitch.running) btnGlitch.restart()
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton)
                            Hyprland.dispatch("workspace name:" + wsBtn.modelData.name)
                        else if (mouse.button === Qt.MiddleButton) {
                            var tops = wsBtn.modelData.toplevels.values
                            if (tops.length > 0)
                                Hyprland.dispatch("closewindow address:" + tops[tops.length - 1].address)
                        }
                    }
                    onWheel: wheel => {
                        var wsList = root.workspaces
                        if (wsList.length === 0) return

                        var currentIdx = -1
                        for (var i = 0; i < wsList.length; i++) {
                            if (wsList[i].id === root.activeWsId) {
                                currentIdx = i
                                break
                            }
                        }
                        if (currentIdx === -1) return

                        var nextIdx = wheel.angleDelta.y > 0
                            ? currentIdx - 1
                            : currentIdx + 1

                        nextIdx = (nextIdx + wsList.length) % wsList.length
                        if (nextIdx === currentIdx) return

                        Hyprland.dispatch("workspace name:" + wsList[nextIdx].name)
                    }
                }
            }
        }
    }
}
