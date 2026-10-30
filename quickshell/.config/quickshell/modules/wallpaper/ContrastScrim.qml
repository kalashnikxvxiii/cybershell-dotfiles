// ContrastScrim.qml — Adaptive dim behind self-translucent windows
//
// Zen runs with `browser.tabs.allow_transparent_browser`, so the wallpaper
// shows through the page content itself, not just through the chrome: on a
// bright wallpaper the text becomes unreadable. Zen's own transparency cannot
// be answered from Hyprland (a window's alpha only ever makes it *more*
// transparent) nor from userChrome.css (read once at startup), so the only
// lever left is what sits behind the window.
//
// This owns a layer-shell surface on WlrLayer.Bottom: above the wallpaper,
// below every window. It dims only what is seen *through* a window's
// transparent pixels — an opaque window hides it entirely and the effect scales
// with how transparent the window actually is, so nothing needs to know which
// parts of Zen are see-through.
//
// One dimmed rectangle per tracked window, each darkened by the luminance of
// the patch of wallpaper it actually covers.

import CyberGraphics
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../../common"
import "../../common/Colors.js" as CP

Scope {
    id: root

    required property ShellScreen screenObj

    // Window classes that render themselves translucent enough to need this.
    property var windowClasses: ["zen"]

    // Luminance below this reads fine on its own; above it the dim ramps up.
    property real lumFloor: 0.28
    property real lumGain:  0.6
    property real maxDim:   0.25
    // Turned on by hand, so its must always show: this is the dim on a dark wallpaper
    property real minDim: 0.15

    // Mirrors decoration:rounding in hypr/lua/look-and-feel.lua. With
    // rounding_power = 1 Hyprland's superellipse degenerates to a straight
    // line, so the corner is a 45° chamfer of this many px per edge - which is
    // what CutShape's `cut` draws
    property real cornerCut: 34

    // Rects of the tracked windows, in monitor-local pixels, clipped to the
    // monitor: a tiled window can extend past the screen edge.
    property var windowRects: []
    readonly property bool needed: windowRects.length > 0

    // What is actually drawn: outlives windowRects by the length of the fade,
    // because emptying the model destroys the delegates on the spot
    property var shownRects: []

    onWindowRectsChanged: {
        if (windowRects.length > 0) {
            fadeOutHold.stop()
            shownRects = windowRects
        } else {
            fadeOutHold.restart()
        }
    }

    Timer {
        id: fadeOutHold
        interval: 300
        onTriggered: root.shownRects = []
    }

    property string wallpaperPath: ""

    function _rects() {
        if (!WallpaperState.scrimEnabled)
            return []
        const mon = Hyprland.monitorFor(root.screenObj)
        const ws = mon ? mon.activeWorkspace : null
        if (!ws || !ws.toplevels)
            return []

        const sx = root.screenObj.x, sy = root.screenObj.y
        const sw = root.screenObj.width, sh = root.screenObj.height
        const tls = ws.toplevels.values
        const out = []

        for (let i = 0; i < tls.length; i++) {
            const o = tls[i].lastIpcObject
            if (!o || !o.at || !o.size)
                continue
            const cls = o.class ?? tls[i].wayland?.appId ?? ""
            if (root.windowClasses.indexOf(cls) < 0)
                continue

            const rx0 = o.at[0] - sx, ry0 = o.at[1] - sy
            const rx1 = rx0 + o.size[0], ry1 = ry0 + o.size[1]
            const x0 = Math.max(0, rx0), y0 = Math.max(0, ry0)
            const x1 = Math.min(sw, rx1), y1 = Math.min(sh, ry1)
            if (x1 - x0 < 16 || y1 - y0 < 16)
                continue

            // A side that we clipped, or that sits flush against the monitor
            // edge, is not a visible window edge: the two corners on it have no
            // chamfer to follow, and cutting them would carve into the window.
            // Flush also covers a fullscreen window, which Hyprland never rounds
            const inL = rx0 > 0, inR = rx1 < sw
            const inT = ry0 > 0, inB = ry1 < sh
            const c = Math.min(root.cornerCut, (x1 - x0) / 2, (y1 - y0) / 2)

            out.push({
                x: x0, y: y0, w: x1 - x0, h: y1 - y0,
                cutTL: (inT && inL) ? c : 0, cutTR: (inT && inR) ? c : 0,
                cutBR: (inB && inR) ? c : 0, cutBL: (inB && inL) ? c : 0
            })
        }
        return out
    }

    // Assign only on a real change: the rects drive both the delegates and the
    // regions being analysed, and replacing the model re-runs both.
    function _sync() {
        const next = root._rects()
        if (JSON.stringify(next) !== JSON.stringify(root.windowRects))
            root.windowRects = next
    }

    Connections {
        target: WallpaperState
        function onScrimEnabledChanged() { root._sync() }
    }

    // Hyprland emits no event for a resize, so polling is the only way to catch
    // one; slow down to a heartbeat while nothing is being tracked.
    Timer {
        interval: root.needed ? 500 : 1500
        running: WallpaperState.scrimEnabled
        triggeredOnStart: true
        repeat: true
        onTriggered: {
            Hyprland.refreshToplevels()
            root._sync()
        }
    }

    // wallpaper-themer.sh records the live wallpaper per screen here, and keeps
    // doing so during a playlist cycle — when WallpaperState.screenPaths is
    // deliberately left empty so awww owns the transition.
    FileView {
        id: currentFile
        path: (Quickshell.env("HOME") || "") + "/.cache/wallpaper-themer/current_" + root.screenObj.name
        watchChanges: true
        onLoaded: root._setWallpaper(currentFile.text())
        onFileChanged: reload()
    }

    function _setWallpaper(raw) {
        let p = (raw || "").trim()
        while (p.endsWith("/"))
            p = p.slice(0, -1)

        const isWpe = p.indexOf("/steamcmd-isolated/") >= 0
        if (isWpe) {
            // A WPE entry is a directory, not an image: analyse the catalogue
            // thumbnail the picker already generated for it (the same frame awww
            // shows while linux-wallpaperengine initialises).
            const key = p.slice(p.lastIndexOf("/") + 1)
            root.wallpaperPath = (Quickshell.env("HOME") || "") + "/.cache/wallpaper-picker/thumbs/" + key + ".jpg"
            // linux-wallpaperengine puts its own surface on WlrLayer.Bottom, and
            // within a layer the newest surface wins: started after us, it covers
            // this one. Recreating our surface puts it back on top. Its startup
            // takes a few seconds and varies, hence more than one attempt.
            restack.attempts = 3
            restack.restart()
        } else {
            root.wallpaperPath = p
        }
    }

    Timer {
        id: restack
        property int attempts: 0
        interval: 3000
        repeat: true
        onTriggered: {
            root._recreate()
            attempts -= 1
            if (attempts <= 0)
                stop()
        }
    }

    function _recreate() {
        surface.active = false
        surface.active = true
    }

    // A window appearing is the other moment our surface may need to be the
    // newest one on the layer.
    onNeededChanged: if (needed) _recreate()

    Loader {
        id: surface
        active: true

        sourceComponent: PanelWindow {
            screen: root.screenObj
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "contrast-scrim"
            anchors { top: true; bottom: true; left: true; right: true }
            exclusiveZone: -1
            color: "transparent"
            mask: Region {}  // never take input: this is decoration, not a surface to click

            Repeater {
                model: root.shownRects

                delegate: Item {
                    id: dim

                    required property var modelData

                    x: dim.modelData.x
                    y: dim.modelData.y
                    width: dim.modelData.w
                    height: dim.modelData.h

                    opacity: root.needed ? Math.max(root.minDim, Math.min(root.maxDim,
                                (region.luminance - root.lumFloor) * root.lumGain))
                            : 0
                    // Slow on purpose: this must not pop when switching workspace.
                    Behavior on opacity { Anim { duration: 300 } }

                    // Follows the window's chamfered corners, so the dim stops
                    // where the window does instead of poking out onto the bare
                    // wallpaper at each corner
                    CutShape {
                        anchors.fill: parent
                        // A single flat fill does not need a multisampled FBO the
                        // size of the window, reallocated on every resize
                        layer.enabled: false
                        fillColor: CP.void_
                        cutTopLeft: dim.modelData.cutTL
                        cutTopRight: dim.modelData.cutTR
                        cutBottomRight: dim.modelData.cutBR
                        cutBottomLeft: dim.modelData.cutBL
                    }

                    // The patch of wallpaper this window covers, in normalised
                    // image coordinates. Assumes the wallpaper fills the screen
                    // (both are 16:9 here); a differently shaped image samples a
                    // slightly shifted patch, which only nudges the dim.
                    ImageAnalyser {
                        id: region
                        source: root.wallpaperPath
                        rescaleSize: 64
                        sampleRect: Qt.rect(dim.x / dim.parent.width, dim.y / dim.parent.height,
                                            dim.width / dim.parent.width, dim.height / dim.parent.height)
                    }
                }
            }
        }
    }
}
