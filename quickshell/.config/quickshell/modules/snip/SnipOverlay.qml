// SnipOverlay.qml — the region selector: a frozen screen you draw a box on.
//
// The screen is frozen because we are not drawing over the desktop at all, we
// are drawing over a PNG that scripts/snip.sh captured with grim a moment
// before this surface existed. That is what makes it possible to capture an open
// menu, a tooltip or a hover state: by the time the keyboard grab dismisses
// them, the pixels are already on disk.
//
// Keyboard focus is Exclusive, not OnDemand as in WallpaperPicker: a selector
// has to answer Esc before the first click, and OnDemand only grants focus once
// something has been clicked.
//
// Release commits immediately -- there is no confirm step. The left button uses
// the armed action, the right button overrides it with the annotator.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../../common"
import "../../common/effects"
import "../../common/Colors.js" as CP

Scope {
    id: root

    required property var screen

    readonly property bool isActive:
        SnipState.active && root.screen.name === SnipState.screenName

    PanelWindow {
        id: win

        screen: root.screen
        WlrLayershell.namespace: "snip-overlay"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.isActive
            ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: -1
        color: "transparent"
        visible: root.isActive

        // ── Selection geometry (window-local logical pixels) ──────────────
        property bool  dragging: false
        property real  startX: 0
        property real  startY: 0
        property real  curX: 0
        property real  curY: 0

        readonly property real selX: Math.min(win.startX, win.curX)
        readonly property real selY: Math.min(win.startY, win.curY)
        readonly property real selW: Math.abs(win.curX - win.startX)
        readonly property real selH: Math.abs(win.curY - win.startY)
        readonly property bool hasSel: win.selW >= 1 && win.selH >= 1

        // Clamp before handing the rectangle over: a drag that leaves the
        // output would otherwise crop outside the captured image.
        function clampedRect() {
            const x = Math.max(0, Math.min(win.selX, win.width));
            const y = Math.max(0, Math.min(win.selY, win.height));
            return {
                x: x,
                y: y,
                w: Math.max(0, Math.min(win.selW, win.width - x)),
                h: Math.max(0, Math.min(win.selH, win.height - y))
            };
        }

        function reset() {
            win.dragging = false;
            win.startX = win.startY = win.curX = win.curY = 0;
        }

        onVisibleChanged: if (visible) win.reset()

        // ── The freeze ───────────────────────────────────────────────────
        Image {
            id: frozen
            anchors.fill: parent
            // Unique filenames per capture already defeat the cache, but an
            // explicit false removes any doubt that a stale frame could show.
            cache: false
            asynchronous: false
            fillMode: Image.Stretch
            source: SnipState.frozenPath ? "file://" + SnipState.frozenPath : ""
        }

        // ── Dimming: four bands around the selection ─────────────────────
        // Four rectangles rather than an opacity mask, so the selected region
        // is literally untouched pixels instead of a composite.
        Item {
            anchors.fill: parent
            visible: true

            readonly property color veil: CP.alpha(CP.void2, 0.62)
            readonly property var r: win.hasSel
                ? { x: win.selX, y: win.selY, w: win.selW, h: win.selH }
                : { x: 0, y: 0, w: 0, h: 0 }

            Rectangle {   // top
                color: parent.veil
                x: 0; y: 0
                width: parent.width
                height: parent.r.y
            }
            Rectangle {   // bottom
                color: parent.veil
                x: 0
                y: parent.r.y + parent.r.h
                width: parent.width
                height: Math.max(0, parent.height - (parent.r.y + parent.r.h))
            }
            Rectangle {   // left
                color: parent.veil
                x: 0
                y: parent.r.y
                width: parent.r.x
                height: parent.r.h
            }
            Rectangle {   // right
                color: parent.veil
                x: parent.r.x + parent.r.w
                y: parent.r.y
                width: Math.max(0, parent.width - (parent.r.x + parent.r.w))
                height: parent.r.h
            }
        }

        // No scanline overlay here on purpose: it would sit over the region
        // being framed, and the point of this surface is that what you box is
        // exactly what you get. The toolbar keeps its own, since that is chrome.

        // ── Crosshair guides, while nothing is selected yet ──────────────
        Item {
            anchors.fill: parent
            visible: !win.dragging && !win.hasSel && ma.containsMouse
            opacity: 0.35

            Rectangle {
                color: SnipState.currentAccent
                width: parent.width; height: 1
                y: Math.round(ma.mouseY)
            }
            Rectangle {
                color: SnipState.currentAccent
                width: 1; height: parent.height
                x: Math.round(ma.mouseX)
            }
        }

        // ── The selection frame ──────────────────────────────────────────
        Item {
            id: frame
            visible: win.hasSel
            x: win.selX
            y: win.selY
            width: win.selW
            height: win.selH

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: 1
                border.color: SnipState.currentAccent
                Behavior on border.color { CAnim {} }
            }

            CornerAccents {
                anchors.fill: parent
                accentColor: SnipState.currentAccent
                size: Math.max(6, Math.min(14, Math.min(frame.width, frame.height) / 4))
                thickness: 2
            }

            // Dimension readout. Device pixels, because that is what the file
            // will actually contain -- the logical size would be a lie on a
            // scaled output.
            Item {
                id: readout
                width: sizeText.implicitWidth + 16
                height: 20
                // Flips inside the selection when there is no room above it.
                y: frame.y >= 24 ? -24 : frame.height + 4
                x: 0

                CutShape {
                    anchors.fill: parent
                    fillColor: CP.alpha(CP.void2, 0.88)
                    strokeColor: Qt.rgba(SnipState.currentAccent.r,
                                         SnipState.currentAccent.g,
                                         SnipState.currentAccent.b, 0.55)
                    strokeWidth: 1
                    inset: 0.5
                    cutTopLeft: 2
                    cutBottomRight: 2
                }

                Text {
                    id: sizeText
                    anchors.centerIn: parent
                    text: Math.round(win.selW * SnipState.monitorScale) + "×"
                        + Math.round(win.selH * SnipState.monitorScale) + " PX"
                    font.family: "Oxanium"
                    font.pixelSize: 10
                    font.letterSpacing: 2
                    color: SnipState.currentAccent
                }
            }
        }

        // ── Input ────────────────────────────────────────────────────────
        MouseArea {
            id: ma
            anchors.fill: parent
            focus: win.visible
            hoverEnabled: true
            cursorShape: Qt.CrossCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onPressed: mouse => {
                mouse.accepted = true;
                win.startX = mouse.x;
                win.startY = mouse.y;
                win.curX = mouse.x;
                win.curY = mouse.y;
                win.dragging = true;
            }

            onPositionChanged: mouse => {
                if (!win.dragging)
                    return;
                win.curX = mouse.x;
                win.curY = mouse.y;
            }

            onReleased: mouse => {
                win.dragging = false;
                const r = win.clampedRect();
                // A bare click with no drag is a cancel, not a 1x1 snip.
                if (r.w < 2 || r.h < 2) {
                    SnipState.cancel();
                    return;
                }
                if (mouse.button === Qt.RightButton)
                    SnipState.commitAnnotate(r.x, r.y, r.w, r.h);
                else
                    SnipState.commit(r.x, r.y, r.w, r.h);
            }

            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Escape:
                    SnipState.cancel();
                    event.accepted = true;
                    break;
                case Qt.Key_1: SnipState.setTab(0); event.accepted = true; break;
                case Qt.Key_2: SnipState.setTab(1); event.accepted = true; break;
                case Qt.Key_3: SnipState.setTab(2); event.accepted = true; break;
                case Qt.Key_4: SnipState.setTab(3); event.accepted = true; break;
                case Qt.Key_Tab:
                    SnipState.cycleTab(event.modifiers & Qt.ShiftModifier ? -1 : 1);
                    event.accepted = true;
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter: {
                    const r = win.clampedRect();
                    if (r.w >= 2 && r.h >= 2)
                        SnipState.commit(r.x, r.y, r.w, r.h);
                    event.accepted = true;
                    break;
                }
                case Qt.Key_A: {
                    const r = win.clampedRect();
                    if (r.w >= 2 && r.h >= 2)
                        SnipState.commitAnnotate(r.x, r.y, r.w, r.h);
                    event.accepted = true;
                    break;
                }
                }
            }
        }

        // ── Toolbar ──────────────────────────────────────────────────────
        // Bottom-centred, and it slides out of the way when the selection is
        // about to swallow it, so it never hides what is being framed.
        SnipToolbar {
            id: toolbar

            anchors.horizontalCenter: parent.horizontalCenter
            y: {
                const restY = win.height - height - 48;
                if (!win.hasSel)
                    return restY;
                const overlaps = win.selY + win.selH > restY - 12
                              && win.selY < restY + height + 12;
                return overlaps ? 48 : restY;
            }

            Behavior on y { Anim { duration: 200 } }

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Colours.glowFor(SnipState.currentAccent)
                shadowBlur: 0.75
                shadowOpacity: 0.45
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }
        }
    }
}
