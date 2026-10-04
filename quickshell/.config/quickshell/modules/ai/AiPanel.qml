// AiPanel.qml - the AI chat drawer.
//
// Docked, it unrolls sideways out of the dock's AI slot. Its header drags it:
// the drawer detaches and stays where it is dropped, on this screen or on the
// other one, until a double click on the header docks it again. The edges and
// corners resize it, docked or not
import QtQuick
import Quickshell
import "../../common"
import "../../common/effects"
import "../../common/Colors.js" as CP

Item {
    id: root

    required property string screenName
    required property bool rightSide
    // Where the docked drawer goes, from Panels: beside the dock, centred on
    // the AI slot
    required property real dockedX
    required property real dockedY

    readonly property bool wantOpen: AiState.open && AiState.screenName === root.screenName

    // Never larger than the area it lives in. The default height is the
    // drawer's historic one, until the user resizes it
    readonly property int panelWidth: Math.round(Math.min(parent.width, AiState.panelW))
    readonly property int panelHeight: Math.round(Math.min(parent.height,
        AiState.panelH > 0 ? AiState.panelH : parent.height * 0.78))

    readonly property int minWidth: 360
    readonly property int minHeight: 420

    // The final rectangle: the unroll only animates the width toward it.
    // Docked it is kept inside the screen; detached it follows the pointer
    // even past the edge, and is put back in bounds on release
    readonly property real frameX: AiState.detached ? AiState.floatX : root.dockedX
    readonly property real frameY: AiState.detached ? AiState.floatY
        : Math.max(0, Math.min(parent.height - root.panelHeight, root.dockedY))

    x: root.frameX + (root.rightSide ? root.panelWidth - root.width : 0)
    y: root.frameY

    // Width is the gate here, exactly as height is for the dashboard.
    readonly property int inputWidth: wantOpen ? panelWidth : 0
    readonly property int inputHeight: panelHeight

    implicitWidth: 0
    implicitHeight: panelHeight
    visible: width > 0
    clip: true
    focus: true

    states: State {
        name: "visible"
        when: root.wantOpen
        PropertyChanges { root.implicitWidth: root.panelWidth }
    }

    transitions: [
        Transition { from: ""; to: "visible"; Anim { target: root; property: "implicitWidth"; duration: 260 } },
        Transition { from: "visible"; to: ""; Anim { target: root; property: "implicitWidth"; duration: 200; easing.type: Easing.InCubic } }
    ]

    Keys.onEscapePressed: if (!chat.dismissTop()) AiState.close()
    onVisibleChanged: if (visible) root.forceActiveFocus()

    // -- Drag and resize --------------------------------------
    //
    // Pointer positions are read in the Panels item, which never moves: the
    // MouseAreas travel with the drawer, their own coordinates would drift
    // under the pointer as it follows
    property var _press: null       // { px, py, x, y, w, h } at the press

    function _pointer(area, mouse) { return area.mapToItem(root.parent, mouse.x, mouse.y) }

    function _begin(area, mouse) {
        const p = root._pointer(area, mouse)
        root._press = { px: p.x, py: p.y, x: root.frameX, y: root.frameY,
            w: root.panelWidth, h: root.panelHeight }
    }

    function _move(area, mouse) {
        const s = root._press
        if (!s) return
        const p = root._pointer(area, mouse)
        const dx = p.x - s.px
        const dy = p.y - s.py
        // A click is not a drag: a docked drawer stays docked under 4px
        if (!AiState.detached && Math.abs(dx) + Math.abs(dy) < 4) return
        AiState.detachAt(root.screenName, s.x + dx, s.y + dy)
    }

    // Dropped past the edge of this screen, it goes to the screen under the
    // pointer, at the same offset from it. Either way it lands in bounds
    function _drop(area, mouse) {
        const s = root._press
        root._press = null
        if (!s || !AiState.detached) return
        const p = root._pointer(area, mouse)
        const here = Quickshell.screens.find(q => q.name === root.screenName)
        if (!here) return
        const top = root.parent.y       // the panel area starts under the bar
        const gx = here.x + p.x
        const gy = here.y + top + p.y
        const there = Quickshell.screens.find(q => gx >= q.x && gx < q.x + q.width
            && gy >= q.y && gy < q.y + q.height) ?? here
        const x = gx - there.x + (AiState.floatX - p.x)
        const y = gy - there.y - top + (AiState.floatY - p.y)
        AiState.detachAt(there.name,
            Math.max(0, Math.min(there.width - root.panelWidth, x)),
            Math.max(0, Math.min(there.height - top - root.panelHeight, y)))
    }

    function _resize(area, mouse, edges) {
        const s = root._press
        if (!s) return
        const p = root._pointer(area, mouse)
        const dx = p.x - s.px
        const dy = p.y - s.py
        const w = v => Math.max(root.minWidth, Math.min(root.parent.width, v))
        const h = v => Math.max(root.minHeight, Math.min(root.parent.height, v))
        // Docked, the height grows on both sides of the AI slot: twice the
        // pointer's travel keeps the dragged edge under it
        const k = AiState.detached ? 1 : 2
        let nx = s.x, ny = s.y, nw = s.w, nh = s.h
        if (edges & Qt.LeftEdge) { nw = w(s.w - dx); nx = s.x + s.w - nw }
        if (edges & Qt.RightEdge) nw = w(s.w + dx)
        if (edges & Qt.TopEdge) { nh = h(s.h - k * dy); ny = s.y + s.h - nh }
        if (edges & Qt.BottomEdge) nh = h(s.h + k * dy)
        AiState.panelW = nw
        AiState.panelH = nh
        if (AiState.detached) {
            AiState.floatX = nx
            AiState.floatY = ny
        }
    }

    // Content pinned to the dock side so it unrolls from the icon, not from
    // the far edge: with clip:true this is what makes it read as "growing out
    // of the dock" instead of "sliding in from nowhere".
    Item {
        id: shell
        width: root.panelWidth
        height: root.panelHeight
        anchors.right: root.rightSide ? parent.right : undefined
        anchors.left:  root.rightSide ? undefined : parent.left

        // Cuts go on the corners facing AWAY from the dock, so the panel reads as
        // a slab pulled out of that edge and not as a card floating next to it.
        readonly property int cut: 28
        readonly property int cutTL: root.rightSide ? cut : 0
        readonly property int cutBL: root.rightSide ? cut : 0
        readonly property int cutTR: root.rightSide ? 0 : cut
        readonly property int cutBR: root.rightSide ? 0 : cut

        CutShape {
            anchors.fill: parent
            fillColor: CP.alpha(CP.void2, 0.93)
            cutTopLeft: shell.cutTL; cutBottomLeft: shell.cutBL
            cutTopRight: shell.cutTR; cutBottomRight: shell.cutBR
        }

        // The header strip is the handle. Below the chat on purpose: the
        // header's own buttons sit over it and keep their clicks, the empty
        // parts of the header fall through to here
        MouseArea {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: chat.anchors.topMargin + 26
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            onPressed: mouse => root._begin(this, mouse)
            onPositionChanged: mouse => root._move(this, mouse)
            onReleased: mouse => root._drop(this, mouse)
            onDoubleClicked: AiState.dock()
        }

        AiChatView {
            id: chat
            anchors.fill: parent
            anchors.margins: 14
            // Keep clear of the diagonals.
            anchors.topMargin: 18
            anchors.bottomMargin: 18
        }

        Item {
            anchors.fill: parent
            clip: true
            ScanlineOverlay { anchors.fill: parent; opacity: 0.06 }
        }

        CutShape {
            anchors.fill: parent
            fillColor: "transparent"
            // Magenta: the netrunner accent, same as the dock's AI slot.
            strokeColor: CP.alpha(CP.magenta, 0.45)
            strokeWidth: 2
            inset: 0.5
            cutTopLeft: shell.cutTL; cutBottomLeft: shell.cutBL
            cutTopRight: shell.cutTR; cutBottomRight: shell.cutBR
        }

        CornerAccents {
            anchors.fill: parent
            anchors.margins: 6
            accentColor: CP.magenta
            size: 10
            thickness: 1
            opacity: 0.75
            // Hidden on the cut corners, shown on the square ones.
            showTopLeft:     !root.rightSide
            showBottomLeft:  !root.rightSide
            showTopRight:    root.rightSide
            showBottomRight: root.rightSide
        }

        // Last, so they sit over the content. Docked, the edge against the
        // dock does not move: the dock holds it
        Repeater {
            model: [
                { e: Qt.LeftEdge }, { e: Qt.RightEdge }, { e: Qt.TopEdge }, { e: Qt.BottomEdge },
                { e: Qt.TopEdge | Qt.LeftEdge }, { e: Qt.TopEdge | Qt.RightEdge },
                { e: Qt.BottomEdge | Qt.LeftEdge }, { e: Qt.BottomEdge | Qt.RightEdge }
            ]

            MouseArea {
                id: grip

                required property var modelData
                readonly property int edges: modelData.e
                readonly property bool l: (edges & Qt.LeftEdge) !== 0
                readonly property bool r: (edges & Qt.RightEdge) !== 0
                readonly property bool t: (edges & Qt.TopEdge) !== 0
                readonly property bool b: (edges & Qt.BottomEdge) !== 0
                readonly property bool corner: (l || r) && (t || b)
                readonly property int band: corner ? 14 : 6

                enabled: AiState.detached || !(root.rightSide ? r : l)
                x: r ? parent.width - band : 0
                y: b ? parent.height - band : 0
                width: (l || r) ? band : parent.width
                height: (t || b) ? band : parent.height
                z: corner ? 2 : 1
                cursorShape: corner
                    ? ((t && l) || (b && r) ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor)
                    : ((l || r) ? Qt.SizeHorCursor : Qt.SizeVerCursor)
                onPressed: mouse => root._begin(this, mouse)
                onPositionChanged: mouse => root._resize(this, mouse, grip.edges)
                onReleased: root._press = null
            }
        }
    }
}
