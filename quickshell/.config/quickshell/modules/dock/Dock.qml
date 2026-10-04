// Dock.qml — gooey edge dock.
//
// A single liquid lens grows out of the screen border and tracks the cursor.
// Only the icon the lens is sitting on is pushed out of the edge; the others
// stay flush against it, invisible, until the wave travels onto them.
//
// Three things make it read as liquid rather than as a moving rectangle:
//
// 1. apexY does NOT follow the cursor directly. A SpringAnimation chases it, so
//    the blob has inertia and a little overshoot.
// 2. The target is magnetised toward the nearest slot: halfway between two
//    icons it snaps to the next one, and the spring turns that snap into a
//    glide. This is what makes the wave "grab" an app instead of floating.
// 3. `lag` (the distance the spring still has to cover) skews and stretches the
//    lens along the direction of travel — surface tension, for free.
//
// This is the one place in the shell that uses curves instead of 90° cuts: the
// gooey wave was asked for explicitly. Everything inside it still obeys the
// design system.
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import "../../common"
import "../../common/Colors.js" as CP

Item {
    id: root

    required property DrawerState drawerState
    required property bool   rightSide
    required property string screenName
    property bool pinnedOpen: false

    // Cursor Y in this item's coordinates, pushed down by Interactions. -1 = away.
    property real cursorY: -1

    // Any panel opened from the dock keeps the wave out, not just the AI one
    readonly property bool anyPinned: {
        for (let i = 0; i < root.count; i++)
            if (DockConfig.activeMap[DockConfig.entries[i].id] === true) return true
        return false
    }

    readonly property bool expanded: root.drawerState.dockOpen
        || root.anyPinned || root.pinnedOpen

    // ── Geometry ──────────────────────────────────────────────────────────
    readonly property int  count: DockConfig.entries.length
    readonly property real slotPitch: 58        // distance between icon centres
    readonly property real spread: 84           // half height of the lens
    readonly property real maxDepth: 28         // how far the tip leaves the edge
    readonly property real iconArtSize: 20      // the glyph itself, not its box
    readonly property real iconSize: 50
    readonly property int  triggerPx: 3

    // Vertical headroom so the stretched lens never hits the layer bounds
    // (layer.enabled clips to the item rect, and the glow lives in that layer).
    readonly property real margin: root.spread * 1.42

    function slotCenterY(i) { return root.margin + i * root.slotPitch }

    // The item never resizes: only the Shape inside it moves. A dock whose own
    // width animated would drag its mask region and its children around every
    // frame, and dockCursorY is measured from this item's origin.
    implicitWidth: Math.ceil(root.maxDepth * 1.25) + 16
    implicitHeight: (root.count - 1) * root.slotPitch + root.margin * 2

    // ── Mask contract ─────────────────────────────────────────────────────
    // Closed, only a hairline at the very border takes the pointer; open, the
    // whole blob area does, which is what keeps it open while you use it.
    readonly property real inputWidth: root.expanded ? root.width : root.triggerPx
    readonly property real inputHeight: root.height
    readonly property real inputX:
        (root.rightSide && !root.expanded) ? root.width - root.triggerPx : 0

    // ── Wave state ────────────────────────────────────────────────────────
    readonly property real magnet: 0.62

    function magnetize(y) {
        const first = root.slotCenterY(0)
        const last  = root.slotCenterY(root.count - 1)
        const raw   = Math.max(first, Math.min(last, y))
        const i     = Math.max(0, Math.min(root.count - 1,
                        Math.round((raw - root.margin) / root.slotPitch)))
        const snap  = root.slotCenterY(i)
        return raw + (snap - raw) * root.magnet
    }

    // Is the pointer on the dock right now? The cursor lobe fades with this, so
    // with a panel pinned the wave stays on its icon and no ghost lobe is left
    // parked where the mouse last was
    property real cursorPresence: (root.cursorY >= 0 && root.drawerState.dockOpen) ? 1: 0
    Behavior on cursorPresence { NumberAnimation { duration: 180 } }

    // targetApexY is set imperatively, not bound: a binding that had to fall
    // back on the current apex when the cursor leaves would reference apexY and
    // loop. Assigning it on change keeps the blob where it was on the way out.
    property real targetApexY: root.slotCenterY(0)
    onCursorYChanged: {
        if (root.cursorY < 0) return
        // Re-entering opens the swell right where you are instead of dragging it
        // over from the last hover. Gated on cursorPresence and not on
        // openAmount: with a panel pinned the dock is already fully open
        const fresh = root.cursorPresence < 0.02
        if (fresh) root._snap = true
        root.targetApexY = root.magnetize(root.cursorY)
        if (fresh) root._snap = false
    }
    onPinnedOpenChanged: if (root.pinnedOpen) root.targetApexY = root.aiSlotCenterY

    // Guard for the Behavior below: while it is up, apexY follows its binding
    // without animating
    property bool _snap: false

    property real apexY: root.targetApexY
    Behavior on apexY {
        enabled: !root._snap
        SpringAnimation { spring: 4.2; damping: 0.52; mass: 1.0; epsilon: 0.15 }
    }

    // How far behind the spring is running, normalised and signed. Positive =
    // travelling down. This is the liquid term.
    readonly property real lag:
        Math.max(-1, Math.min(1, (root.targetApexY - root.apexY) / 55))

    property real openAmount: root.expanded ? 1 : 0
    Behavior on openAmount {
        NumberAnimation {
            duration: root.expanded ? 320 : 210
            easing.type: root.expanded ? Easing.OutBack : Easing.InCubic
            easing.overshoot: 1.15
        }
    }

    // -- The wave, as a field -------------------------------
    // One animated weight per slot, 1 while that panel is open. Animating it is
    // what makes a lobe grow out of the border instead of popping into place
    Instantiator {
        id: lobes
        model: root.count
        delegate: QtObject {
            required property int index
            property real w: DockConfig.activeMap[DockConfig.entries[index].id] === true ? 1 : 0
            Behavior on w { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
        }
    }
    function pinW(i) {
        const o = lobes.objectAt(i)
        return o ? o.w : 0
    }

    // Width of the weld between two lobes, in px of depth. Larger = they start
    // merging from further apart and the trough between them is shallower
    readonly property real weld: 9

    // Polynomial smooth maximum. A plain max() would leave a crease where two
    // profiles cross; this rounds the junction over - it is the whole merge
    function smoothMax(a, b, k) {
        const h = Math.max(0, Math.min(1, 0.5 + 0.5 * (a - b) / k))
        return a * h + b * (1 - h) + k * h * (1 - h)
    }

    // Raised-cosine half-width of a single lobe at y. Asymmetric extents let the
    // cursor lobe trail behind itself; a pinned lobe passes the same value twice
    function lobeAt(y, cy, d, sTop, sBot) {
        if (d <= 0.01) return 0
        const dy = y - cy
        const s = dy < 0 ? sTop : sBot
        if (s <= 0.5) return 0
        const t = Math.min(1, Math.abs(dy) / s)
        return d * 0.5 * (1 + Math.cos(Math.PI * t))
    }

    // Soft union of the cursor lobe and every pinned one. Single source of
    // truth: the outline, the containment gate and the icon offset all read it
    function lensDepthAt(y) {
        let d = root.lobeAt(y, root.apexY, root.cursorDepth,
            root.spreadTop, root.spreadBottom)
        for (let i = 0; i < root.count; i++) {
            const w = root.pinW(i)
            if (w <= 0.01) continue
            d = root.smoothMax(d,
                root.lobeAt(y, root.slotCenterY(i), root.pinnedDepth * w,
                root.pinnedSpread, root.pinnedSpread),
                root.weld)
        }
        return d
    }

    // Proximity of the CURSOR lobe to slot i, 0..1. Kept apart from the pinned
    // weights: the name plate and the crest rise follow the pointer only
    function cursorRevealOf(i) {
        const d = Math.abs(root.slotCenterY(i) - root.apexY)
        const t = Math.max(0, 1 - d / (root.slotPitch * 0.58))
        return t * t * (3 - 2 * t) * root.cursorPresence
    }

    // What an icon answers to: the cursor on it, or its own panel being open
    function revealOf(i) { return Math.max(root.cursorRevealOf(i), root.pinW(i)) }

    // Single source of truth for the icon scale: the containment maths below
    // needs to know how big the glyph currently is
    function revealScale(r) { return 0.52 + 0.48 * r }

    // How much of the glyph the wave can holde at slot i, 0..1. Sampled at the
    // glyph's top and bottom edges: a square icon's corners break through the
    // outline long before its centre would, which is why the wallpaper frame
    // kept poking out while the diamonds looked fine
    function fitOf(i) {
        const cy = root.slotCenterY(i)
        const half = root.iconArtSize * 0.5
        const lens = Math.min(root.lensDepthAt(cy - half),
            root.lensDepthAt(cy + half))
        const t = Math.max(0, Math.min(1, (lens - half - 3) / 10))
        return t * t * (3 - 2 * t)
    }

    // Distance from the border for the icon centre. whatever is left ovcer once
    // half the glyph and the stroke have been subtracted from the local field
    // width. This is what makes the icon ride the outline
    function slotOffset(i, r) {
        const cy = root.slotCenterY(i)
        const half = root.iconArtSize * 0.5 * root.revealScale(r)
        const lens = Math.min(root.lensDepthAt(cy - half),
            root.lensDepthAt(cy + half))
        return Math.max(0, Math.min(root.maxDepth * 0.55, lens - half - 3))
    }

    readonly property real focusReveal: {
        let m = 0
        for (let i = 0; i < root.count; i++) m = Math.max(m, root.cursorRevealOf(i))
        return m
    }

    // The cursor love rises higher when it has hold of an icon and flattens in
    // transit; it disappears entirely when the pointer leaves the dock
    readonly property real cursorDepth: root.maxDepth * root.openAmount
        * root.cursorPresence
        * (0.80 + 0.20 * root.focusReveal)
        * (1 - 0.18 * Math.abs(root.lag))

    // Pinned lobes are static and slightly shallower, so the cursor lobe still
    // reads as the live one when it travels across them
    readonly property real pinnedDepth: root.maxDepth * 0.86 * root.openAmount
    readonly property real pinnedSpread: root.spread * 0.94

    readonly property real liveSpread: root.spread
        * (0.88 + 0.12 * Math.min(1, root.openAmount))
        * (1 + 0.22 * Math.abs(root.lag))

    // ── Focus readouts (name plate in Panels reads these) ─────────────────
    readonly property int focusedIndex: {
        if (!root.expanded || root.cursorPresence < 0.5) return -1
        let best = -1, bestR = 0.5
        for (let i = 0; i < root.count; i++) {
            const r = root.revealOf(i)
            if (r > bestR) { bestR = r; best = i }
        }
        return best
    }
    readonly property string focusedLabel:
        focusedIndex < 0 ? "" : DockConfig.entries[focusedIndex].label
    readonly property real focusedCenterY: root.apexY
    readonly property color focusedAccent:
        focusedIndex < 0 ? CP.cyan
        : (DockConfig.activeMap[DockConfig.entries[focusedIndex].id] === true
        ? CP.yellow : DockConfig.entries[focusedIndex].accent)

    // Where the chat drawer anchors itself.
    readonly property real aiSlotCenterY: {
        const i = DockConfig.entries.findIndex(e => e.id === "ai")
        return i < 0 ? height / 2 : root.slotCenterY(i)
    }

    // ── The blob ──────────────────────────────────────────────────────────
    // Both ends of the curve sit 3px PAST the border so the straight segment
    // that closes the path — and its stroke — falls off-screen. Only the
    // outward curve is ever visible.
    readonly property real edgeX: root.rightSide ? root.width + 3 : -3
    readonly property real anchorX: root.rightSide ? root.width : 0
    readonly property real dir: root.rightSide ? -1 : 1

    // Asymmetric extents: moving down stretches the upper half and shortens the
    // lower one, so the blob trails behind instead of sliding rigidly
    readonly property real spreadTop: root.liveSpread * (1 + root.lag * 0.32)
    readonly property real spreadBottom: root.liveSpread * (1 - root.lag * 0.32)

    // -- Outline ---------------------------
    readonly property real sampleStep: 5

    // The field, walked from top to bottom and emitted as one path. Sampling is
    // the price of the merge: a union of N raised cosines has no closed-form
    // bezier. Quadratics through the midpoints make it C1-continuous, so ~80
    // samples read as a curve and not as a chain of facets.
    //
    // The baseline is edgeX, 3px past the border: where the field is 0 the
    // outline - and its stroke - sits off-screen, so loves that are still apart
    // are not joined by a visible hairline running along the edge
    readonly property string wavePath: {
        const h = root.height
        const step = root.sampleStep
        const xs = [], ys = []
        for (let y = 0; y <= h; y += step) {
            ys.push(y)
            xs.push(root.edgeX + root.dir * root.lensDepthAt(y))
        }
        const n = ys.length
        let d = "M " + xs[0] + " " + ys[0]
        for (let i = 1; i < n - 1; i++)
            d += " Q " + xs[i] + " " + ys[i]
            + " " + ((xs[i] + xs[i + 1]) * 0.5)
            + " " + ((ys[i] + ys[i + 1]) * 0.5)
        return d + " L " + xs[n - 1] + " " + ys[n - 1] 
    }

    Shape {
        id: blob
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        visible: root.openAmount > 0.005
        asynchronous: false

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: CP.alpha(root.focusedAccent, 0.5)
            shadowBlur: 0.85
            shadowOpacity: 0.55
        }

        ShapePath {
            fillColor: CP.alpha(CP.void2, 0.92)
            strokeColor: CP.alpha(root.focusedAccent, 0.85)
            strokeWidth: 1.5
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap

            Behavior on strokeColor { ColorAnimation { duration: 180 } }

            PathSvg { path: root.wavePath }
        }
    }

    // -- Icons -------------------------------------
    Repeater {
        model: DockConfig.entries

        DockSlot {
            required property var modelData
            required property int index

            // Proximity-or-pinned gate times containment gate: the wave has to
            // be on us AND be wide enough to hold us
            readonly property real r: root.revealOf(index) * root.fitOf(index)
                * Math.min(1, root.openAmount)

            iconId: modelData.id
            accent: modelData.accent
            active: DockConfig.activeMap[modelData.id] === true

            rightSide: root.rightSide
            reveal: r
            artSize: root.iconArtSize
            artScale: root.revealScale(r)
            centerOffset: root.slotOffset(index, r)

            width: root.iconSize
            height: root.iconSize
            // A couple of px of drag in the direction the wave is travelling
            y: root.slotCenterY(index) - height / 2
                + root.lag * 3 * root.cursorRevealOf(index)

            onActivated: DockConfig.activate(modelData.id, root.screenName)
        }
    }
}
