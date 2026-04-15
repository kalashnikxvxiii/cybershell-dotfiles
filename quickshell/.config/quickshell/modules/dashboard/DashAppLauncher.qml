// DashAppLauncher.qml — App icon grid with drag-and-drop + context menu
// Left click  → launch app
// Drag        → reorder (live swap, persisted to applauncher-order.json)
// Right click → context menu (Pin / Remove)
// "+" button  → inline form to add a new app

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../common"
import "../../common/Colors.js" as CP

Item {
    id: root

    readonly property int  cols:     3
    readonly property real cellSize: Math.floor(width / cols)

    // Add-app mode
    property bool adding:       false
    property bool iconEditing:  false
    property int  iconEditIndex: -1

    // Current drag state (for trail shadows)
    property bool dragActive: false
    property real dragCenterX: 0
    property real dragCenterY: 0
    property string dragSrc: ""

    // Request OnDemand keyboard focus from the containing PanelWindow
    Binding {
        when: root.adding || root.iconEditing
        target: QsWindow.window
        property: "WlrLayershell.keyboardFocus"
        value: WlrKeyboardFocus.OnDemand
    }

    // Close the form if the focus grab is released externally (click outside)
    HyprlandFocusGrab {
        active: root.adding || root.iconEditing
        windows: [QsWindow.window]
        onCleared: { root.adding = false; root.iconEditing = false }
    }

    // Button hover detected at root level — bypasses delegate MouseAreas
    readonly property bool addBtnHovered: !adding
        && rootHover.hovered
        && rootHover.point.position.x >= root.width  - 28
        && rootHover.point.position.y >= root.height - 28

    onAddBtnHoveredChanged: if (addBtnHovered) addGlitch.restart()

    HoverHandler { id: rootHover }

    // Default apps — only used if the JSON doesn't exist yet (first launch)
    readonly property var defaultApps: [
        { icon: "discord",          exec: "discord",          pinned: false },
        { icon: "steam",            exec: "steam",            pinned: false },
        { icon: "spotify-launcher", exec: "spotify-launcher", pinned: false },
        { icon: "kitty",            exec: "kitty",            pinned: false },
    ]

    // Icon lookup via GTK icon theme (same pattern as Workspaces.qml)
    property var  iconCache:        ({})
    property int  iconCacheVersion: 0
    property var  lookupQueue:      []
    property bool lookupBusy:       false

    function requestIcon(name) {
        if (!name || name.startsWith("/")) return   // absolute path: no lookup needed
        if (name in iconCache) return
        if (lookupQueue.indexOf(name) >= 0) return
        iconCache[name] = null
        lookupQueue.push(name)
        drainQueue()
    }

    function drainQueue() {
        if (lookupBusy || lookupQueue.length === 0) return
        var name = lookupQueue.shift()
        lookupBusy = true
        iconProc.pendingName = name
        iconProc.command = [
            "python3",
            Qt.resolvedUrl("../../scripts/icon-lookup.py").toString().replace("file://", ""),
            name
        ]
        iconProc.running = true
    }

    Process {
        id: iconProc
        property string pendingName: ""
        running: false
        stdout: SplitParser {
            onRead: data => {
                root.iconCache[iconProc.pendingName] = data.trim()
                root.iconCacheVersion++
            }
        }
        onExited: {
            if (root.iconCache[iconProc.pendingName] === null) {
                root.iconCache[iconProc.pendingName] = ""
                root.iconCacheVersion++
            }
            root.lookupBusy = false
            root.drainQueue()
        }
    }

    readonly property string jsonPath:
        Qt.resolvedUrl("applauncher-order.json").toString().replace("file://", "")

    property bool modelPopulated: false

    ListModel { id: appsModel }

    // Async read on first launch
    Process {
        id: readProc
        command: ["python3", "-c",
            "import json,sys; print(json.dumps(json.load(open(sys.argv[1]))))",
            root.jsonPath
        ]
        running: false
        stdout: SplitParser {
            onRead: data => {
                if (root.modelPopulated) return
                try {
                    var obj  = JSON.parse(data.trim())
                    var apps = Array.isArray(obj.apps) ? obj.apps : []
                    root.populateModel(apps.length > 0 ? apps : null)
                } catch(e) { root.populateModel(null) }
            }
        }
        onExited: {
            // File not found or parse failed: fall back to defaults
            if (!root.modelPopulated) root.populateModel(null)
        }
    }

    // Write via Process — guarantees flush to disk
    Process {
        id: saveProc
        running: false
    }

    Component.onCompleted: readProc.running = true

    function populateModel(saved) {
        modelPopulated = true
        var list = (saved && saved.length > 0) ? saved : root.defaultApps
        for (var i = 0; i < list.length; i++) {
            var e = list[i]
            appsModel.append({
                exec:   String(e.exec   || ""),
                icon:   String(e.icon   || e.exec || ""),
                pinned: e.pinned === true,
                appId: String(e.appId || "")
            })
        }
        if (!saved || saved.length === 0) Qt.callLater(root.saveState)
    }

    // Save the current state (order + icon + pin)
    function saveState() {
        var apps = []
        for (var i = 0; i < appsModel.count; i++) {
            var it = appsModel.get(i)
            apps.push({ exec: String(it.exec), icon: String(it.icon), pinned: it.pinned === true, appId: String(it.appId || "") })
        }
        var jsonStr = JSON.stringify({ apps: apps })
        saveProc.command = ["python3", "-c",
            "import json,sys; f=open(sys.argv[2],'w'); json.dump(json.loads(sys.argv[1]),f,indent=2); f.close()",
            jsonStr, root.jsonPath
        ]
        saveProc.running = true
    }

    // Update the appId in the model reading the active Hyprland windows
    function syncAppIds() {
        let wins = Hyprland.toplevels.values
        for (let i = 0; i < appsModel.count; i++) {
            let app = appsModel.get(i)
            if (app.appId && app.appId.length > 0) continue
            let exec = app.exec
            for (let j = 0; j < wins.length; j++) {
                let w = wins[j]
                if (!w.wayland) continue
                let wId = w.wayland.appId
                let wClass = (w.wlClass || "").toLowerCase()
                // Match: the exec contains the appId or viceversa
                if (wId && (exec.indexOf(wId) >= 0 || wId.indexOf(exec) >= 0 || wClass.indexOf(exec) >= 0)) {
                    appsModel.setProperty(i, "appId", wId)
                    saveState()
                    break
                }
            }
        }
    }

    Timer {
        interval: 10000; running: root.visible; repeat: true
        onTriggered: root.syncAppIds()
    }

    layer.enabled: true
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: shapeMask
    }

    CutShape {
        anchors.fill: parent
        fillColor: "transparent"
        cutTopLeft: 26
    }

    // GridView — direct model on appsModel: appsModel.move() updates positions without recreating delegates
    GridView {
        id: gridView
        anchors.fill: parent
        cellWidth:  root.cellSize
        cellHeight: root.cellSize
        model: appsModel
        clip:  true
        interactive: true

        opacity: (root.adding || root.iconEditing) ? 0 : 1
        enabled: !root.adding && !root.iconEditing
        Behavior on opacity { Anim { duration: 180 } }

        delegate: Item {
            id: delegateRoot
            width:  root.cellSize
            height: root.cellSize

            // Model index (updates after each appsModel.move())
            property int modelIndex: index

            // Normalized vector: from icon center -> GridView center
            // Reactive to delegateRoot.x/y and gridView.width/height
            readonly property real _rawDx: gridView.width / 2 - (delegateRoot.x + width / 2)
            readonly property real _rawDy: gridView.height / 2 - (delegateRoot.y - gridView.contentY + height / 2)

            // Resolve icon path: direct absolute path, or via iconCache
            property string resolvedIcon: {
                var _ = root.iconCacheVersion
                var ic = model.icon
                if (ic.startsWith("/")) return "file://" + ic
                var p = root.iconCache[ic] || ""
                return p.length > 0 ? "file://" + p : ""
            }

            Component.onCompleted: root.requestIcon(model.icon)

            // Slot highlight — visible when an icon hovers over this cell during drag
            Rectangle {
                anchors.fill: parent
                anchors.margins: 5
                radius: 8
                color: "transparent"
                border.width: 1
                border.color: CP.alpha(CP.cyan, 0.55)
                visible: dropZone.containsDrag && !mouseArea.drag.active
            }

            // Drop zone: live swap in the model
            DropArea {
                id: dropZone
                anchors.fill: parent
                onEntered: drag => {
                    var from = drag.source.modelIndex
                    var to   = delegateRoot.modelIndex
                    if (from !== to) appsModel.move(from, to, 1)
                }
            }

            // Visual element — detaches from layout during drag (ParentChange)
            Item {
                id: content
                width:  delegateRoot.width
                height: delegateRoot.height
                x: 0
                y: 0

                Drag.active:    mouseArea.drag.active
                Drag.source:    delegateRoot
                Drag.hotSpot.x: width  / 2
                Drag.hotSpot.y: height / 2

                states: State {
                    when: mouseArea.drag.active
                    ParentChange { target: content; parent: root }
                    PropertyChanges { target: root; dragActive: true; dragSrc: delegateRoot.resolvedIcon }
                    PropertyChanges { target: content; z: 20 }
                }
                onXChanged: if (mouseArea.drag.active) root.dragCenterX = x + width / 2
                onYChanged: if (mouseArea.drag.active) root.dragCenterY = y + height / 2

                Behavior on x { enabled: !mouseArea.drag.active; SpringAnimation { spring: 1.5; damping: 0.25; epsilon: 0.01 } }
                Behavior on y { enabled: !mouseArea.drag.active; SpringAnimation { spring: 1.5; damping: 0.25; epsilon: 0.01 } }

                // Cyan shadows oriented toward the center
                Repeater {
                    model: 3
                    delegate: Image {
                        required property int index
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: delegateRoot._rawDx * (index + 1) * 0.12
                        anchors.verticalCenterOffset: delegateRoot._rawDy * (index + 1) * 0.12
                        width: parent.width - 24
                        height: width
                        source: delegateRoot.resolvedIcon
                        sourceSize.width: width
                        sourceSize.height: height
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        visible: appIcon.status === Image.Ready && !mouseArea.drag.active
                        opacity: 0.22 - index * 0.07
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            colorization: 1.0
                            colorizationColor: CP.cyan
                        }
                    }
                }

                Image {
                    id: appIcon
                    anchors.centerIn: parent
                    width:  parent.width  - 24
                    height: width
                    source: delegateRoot.resolvedIcon
                    sourceSize.width:  width
                    sourceSize.height: height
                    fillMode: Image.PreserveAspectFit
                    smooth:   true
                    visible: status === Image.Ready
                    opacity: mouseArea.drag.active ? 0.6 : 1.0
                    Behavior on opacity { Anim { duration: 120 } }
                }

                // Fallback: generic icon when lookup comes up empty
                Text {
                    anchors.centerIn: parent
                    visible: appIcon.status !== Image.Ready
                    text: "󰣇"
                    font.family: "JetBrains Mono Nerd Font"
                    font.pixelSize: appIcon.width * 0.65
                    color: Colours.accentPrimary
                    opacity: mouseArea.drag.active ? 0.6 : 1.0
                    Behavior on opacity { Anim { duration: 120 } }
                }

                // Pin dot, top-right corner
                Rectangle {
                    anchors.top:    parent.top
                    anchors.right:  parent.right
                    anchors.margins: 7
                    width: 5; height: 5; radius: 3
                    color: CP.cyan
                    visible: model.pinned ?? false
                }

                // Border during drag
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 8
                    color: "transparent"
                    border.width: mouseArea.drag.active ? 1 : 0
                    border.color: CP.alpha(CP.cyan, 0.7)
                    Behavior on border.width { Anim { duration: 80 } }
                }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                drag.target:     content
                drag.smoothed:   true
                preventStealing: true
                cursorShape: drag.active ? Qt.DragMoveCursor : Qt.PointingHandCursor

                property bool wasDragged: false
                onPressed:         wasDragged = false
                onPositionChanged: if (drag.active) wasDragged = true

                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        var pos = mapToItem(root, mouseX, mouseY)
                        ctxMenu.open(delegateRoot.modelIndex,
                                     model.pinned ?? false,
                                     pos.x, pos.y)
                    } else if (!wasDragged) {
                        launcher.running = true
                    }
                }

                onReleased: {
                    if (wasDragged) {
                        content.Drag.drop()
                        root.saveState()
                    }
                }
            }

            Process {
                id: launcher
                command: ["bash", "-c", model.exec]
                running: false
            }
        }
    }

    // Trail shadows while dragging
    Repeater {
        model: 3
        delegate: Item {
            id: trailItem
            required property int index
            z: 19

            property real _cx: root.width / 2
            property real _cy: root.height / 2

            x: _cx - (root.cellSize - 24) / 2
            y: _cy - (root.cellSize - 24) / 2

            Behavior on _cx { NumberAnimation { duration: (trailItem.index + 1) * 80 } }
            Behavior on _cy { NumberAnimation { duration: (trailItem.index + 1) * 80 } }

            Connections {
                target: root
                function onDragCenterXChanged() {
                    if (root.dragActive) trailItem._cx = root.dragCenterX
                }
                function onDragCenterYChanged() {
                    if (root.dragActive) trailItem._cy = root.dragCenterY
                }
            }

            Image {
                x: (root.width / 2 - trailItem._cx) * (trailItem.index + 1) * 0.12
                y: (root.height / 2 - trailItem._cy) * (trailItem.index + 1) * 0.12
                width: root.cellSize - 24
                height: width
                source: root.dragSrc
                sourceSize.width: width
                sourceSize.height: height
                fillMode: Image.PreserveAspectFit
                smooth: true
                opacity: root.dragActive ? (0.22 - trailItem.index * 0.07) : 0
                Behavior on opacity { NumberAnimation { duration: 120 }  } 
                layer.enabled: true
                layer.effect: MultiEffect {
                    colorization: 1.0
                    colorizationColor: CP.cyan
                }
            }
        }
    }

    CutShape {
        id: shapeMask
        layer.enabled: true
        visible: false
        width: parent.width
        height: parent.height
        fillColor: "white"
        cutTopLeft: 26
    }

    // Add app button — bottom-right corner
    // The container never changes opacity: only the visual child animates it,
    // so the MouseArea is never disrupted by opacity changes on the parent.
    Item {
        anchors.bottom: parent.bottom
        anchors.right:  parent.right
        width:  28
        height: 28
        z: 5
        visible: !root.adding

        // Visual part with animated opacity
        Item {
            id: addVisual
            anchors.fill: parent
            opacity: root.addBtnHovered ? 0.45 : 0
            Behavior on opacity { Anim { duration: 180 } }

            CutShape {
                anchors.fill: parent
                fillColor:   CP.alpha(CP.cyan, 0.15)
                strokeColor: CP.alpha(CP.cyan, 0.55)
                strokeWidth: 1
                inset: 0.5
                cutTopLeft: 8
            }

            Text {
                id: addLabel
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 3
                text: "+"
                font.pixelSize: 15
                font.family: "Oxanium"
                color: CP.cyan
                transform: Translate { id: addShift; x: 0 }
            }

            GlitchAnim {
                id: addGlitch
                labelTarget: addLabel
                shiftTarget: addShift
                baseColor: CP.cyan
                shortMode: true
                x1: 2; x2: -2
                finalPause: 100
            }
        }

        // TapHandler for click — hover is handled by rootHover at root level
        TapHandler {
            cursorShape: Qt.PointingHandCursor
            onTapped: {
                execInput.text = ""
                iconInput.text = ""
                root.adding = true
            }
        }
    }

    // Add app form — inline, takes the grid's place
    Item {
        id: addForm
        anchors.fill: parent
        opacity: root.adding ? 1 : 0
        enabled: root.adding
        // visible throughout the entire fade-in/out animation
        visible: root.adding || opacity > 0
        z: 8
        Behavior on opacity { Anim { duration: 180 } }

        // FocusScope: delegates focus to execInput when the scope becomes active
        FocusScope {
            anchors.fill: parent
            focus: root.adding

            Column {
                anchors {
                    left: parent.left; right: parent.right
                    verticalCenter: parent.verticalCenter
                    margins: 10
                }
                spacing: 6

                Text {
                    width: parent.width
                    text: "ADD APP"
                    font.family: "Oxanium"; font.pixelSize: 11; font.letterSpacing: 3
                    color: CP.cyan
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle { width: parent.width; height: 1; color: CP.alpha(CP.cyan, 0.3) }

                // Exec
                Text {
                    text: "exec"
                    font.family: "Oxanium"; font.pixelSize: 9; font.letterSpacing: 1
                    color: CP.alpha(CP.cyan, 0.6)
                }
                Rectangle {
                    width: parent.width; height: 24; radius: 3
                    color: CP.alpha(CP.cyan, 0.07)
                    border.width: 1
                    border.color: execInput.activeFocus ? CP.alpha(CP.cyan, 0.7) : CP.alpha(CP.cyan, 0.25)
                    Behavior on border.color { CAnim {} }

                    TextInput {
                        id: execInput
                        focus: true   // default focus item in the FocusScope
                        anchors { fill: parent; margins: 6 }
                        font.family: "Oxanium"; font.pixelSize: 11
                        color: Colours.textPrimary
                        selectByMouse: true
                        Keys.onReturnPressed: iconInput.forceActiveFocus()
                        Keys.onEscapePressed: root.adding = false
                    }
                }

                // Icon
                Text {
                    text: "icon path  (empty = auto)"
                    font.family: "Oxanium"; font.pixelSize: 9; font.letterSpacing: 1
                    color: CP.alpha(CP.cyan, 0.6)
                }
                Rectangle {
                    width: parent.width; height: 24; radius: 3
                    color: CP.alpha(CP.cyan, 0.07)
                    border.width: 1
                    border.color: iconInput.activeFocus ? CP.alpha(CP.cyan, 0.7) : CP.alpha(CP.cyan, 0.25)
                    Behavior on border.color { CAnim {} }

                    TextInput {
                        id: iconInput
                        anchors { fill: parent; margins: 6 }
                        font.family: "Oxanium"; font.pixelSize: 11
                        color: Colours.textPrimary
                        selectByMouse: true
                        Keys.onReturnPressed: addForm.confirmAdd()
                        Keys.onEscapePressed: root.adding = false
                    }
                }

                // Buttons
                Row {
                    width: parent.width
                    spacing: 6

                    Rectangle {
                        width: (parent.width - 6) / 2; height: 26; radius: 3
                        color: cancelHover.containsMouse ? CP.alpha(CP.red, 0.12) : "transparent"
                        border.width: 1; border.color: CP.alpha(CP.red, 0.4)
                        Behavior on color { CAnim {} }

                        Text {
                            anchors.centerIn: parent
                            text: "CANCEL"
                            font.family: "Oxanium"; font.pixelSize: 10; font.letterSpacing: 2
                            color: CP.red
                        }
                        MouseArea {
                            id: cancelHover
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.adding = false
                        }
                    }

                    Rectangle {
                        width: (parent.width - 6) / 2; height: 26; radius: 3
                        color: confirmHover.containsMouse ? CP.alpha(CP.cyan, 0.2) : CP.alpha(CP.cyan, 0.08)
                        border.width: 1; border.color: CP.alpha(CP.cyan, 0.5)
                        Behavior on color { CAnim {} }

                        Text {
                            anchors.centerIn: parent
                            text: "ADD"
                            font.family: "Oxanium"; font.pixelSize: 10; font.letterSpacing: 2
                            color: CP.cyan
                        }
                        MouseArea {
                            id: confirmHover
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: addForm.confirmAdd()
                        }
                    }
                }
            }
        }

        function confirmAdd() {
            var exec = execInput.text.trim()
            if (exec === "") return
            var icon = iconInput.text.trim()
            if (icon === "") icon = exec   // use exec as icon name for lookup
            appsModel.append({ icon: icon, exec: exec, pinned: false })
            root.requestIcon(icon)
            root.saveState()
            root.adding = false
        }
    }

    // Icon edit form — inline, same style as addForm
    Item {
        id: iconEditForm
        anchors.fill: parent
        opacity: root.iconEditing ? 1 : 0
        enabled: root.iconEditing
        visible: root.iconEditing || opacity > 0
        z: 8
        Behavior on opacity { Anim { duration: 180 } }

        FocusScope {
            anchors.fill: parent
            focus: root.iconEditing

            Column {
                anchors {
                    left: parent.left; right: parent.right
                    verticalCenter: parent.verticalCenter
                    margins: 10
                }
                spacing: 6

                Text {
                    width: parent.width
                    text: "CHANGE ICON"
                    font.family: "Oxanium"; font.pixelSize: 11; font.letterSpacing: 3
                    color: CP.cyan
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle { width: parent.width; height: 1; color: CP.alpha(CP.cyan, 0.3) }

                Text {
                    text: "icon name or path"
                    font.family: "Oxanium"; font.pixelSize: 9; font.letterSpacing: 1
                    color: CP.alpha(CP.cyan, 0.6)
                }
                Rectangle {
                    width: parent.width; height: 24; radius: 3
                    color: CP.alpha(CP.cyan, 0.07)
                    border.width: 1
                    border.color: iconEditInput.activeFocus ? CP.alpha(CP.cyan, 0.7) : CP.alpha(CP.cyan, 0.25)
                    Behavior on border.color { CAnim {} }

                    TextInput {
                        id: iconEditInput
                        focus: true
                        anchors { fill: parent; margins: 6 }
                        font.family: "Oxanium"; font.pixelSize: 11
                        color: Colours.textPrimary
                        selectByMouse: true
                        Keys.onReturnPressed: iconEditForm.confirmChange()
                        Keys.onEscapePressed: root.iconEditing = false
                    }
                }

                Row {
                    width: parent.width
                    spacing: 6

                    Rectangle {
                        width: (parent.width - 6) / 2; height: 26; radius: 3
                        color: ieCancel.containsMouse ? CP.alpha(CP.red, 0.12) : "transparent"
                        border.width: 1; border.color: CP.alpha(CP.red, 0.4)
                        Behavior on color { CAnim {} }

                        Text {
                            anchors.centerIn: parent
                            text: "CANCEL"
                            font.family: "Oxanium"; font.pixelSize: 10; font.letterSpacing: 2
                            color: CP.red
                        }
                        MouseArea {
                            id: ieCancel
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.iconEditing = false
                        }
                    }

                    Rectangle {
                        width: (parent.width - 6) / 2; height: 26; radius: 3
                        color: ieConfirm.containsMouse ? CP.alpha(CP.cyan, 0.2) : CP.alpha(CP.cyan, 0.08)
                        border.width: 1; border.color: CP.alpha(CP.cyan, 0.5)
                        Behavior on color { CAnim {} }

                        Text {
                            anchors.centerIn: parent
                            text: "APPLY"
                            font.family: "Oxanium"; font.pixelSize: 10; font.letterSpacing: 2
                            color: CP.cyan
                        }
                        MouseArea {
                            id: ieConfirm
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: iconEditForm.confirmChange()
                        }
                    }
                }
            }
        }

        function confirmChange() {
            var icon = iconEditInput.text.trim()
            if (icon === "" || root.iconEditIndex < 0) { root.iconEditing = false; return }
            appsModel.setProperty(root.iconEditIndex, "icon", icon)
            root.requestIcon(icon)
            root.saveState()
            root.iconEditing = false
        }
    }

    // Context menu (external component)
    AppContextMenu {
        id: ctxMenu
        anchors.fill: parent
        parentWidth: root.width
        parentHeight: root.height

        onPinToggle: (index, currentlyPinned) => {
            appsModel.setProperty(index, "pinned", !currentlyPinned)
            root.saveState()
        }
        onRemoveApp: index => {
            appsModel.remove(index, 1)
            root.saveState()
        }
        onEditIcon: index => {
            root.iconEditIndex = index
            iconEditInput.text = appsModel.get(index).icon
            root.iconEditing = true
        }
    }
}
