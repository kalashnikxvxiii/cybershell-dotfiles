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

    // Workspaces for this monitor: solo quelli con finestre o quello attivo.
    // Hyprland tiene comunque tutti i workspace pre-creati dal plugin split-monitor-workspaces
    // (la chiave enable_persistent_workspaces non è esposta come config key in Lua mode v1.2.0,
    // quindi non possiamo dirgli "non pre-creare"). Filtro qui per restituire l'UX desiderata.
    property var workspaces: {
        var all = Hyprland.workspaces.values
        var result = []
        for (var i = 0; i < all.length; i++) {
            var ws = all[i]
            // Special workspaces carry negative ids and must never surface as tiles.
            if (ws.id < 0)
                continue
            if (root.monitor && ws.monitor && ws.monitor.name !== root.monitor.name)
                continue
            if (!root.monitor && ws.monitor)  // catch-all when no barScreen
                continue
            var hasWindows = ws.toplevels && ws.toplevels.values.length > 0
            var isActive   = ws.id === root.activeWsId
            if (hasWindows || isActive)
                result.push(ws)
        }
        result.sort(function(a, b) {
            return (parseInt(a.name) || 0) - (parseInt(b.name) || 0)
        })
        return result
    }

    property var _pendingWs: null

    // -- Drag reorder --------------------------------------------
    // The tiles are laid out by a Row, so their order lives in a ListModel
    // rather than in the computed `workspaces` array: reassigning an array
    // model makes the Repeater rebuild every delegate, which would both kill
    // the positioner's move animation and drop the drag in progress.
    ListModel { id: wsModel }

    property int  dragWsId:     -1
    property bool dragging:     false
    // Pointer position in wsRow coordinates.
    property real dragPointerX: 0
    // Tile widths by workspace id, published by the delegates. Only ever read
    // inside functions, so mutating it without a change signal is fine.
    property var  _tileW:       ({})
    property var  _origOrder:   null

    function _wsById(id) {
        var all = Hyprland.workspaces.values
        for (var i = 0; i < all.length; i++)
            if (all[i].id === id) return all[i]
        return null
    }

    function _currentOrder() {
        var o = []
        for (var i = 0; i < wsModel.count; i++) o.push(wsModel.get(i).wsId)
        return o
    }

    function _indexOfId(id) {
        for (var i = 0; i < wsModel.count; i++)
            if (wsModel.get(i).wsId === id) return i
        return -1
    }

    // Reconciles the stable model with the live list, in place. Never runs
    // during a drag: while the finger is down the model IS the order.
    // What each workspace is about to contain, shown before Hyprland has
    // actually moved anything. Keyed by workspace id; null when idle.
    property var _optimistic: null

    // The drop itself must not animate. By then the row already shows the
    // arrangement the user made: the tiles slide back to their numeric slots
    // while the contents slide the opposite way, and the two crossing motions
    // cancel out to exactly the picture that was already on screen. Animating
    // them just shows the user a shuffle that changes nothing.
    property bool _silentReorder: false

    Timer {
        id: _silentGuard
        interval: 60
        onTriggered: root._silentReorder = false
    }

    // True once every workspace really holds what the drop promised.
    function _optimisticSettled() {
        if (!root._optimistic) return true
        for (var id in root._optimistic) {
            var ws   = root._wsById(parseInt(id))
            var want = root._optimistic[id]
            var have = ws ? ws.toplevels.values : []
            if (have.length !== want.length) return false
            for (var i = 0; i < want.length; i++) {
                var found = false
                for (var j = 0; j < have.length; j++)
                    if (have[j].address === want[i].address) { found = true; break }
                if (!found) return false
            }
        }
        return true
    }

    function _syncModel() {
        if (root.dragging) return
        if (root._optimistic) {
            if (!root._optimisticSettled()) return
            root._optimistic = null
            _optimisticGuard.stop()
        }
        var list = root.workspaces
        for (var i = wsModel.count - 1; i >= 0; i--) {
            var gone = true
            for (var j = 0; j < list.length; j++)
                if (list[j].id === wsModel.get(i).wsId) { gone = false; break }
            if (gone) wsModel.remove(i)
        }
        for (var k = 0; k < list.length; k++) {
            var at = root._indexOfId(list[k].id)
            if (at === -1)     wsModel.insert(k, { wsId: list[k].id })
            else if (at !== k) wsModel.move(at, k, 1)
        }
    }

    onWorkspacesChanged: root._syncModel()

    // Drops the promise if the moves never arrive, so a failed commit cannot
    // leave the tiles showing windows that are not there.
    Timer {
        id: _optimisticGuard
        interval: 2500
        onTriggered: {
            root._optimistic = null
            root._syncModel()
        }
    }

    // Numeric order, keeping every tile currently on screen. Workspaces empty
    // out and are destroyed while the windows are in flight, and re-syncing
    // from the live list through that churn is what made the row flicker.
    function _reorderNumeric() {
        var ids = root._currentOrder()
        ids.sort(function (a, b) { return a - b })
        for (var k = 0; k < ids.length; k++) {
            var at = root._indexOfId(ids[k])
            if (at !== k) wsModel.move(at, k, 1)
        }
    }

    function _beginDrag(wsId) {
        root._origOrder = root._currentOrder()
        root.dragWsId   = wsId
        root.dragging   = true
        // Whatever the preview was about to do, it is not what the user is
        // asking for now.
        _dwellTimer.stop()
        _closeTimer.stop()
        root._pendingWs = null
        root._hoveredWs = null
        BarState.previewWorkspace = null
    }

    // Walks the row front to back, dropping the dragged tile into the first
    // slot whose midpoint the pointer has passed.
    function _updateDropTarget() {
        var cur = root._indexOfId(root.dragWsId)
        if (cur < 0) return
        var x = 0
        var target = wsModel.count - 1
        for (var i = 0; i < wsModel.count; i++) {
            var w = root._tileW[wsModel.get(i).wsId] || 0
            if (root.dragPointerX < x + w / 2) { target = i; break }
            x += w + wsRow.spacing
        }
        if (target !== cur) wsModel.move(cur, target, 1)
    }

    function _endDrag() {
        var before = root._origOrder
        var after  = root._currentOrder()

        var moved = false
        if (before && before.length === after.length)
            for (var i = 0; i < after.length; i++)
                if (after[i] !== before[i]) { moved = true; break }

        if (moved) {
            // The tiles are labelled by workspace number, and the numbers get
            // reassigned on commit. Painting the promised contents now is what
            // lets the drop be silent: the tile that ends up in this slot shows
            // exactly what the dragged one was showing a moment ago, so nothing
            // on screen needs to move.
            var promise = ({})
            for (var k = 0; k < after.length; k++) {
                var src = root._wsById(after[k])
                promise[before[k]] = src ? src.toplevels.values.slice() : []
            }
            root._optimistic = promise
            _optimisticGuard.restart()
            // Raised before the drag state is cleared, so the tile's offset
            // falls to zero without animating.
            root._silentReorder = true
        }

        root.dragging   = false
        root.dragWsId   = -1
        root._origOrder = null

        if (!before || before.length !== after.length) { root._syncModel(); return }
        if (!moved) return

        root._reorderNumeric()
        root._commitOrder(before, after)
        _silentGuard.restart()
    }


    // Realises the new order for real. `before` is the ids in the order they
    // were displayed, which -- the row being sorted by number -- is also the
    // list of destinations: the tile at slot k takes the number before[k].
    //
    // An id cannot be taken while in use, so each cycle of the permutation
    // goes through a temporary id, outside the per-monitor ranges.
    function _commitOrder(before, after) {
        var tempId = 999

        for (var m = 0; m < after.length; m++) {
            if (!root._wsById(after[m])) {
                root._optimistic = null
                root._syncModel()
                return
            }
        }

        var destOf = ({})
        for (var k = 0; k < after.length; k++) destOf[after[k]] = before[k]

        var steps = []
        var seen = ({})
        for (var j = 0; j < after.length; j++) {
            var startId = after[j]
            if (seen[startId] || destOf[startId] === startId) continue
            var cycle = []
            var cur = startId
            while (!seen[cur]) {
                seen[cur] = true
                cycle.push(cur)
                cur = destOf[cur]
            }

            // Head out of the way, the rest shift into the hole it leaves,
            // head back in at the end of the chain.
            steps.push({ from: cycle[0], to: tempId })
            for (var c = cycle.length - 1; c >= 1; c--)
                steps.push({ from: cycle[c], to: destOf[cycle[c]] })
            steps.push({ from: tempId, to: destOf[cycle[0]] })
        }

        HL.changeWorkspaceIds(steps)
    }

    // Dwell before the preview opens, so brushing past a tile on the way
    // somewhere else does not pop it up. Deleted by accident during the
    // drag-reorder work, which left _hoverWs referencing an id that no longer
    // existed -- the preview simply stopped appearing.
    Timer {
        id: _dwellTimer
        interval: 1200
        onTriggered: BarState.previewWorkspace = root._pendingWs
    }

    property var _hoveredWs: null

    function _hoverWs(ws, entered) {
        // A drag drags the pointer across every neighbouring tile; without
        // this each one would arm the dwell timer under the finger.
        if (root.dragging) return
        if (entered) {
            _hoveredWs = ws
            _pendingWs = ws
            _closeTimer.stop()
            _dwellTimer.restart()
        } else {
            if (_hoveredWs === ws) _hoveredWs = null
            _dwellTimer.stop()
            _closeTimer.restart()
        }
    }

    Timer {
        id: _closeTimer
        interval: 220
        onTriggered: {
            if (!BarState.previewPopupHovered && root._hoveredWs === null)
                BarState.previewWorkspace = null
        }
    }

    Connections {
        target: BarState
        function onPreviewPopupHoveredChanged() {
            if (BarState.previewPopupHovered) _closeTimer.stop()
            else _closeTimer.restart()
        }
    }

    // -- Icon cache ------------------------------------
    // Map the class -> absolute path. "" = lookup completed with no results.
    // null = not required yet (not in the map).
    property var iconCache: ({})
    property int iconCacheVersion: 0
    property var lookupQueue: []
    property bool lookupBusy: false

    // -- Icon overrides from AppLauncher ----------------------------
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

    FileView {
        path: Qt.resolvedUrl("../../modules/dashboard/applauncher-order.json").toString().replace("file://", "")
        watchChanges: true
        onFileChanged: overrideLoader.running = true
    }

    // One handler per object: a second Component.onCompleted on the same
    // element is a load-time error, not an override.
    Component.onCompleted: {
        overrideLoader.running = true
        root._syncModel()
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

    // -- Layout ----------------------------------------------
    Row {
        id: wsRow
        anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
        spacing: 4

        // The positioner animates the tiles that get displaced, which is the
        // whole "they move aside to make room" effect. OutBack overshoots the
        // slot and settles back into it, giving the snap.
        move: Transition {
            enabled: !root._silentReorder
            NumberAnimation {
                properties: "x"
                duration: 260
                easing.type: Easing.OutBack
                easing.overshoot: 1.5
            }
        }

        Repeater {
            model: wsModel

            delegate: Item {
                id: wsBtn

                required property int wsId
                readonly property var modelData: root._wsById(wsId)
                // A workspace emptied mid-reorder is destroyed by Hyprland and
                // comes straight back; hiding the tile then would make the row
                // blink for no reason the user can see.
                visible: modelData !== null
                        || (root._optimistic && root._optimistic[wsBtn.wsId] !== undefined)

                readonly property bool isDragged: root.dragWsId === wsBtn.wsId
                // Where inside the tile it was grabbed, so it does not jump
                // under the cursor when the drag starts.
                property real grabOffset: 0

                z: isDragged ? 10 : 0
                scale: isDragged ? 1.12 : 1.0
                Behavior on scale {
                    NumberAnimation {
                        duration: 190
                        easing.type: Easing.OutBack
                        easing.overshoot: 2.2
                    }
                }

                transform: [
                    // Glitch animation
                    Translate { id: wsBtnShift; x: 0 },
                    Translate {
                        id: wsDragShift
                        // Glued to the pointer. Subtracting the slot position
                        // cancels out the reshuffle animating underneath, so
                        // the tile stays under the cursor while its neighbours
                        // slide around it.
                        x: wsBtn.isDragged
                            ? root.dragPointerX - wsBtn.grabOffset - wsBtn.x
                            : 0
                        Behavior on x {
                            // Still animates when the drop changed nothing --
                            // that snap back into place is worth seeing.
                            enabled: !root.dragging && !root._silentReorder
                            NumberAnimation {
                                duration: 230
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.8
                            }
                        }
                    }
                ]

                onWidthChanged: root._tileW[wsBtn.wsId] = width
                Component.onCompleted: root._tileW[wsBtn.wsId] = width

                // The windows this tile stands for. Right after a reorder that
                // is what it is about to hold, so the bar shows the outcome
                // without waiting for the moves to land.
                readonly property var tops:
                    (root._optimistic && root._optimistic[wsBtn.wsId] !== undefined)
                        ? root._optimistic[wsBtn.wsId]
                        : (modelData ? modelData.toplevels.values : [])

                // true when it has open windows and is not in urgent state
                property bool showIcons: !isUrgent && winCount > 0
                // isActive: this workspace is the active one ON THIS BAR'S MONITOR
                property bool isActive: modelData ? modelData.id === root.activeWsId : false
                property bool isUrgent: modelData ? (modelData.urgent ?? false) : false
                property int  winCount: tops.length
                property bool isEmpty: winCount === 0

                // RamShape states: active = solid cyan, with windows = faint
                // cyan, empty = red outline
                readonly property color stateColor:
                    isUrgent ? CP.red :
                    isActive ? CP.cyan :
                    !isEmpty ? CP.alpha(CP.cyan, hoverHandler.hovered ? 0.3 : 0.15) :
                               CP.alpha(CP.red, 0.5)
                // Written by the hover glitch instead of stateColor, so the
                // state binding survives it; transparent = no glitch
                property color _glitchTint: "transparent"

                implicitWidth: showIcons
                    ? Math.min(winCount, 3) * 14 + (Math.min(winCount, 3) - 1) * 2 + 10
                    : 10
                implicitHeight: 20

                RamShape {
                    anchors.fill: parent
                    color: wsBtn._glitchTint.a > 0 ? wsBtn._glitchTint : wsBtn.stateColor
                    filled: wsBtn.isActive || wsBtn.isUrgent || !wsBtn.isEmpty
                }

                // -- App icons ------------------------------
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
                                var win = wsBtn.tops[index]
                                return win && win.wayland ? win.wayland.appId : ""
                            }

                            property string iconPath: ""

                            Connections {
                                target: root
                                function onIconCacheVersionChanged() {
                                    iconSlot.iconPath = root.iconCache[iconSlot.appClass] || ""
                                }
                            }

                            Component.onCompleted: {
                                iconSlot.iconPath = root.iconCache[appClass] || ""
                                root.requestIcon(appClass)
                            }
                            onAppClassChanged: {
                                iconSlot.iconPath = root.iconCache[appClass] || ""
                                root.requestIcon(appClass)
                            }

                            Image {
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                source: iconSlot.iconPath.startsWith("/") ? "file://" + iconSlot.iconPath : ""
                                visible: status === Image.Ready
                                sourceSize.width: width
                                sourceSize.height: height
                            }
                        }
                    }
                }

                // -- Urgent blink --------------------------------
                SequentialAnimation on opacity {
                    running: wsBtn.isUrgent
                    loops:   Animation.Infinite
                    // Stopping mid-cycle leaves opacity where it was
                    onRunningChanged: if (!running) wsBtn.opacity = 1
                    PropertyAction { value: 1.0 }
                    PauseAnimation { duration: 280 }
                    PropertyAction { value: 0.15 }
                    PauseAnimation { duration: 280 }
                }

                // -- Glitch on hover ---------------------------
                SequentialAnimation {
                    id: btnGlitch
                    running: false; loops: 1

                    PropertyAction { target: wsBtn;      property: "_glitchTint"; value: "transparent" }
                    PropertyAction { target: wsBtn;      property: "opacity"; value: 1.0 }
                    PropertyAction { target: wsBtnShift; property: "x";     value: 0 }
                    PauseAnimation { duration: 42 }
                    PropertyAction { target: wsBtn;      property: "_glitchTint"; value: CP.magenta }
                    PropertyAction { target: wsBtn;      property: "opacity"; value: 0.55 }
                    PropertyAction { target: wsBtnShift; property: "x";     value: 4 }
                    PauseAnimation { duration: 42 }
                    PropertyAction { target: wsBtn;      property: "_glitchTint"; value: CP.yellow }
                    PropertyAction { target: wsBtn;      property: "opacity"; value: 1.0 }
                    PropertyAction { target: wsBtnShift; property: "x";     value: -3 }
                    PauseAnimation { duration: 42 }
                    PropertyAction { target: wsBtn;      property: "_glitchTint"; value: "transparent" }
                    PropertyAction { target: wsBtn;      property: "opacity"; value: 0.7 }
                    PropertyAction { target: wsBtnShift; property: "x";     value: 2 }
                    PauseAnimation { duration: 42 }
                    PropertyAction { target: wsBtn;      property: "_glitchTint"; value: CP.magenta }                    
                    PropertyAction { target: wsBtn;      property: "opacity"; value: 1.0 }
                    PropertyAction { target: wsBtnShift; property: "x";     value: -1 }
                    PauseAnimation { duration: 42 }
                    PropertyAction { target: wsBtn;      property: "_glitchTint"; value: "transparent" }                    
                    PropertyAction { target: wsBtn;      property: "opacity"; value: 1.0 }
                    PropertyAction { target: wsBtnShift; property: "x";     value: 0 }
                    PauseAnimation { duration: 88 }
                }

                HoverHandler {
                    id: hoverHandler
                    onHoveredChanged: {
                        if (hovered && !btnGlitch.running) btnGlitch.restart()
                        if (wsBtn.modelData) root._hoverWs(wsBtn.modelData, hovered)
                    }
                }

                MouseArea {
                    id: wsMouse
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true

                    property real pressX: 0
                    property bool dragged: false

                    onPressed: mouse => {
                        pressX = mouse.x
                        dragged = false
                    }

                    onPositionChanged: mouse => {
                        if (!pressed || !(mouse.buttons & Qt.LeftButton)) return
                        if (!root.dragging) {
                            // Slack, so a plain click stays a click.
                            if (Math.abs(mouse.x - pressX) < 5) return
                            wsBtn.grabOffset = pressX
                            dragged = true
                            root._beginDrag(wsBtn.wsId)
                        } else if (!wsBtn.isDragged) {
                            return
                        }
                        // Once the tile is glued to the cursor it stops moving
                        // relative to this MouseArea, so the pointer cannot be
                        // read from mouse.x alone. Mapping through the tile's
                        // transform -- which still holds the previous frame's
                        // offset -- recovers the real position.
                        root.dragPointerX = wsBtn.mapToItem(wsRow, mouse.x, mouse.y).x
                        root._updateDropTarget()
                    }

                    onReleased: if (wsBtn.isDragged) root._endDrag()
                    onCanceled: if (wsBtn.isDragged) root._endDrag()

                    onClicked: mouse => {
                        // The release that ends a drag also fires a click.
                        if (dragged) { dragged = false; return }
                        if (!wsBtn.modelData) return
                        if (mouse.button === Qt.LeftButton)
                            HL.focusWorkspace(wsBtn.modelData.id)
                        else if (mouse.button === Qt.MiddleButton) {
                            var tops = wsBtn.modelData.toplevels.values
                            // `wayland` is null until the foreign-toplevel handle
                            // is matched to the window: a click in that gap threw
                            var tl = tops.length > 0 ? tops[tops.length - 1].wayland : null
                            if (tl) tl.close()
                        }
                    }
                    onWheel: wheel => {
                        if (root.dragging) return
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

                        HL.focusWorkspace(wsList[nextIdx].id)
                    }
                }
            }
        }
    }
}
