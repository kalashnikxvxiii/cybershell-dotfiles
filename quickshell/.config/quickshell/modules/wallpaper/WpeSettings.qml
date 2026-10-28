pragma ComponentBehavior: Bound

import "../../common/Colors.js" as CP
import "../../common/effects"
import "../../common"
import Quickshell
import Quickshell.Io
import QtQuick

// Engine flags and project.json user properties for one WPE wallpaper.
// The engine has no live control channel: values reach it only as launch
// arguments, so they are saved as an argv file that every launcher
// (picker preview, themer set/restore/playlist) appends, and APPLY respawns.
Item {
    id: root

    property string wpePath: ""             // "" when the selected card is not a WPE
    property real maxWidth: 520
    property real maxHeight: 270
    property bool live: false               // picker shown on this screen
    property bool open: false

    signal applyRequested(string path)
    signal focusReturn()

    readonly property string wpeId: wpePath.substring(wpePath.lastIndexOf("/") + 1)
    readonly property string settingsFile: Quickshell.env("HOME")
        + "/.config/quickshell/wpe-settings/" + wpeId + ".args"

    // Engine options share the property value form; "@" keeps them apart
    readonly property var _engineDefaults: ({
        "@fps": "30", "@scaling": "default", "@clamp": "clamp",
        "@mouse": "1", "@parallax": "1", "@particles": "1"
    })
    readonly property var _engineRows: [
        { type: "group", label: "ENGINE" },
        { key: "@fps", type: "slider", label: "FPS LIMIT", min: 10, max: 240, isInt: true, decimals: 0 },
        { key: "@scaling", type: "combo", label: "SCALING", options: _opts(["default", "stretch", "fit", "fill"]) },
        { key: "@clamp", type: "combo", label: "CLAMP", options: _opts(["clamp", "border", "repeat"]) },
        { key: "@mouse", type: "bool", label: "MOUSE INTERACTION" },
        { key: "@parallax", type: "bool", label: "PARALLAX" },
        { key: "@particles", type: "bool", label: "PARTICLES" }
    ]
    readonly property var _kinds: ["bool", "slider", "combo", "color", "textinput", "group", "text"]

    property var _defs: []                  // rows parsed from project.json
    property var _defaults: _engineDefaults
    property var _saved: ({})               // non-default values found in the args file
    property var vals: ({})

    readonly property var _rows: _engineRows
        .concat([{ type: "group", label: "SCENE PROPERTIES" }])
        .concat(_defs.length ? _defs : [{ type: "text", label: "NO CUSTOM PROPERTIES" }])
    readonly property bool dirty: _toArgs(vals).join("\n")
        !== _toArgs(Object.assign({}, _defaults, _saved)).join("\n")

    function _opts(list) { return list.map(v => ({ label: v.toUpperCase(), value: v })) }

    function _ser(v) {
        if (typeof v === "boolean") return v ? "1" : "0"
        return (typeof v === "number" || typeof v === "string") ? String(v) : ""
    }

    // WPE labels carry HTML and untranslated "ui_browse_properties_*" keys
    function _label(text, fallback) {
        var s = String(text || "").replace(/<[^>]*>/g, "").trim()
        if (s.startsWith("ui_browse_properties_")) s = s.substring(21).replace(/_/g, " ")
        return (s || fallback).toUpperCase()
    }

    function _parseDefs(json) {
        var props = (json.general || {}).properties || {}
        var out = []
        for (var k in props) {
            var d = props[k]
            if (!d || _kinds.indexOf(d.type) < 0) continue
            out.push({
                key: k, type: d.type, label: _label(d.text, k), def: _ser(d.value),
                min: d.min ?? 0, max: d.max ?? 100, isInt: !d.fraction, decimals: d.precision ?? 2,
                options: (d.options || []).map(o => ({ label: _label(o.label, _ser(o.value)), value: _ser(o.value) })),
                order: d.order ?? d.index ?? 1e9
            })
        }
        return out.sort((a, b) => a.order - b.order)
    }

    function _toArgs(m) {
        var a = []
        for (var k in m) {
            var v = m[k]
            if (v === _defaults[k]) continue
            if (k === "@fps" || k === "@scaling" || k === "@clamp") a.push("--" + k.substring(1), v)
            else if (k[0] === "@") a.push("--disable-" + k.substring(1))   // engine toggles default on
            else a.push("--set-property", k + "=" + v)
        }
        return a
    }

    function _fromArgs(text) {
        var m = {}, l = text.split("\n")
        for (var i = 0; i < l.length; i++) {
            var s = l[i]
            if (s === "--fps" || s === "--scaling" || s === "--clamp") m["@" + s.substring(2)] = l[++i] || ""
            else if (s.startsWith("--disable-")) m["@" + s.substring(10)] = "0"
            else if (s === "--set-property") {
                var kv = l[++i] || "", eq = kv.indexOf("=")
                if (eq > 0) m[kv.substring(0, eq)] = kv.substring(eq + 1)
            }
        }
        return m
    }

    function _sync() { vals = Object.assign({}, _defaults, _saved) }

    function set(key, v) {
        var m = Object.assign({}, vals)
        m[key] = v
        vals = m
    }

    function reset() { vals = Object.assign({}, _defaults) }

    function apply() {
        var args = _toArgs(vals)
        saveProc.command = ["bash", "-c",
            'mkdir -p "${0%/*}" && if [ $# -eq 0 ]; then rm -f "$0"; else printf "%s\\n" "$@" > "$0"; fi',
            settingsFile].concat(args)
        saveProc.running = true
        _saved = _fromArgs(args.join("\n"))
        _sync()
    }

    // Colors: project.json holds "r g b" in 0-1; the engine reads a value
    // without a dot as 0-255, so written colors always carry decimals
    function _toQColor(v) {
        var p = String(v).replace(/,/g, " ").trim().split(/\s+/).map(Number)
        if (p.length < 3 || p.some(isNaN)) return "#000000"
        var s = p.some(x => x > 1) ? 255 : 1
        return Qt.rgba(p[0] / s, p[1] / s, p[2] / s, 1)
    }
    function _fromHex(hex) {
        var c = Qt.color(hex)
        return [c.r, c.g, c.b].map(x => x.toFixed(4)).join(" ")
    }

    onWpePathChanged: { _defs = []; _defaults = _engineDefaults; _saved = {}; _sync() }

    FileView {
        path: root.wpePath ? root.wpePath + "/project.json" : ""
        printErrors: false
        onLoaded: {
            try { root._defs = root._parseDefs(JSON.parse(text())) } catch (e) { root._defs = [] }
            var d = Object.assign({}, root._engineDefaults)
            root._defs.forEach(r => { if (r.def !== undefined) d[r.key] = r.def })
            root._defaults = d
            root._sync()
        }
    }

    FileView {
        path: root.wpePath ? root.settingsFile : ""
        printErrors: false                  // no file = all defaults
        onLoaded: { root._saved = root._fromArgs(text()); root._sync() }
        onLoadFailed: { root._saved = {}; root._sync() }
    }

    Process {
        id: saveProc
        onExited: code => { if (code === 0) root.applyRequested(root.wpePath) }
    }

    Pulse { id: dirtyPulse; running: root.live && root.open && root.dirty; from: 1.0; to: 0.55; halfMs: 600; sine: true }

    // Grows from the gear's corner; the picker anchors it bottom-right
    visible: open || wpePath !== ""
    width: open ? maxWidth : 40
    height: open ? maxHeight : 40
    clip: true

    Behavior on width  { NumberAnimation { duration: 260; easing.type: Easing.OutQuart } }
    Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutQuart } }

    CutShape {
        anchors.fill: parent
        fillColor: CP.moduleBg
        strokeColor: CP.alpha(CP.yellow, root.open ? 0.45 : 0.3)
        strokeWidth: 1; inset: 0.5
        cutTopLeft: root.open ? 16 : 8
    }

    // Fixed size, so the canvas does not repaint on every frame of the expansion
    Item {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: root.maxWidth; height: root.maxHeight
        opacity: 0.06
        ScanlineOverlay { lineColor: Colours.scanlineColor }
    }

    // ── Expanded content ──
    Item {
        anchors.fill: parent
        opacity: root.open ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 34

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                width: 5; height: 14
                color: Colours.accentPrimary
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.verticalCenter: parent.verticalCenter
                text: "WPE CONFIG"
                font.family: "Oxanium"; font.pixelSize: 13; font.bold: true; font.letterSpacing: 3
                color: Colours.accentPrimary
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: root.wpeId ? "ID:" + root.wpeId : "· NO ENGINE WALLPAPER"
                font.family: "Oxanium"; font.pixelSize: 9; font.letterSpacing: 1.5
                color: Colours.textMuted
            }
        }

        Rectangle {
            id: headerSep
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: CP.alpha(CP.yellow, 0.25)
        }

        ListView {
            id: list
            anchors.top: headerSep.bottom
            anchors.bottom: footer.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 10
            anchors.rightMargin: 14
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            visible: root.wpePath !== ""
            model: root._rows

            delegate: Item {
                id: row
                required property var modelData
                readonly property string val: root.vals[modelData.key] ?? ""

                width: list.width
                height: modelData.type === "slider" ? 40 : modelData.type === "group" ? 28 : 24

                Text {
                    visible: row.modelData.type !== "slider"
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: row.modelData.type === "group" || row.modelData.type === "text"
                        ? parent.width : parent.width * 0.45
                    text: row.modelData.type === "group" ? "◢ " + row.modelData.label : row.modelData.label
                    font.family: "Oxanium"
                    font.pixelSize: row.modelData.type === "group" ? 10 : 9
                    font.bold: row.modelData.type === "group"
                    font.letterSpacing: row.modelData.type === "group" ? 3 : 1.5
                    color: row.modelData.type === "group" ? Colours.accentSecondary : Colours.textMuted
                    elide: Text.ElideRight
                }

                Loader {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: row.modelData.type === "slider" ? parent.width : parent.width * 0.52
                    sourceComponent: ({ slider: cSlider, bool: cBool, combo: cCombo,
                                        color: cColor, textinput: cText })[row.modelData.type] ?? null
                }

                Component {
                    id: cSlider
                    Slider {
                        label: row.modelData.label
                        minValue: row.modelData.min
                        maxValue: row.modelData.max
                        isInt: row.modelData.isInt
                        decimals: row.modelData.decimals
                        value: Number(row.val)
                        onValueEdited: v => root.set(row.modelData.key, String(v))
                    }
                }

                Component {
                    id: cBool
                    Item {
                        height: 18
                        readonly property bool on: row.val === "1" || row.val === "true"
                        Item {
                            anchors.right: parent.right
                            width: 54; height: 18
                            CutShape {
                                anchors.fill: parent
                                fillColor: parent.parent.on ? CP.alpha(CP.cyan, 0.2)
                                         : boolMa.containsMouse ? CP.alpha(CP.yellow, 0.12) : "transparent"
                                strokeColor: parent.parent.on ? Colours.accentSecondary : CP.alpha(Colours.textMuted, 0.5)
                                strokeWidth: 1; inset: 0.5
                                cutTopLeft: 3; cutBottomRight: 3
                                Behavior on fillColor { ColorAnimation { duration: 120 } }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: parent.parent.on ? "ON" : "OFF"
                                font.family: "Oxanium"; font.pixelSize: 9; font.letterSpacing: 1.5
                                color: parent.parent.on ? Colours.accentSecondary : Colours.textMuted
                            }
                            MouseArea {
                                id: boolMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.set(row.modelData.key, parent.parent.on ? "0" : "1")
                            }
                        }
                    }
                }

                Component {
                    id: cCombo
                    Item {
                        id: combo
                        height: 18
                        readonly property var opts: row.modelData.options
                        readonly property int idx: Math.max(0, opts.findIndex(o => o.value === row.val))
                        function step(d) {
                            if (opts.length) root.set(row.modelData.key, opts[(idx + d + opts.length) % opts.length].value)
                        }

                        CutShape {
                            anchors.fill: parent
                            fillColor: CP.alpha(CP.yellow, 0.06)
                            strokeColor: CP.alpha(CP.yellow, 0.35)
                            strokeWidth: 1; inset: 0.5
                            cutTopLeft: 3; cutBottomRight: 3
                        }
                        Repeater {
                            model: [-1, 1]
                            Text {
                                required property int modelData
                                anchors.verticalCenter: parent.verticalCenter
                                x: modelData < 0 ? 6 : combo.width - width - 6
                                text: modelData < 0 ? "◂" : "▸"
                                font.pixelSize: 11
                                color: arrowMa.containsMouse ? Colours.accentPrimary : CP.alpha(CP.yellow, 0.55)
                                Behavior on color { ColorAnimation { duration: 120 } }
                                MouseArea {
                                    id: arrowMa
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: combo.step(parent.modelData)
                                }
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 36
                            horizontalAlignment: Text.AlignHCenter
                            text: combo.opts.length ? combo.opts[combo.idx].label : row.val
                            font.family: "Oxanium"; font.pixelSize: 9; font.letterSpacing: 1
                            color: Colours.accentPrimary
                            elide: Text.ElideRight
                        }
                    }
                }

                Component {
                    id: cColor
                    Item {
                        height: 18
                        readonly property color c: root._toQColor(row.val)
                        Rectangle {
                            id: swatch
                            anchors.right: hexField.left
                            anchors.rightMargin: 6
                            width: 18; height: 18
                            color: parent.c
                            border.color: CP.alpha(CP.cyan, 0.5)
                        }
                        Field {
                            id: hexField
                            anchors.right: parent.right
                            width: 84
                            text: parent.c.toString().toUpperCase()
                            onEdited: t => { if (/^#[0-9a-fA-F]{6}$/.test(t)) root.set(row.modelData.key, root._fromHex(t)) }
                        }
                    }
                }

                Component {
                    id: cText
                    Field {
                        text: row.val
                        onEdited: t => root.set(row.modelData.key, t)
                    }
                }
            }
        }

        // ── Footer: actions on the left, the gear keeps the corner ──
        Item {
            id: footer
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: 40
            height: 40

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                visible: root.wpePath !== ""

                Repeater {
                    model: [
                        { label: "RESET", danger: true },
                        { label: "APPLY", danger: false }
                    ]
                    Item {
                        id: btn
                        required property var modelData
                        width: btnLbl.implicitWidth + 24; height: 22
                        opacity: btn.modelData.danger ? 1 : dirtyPulse.k
                        readonly property color accent: btn.modelData.danger ? CP.red : CP.yellow

                        CutShape {
                            anchors.fill: parent
                            fillColor: btnMa.containsMouse ? CP.alpha(btn.accent, 0.22) : CP.alpha(btn.accent, 0.08)
                            strokeColor: CP.alpha(btn.accent, !btn.modelData.danger && root.dirty ? 0.9 : 0.45)
                            strokeWidth: 1; inset: 0.5
                            cutTopLeft: 4; cutBottomRight: 4
                            Behavior on fillColor { ColorAnimation { duration: 120 } }
                        }
                        Text {
                            id: btnLbl
                            anchors.centerIn: parent
                            text: btn.modelData.label
                            font.family: "Oxanium"; font.pixelSize: 10; font.letterSpacing: 1.5
                            color: btn.modelData.danger ? Colours.accentDanger : Colours.accentPrimary
                        }
                        MouseArea {
                            id: btnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: btn.modelData.danger ? root.reset() : root.apply()
                        }
                    }
                }
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: root.dirty ? "· UNSAVED" : "· SAVED"
                font.family: "Oxanium"; font.pixelSize: 9; font.letterSpacing: 2
                color: root.dirty ? CP.alpha(CP.yellow, 0.65) : Colours.textMuted
                visible: root.wpePath !== ""
            }
        }
    }

    // ── Gear ──
    Item {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 40; height: 40

        Text {
            anchors.centerIn: parent
            text: "\uf013"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 18
            color: gearMa.containsMouse || root.open ? Colours.accentPrimary : CP.alpha(CP.yellow, 0.6)
            rotation: root.open ? 90 : 0
            Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutQuart } }
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        MouseArea {
            id: gearMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.open = !root.open
        }
    }

    component Field: Item {
        id: field
        property string text
        signal edited(string t)
        height: 18

        CutShape {
            anchors.fill: parent
            fillColor: CP.alpha(CP.cyan, 0.06)
            strokeColor: input.activeFocus ? Colours.accentSecondary : CP.alpha(CP.cyan, 0.3)
            strokeWidth: 1; inset: 0.5
            cutTopLeft: 3; cutBottomRight: 3
        }
        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            text: field.text
            font.family: "Oxanium"; font.pixelSize: 9; font.letterSpacing: 1
            color: Colours.accentSecondary
            selectionColor: CP.alpha(CP.cyan, 0.35)
            onTextEdited: field.edited(text.replace(/\n/g, " "))
            onAccepted: root.focusReturn()
            // Unhandled keys must not reach the carousel shortcuts behind
            Keys.priority: Keys.AfterItem
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) root.focusReturn()
                event.accepted = true
            }
        }
    }
}
