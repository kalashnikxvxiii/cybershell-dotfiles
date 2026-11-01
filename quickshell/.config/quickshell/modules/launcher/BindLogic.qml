// BindLogic.qml -- what the two keybind forms share: capturing a combination, checking it
// against `hyprctl binds`, saving through user-binds.py. While capturing, Hyprland sits in an
// empty submap, or it would swallow the combination; Esc and a timeout both bring it back.
import QtQuick
import Quickshell.Io
import "../../common"

Item {
    id: root

    // { index, name, keys, command }; index -1 is a new bind
    property var draft: null
    signal closed()
    // Capture is over, one way or the other: the form takes the keyboard back
    signal captureEnded()

    property string keys: ""
    property string conflict: ""
    property string status: ""
    property bool capturing: false
    property bool deleteArmed: false
    readonly property bool busy: saveProc.running

    readonly property string script: Qt.resolvedUrl("../../scripts/user-binds.py").toString().replace("file://", "")

    onDraftChanged: {
        stopCapture()
        keys = draft ? draft.keys : ""
        conflict = ""
        status = ""
        deleteArmed = false
    }
    Component.onDestruction: stopCapture()

    function startCapture() {
        capturing = true
        status = ""
        HL.dispatch('hl.dsp.submap("bind-capture")')
        captureGuard.restart()
    }

    function stopCapture() {
        captureGuard.stop()
        if (!capturing)
            return
        capturing = false
        HL.dispatch('hl.dsp.submap("reset")')
    }

    function keyName(key, scanCode) {
        if (key >= Qt.Key_A && key <= Qt.Key_Z)
            return String.fromCharCode(key)
        if (key >= Qt.Key_0 && key <= Qt.Key_9)
            return String.fromCharCode(key)
        if (key >= Qt.Key_F1 && key <= Qt.Key_F24)
            return "F" + (key - Qt.Key_F1 + 1)
        const names = {}
        names[Qt.Key_Space] = "SPACE"
        names[Qt.Key_Return] = "Return"
        names[Qt.Key_Tab] = "Tab"
        names[Qt.Key_Backspace] = "BackSpace"
        names[Qt.Key_Delete] = "Delete"
        names[Qt.Key_Insert] = "Insert"
        names[Qt.Key_Home] = "Home"
        names[Qt.Key_End] = "End"
        names[Qt.Key_PageUp] = "Prior"
        names[Qt.Key_PageDown] = "Next"
        names[Qt.Key_Left] = "left"
        names[Qt.Key_Right] = "right"
        names[Qt.Key_Up] = "up"
        names[Qt.Key_Down] = "down"
        names[Qt.Key_Comma] = "comma"
        names[Qt.Key_Period] = "period"
        names[Qt.Key_Slash] = "slash"
        names[Qt.Key_Minus] = "minus"
        names[Qt.Key_Equal] = "equal"
        names[Qt.Key_QuoteLeft] = "grave"
        names[Qt.Key_Print] = "Print"
        // Whatever the layout makes of the other keys, their physical code still works
        return names[key] !== undefined ? names[key] : "code:" + scanCode
    }

    // Only modifiers down, or a bare key: capture keeps waiting
    function capture(key, modifiers, scanCode) {
        const lone = [Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_AltGr, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_Hyper_L, Qt.Key_Hyper_R]
        if (lone.indexOf(key) >= 0)
            return
        const mods = []
        if (modifiers & Qt.MetaModifier) mods.push("SUPER")
        if (modifiers & Qt.ControlModifier) mods.push("CTRL")
        if (modifiers & Qt.AltModifier) mods.push("ALT")
        if (modifiers & Qt.ShiftModifier) mods.push("SHIFT")
        const name = keyName(key, scanCode)
        // A bare letter would stop being typeable everywhere
        if (mods.length === 0 && !/^F[0-9]+$/.test(name)) {
            status = "Needs a modifier: SUPER, CTRL or ALT"
            return
        }
        keys = mods.concat([name]).join(" + ")
        stopCapture()
        status = ""
        conflict = ""
        checkProc.command = ["python3", script, "check", keys, draft ? draft.name : ""]
        checkProc.running = true
        captureEnded()
    }

    function save(name, command) {
        saveProc.command = ["python3", script, "save", String(draft.index), name, keys, command]
        saveProc.running = true
    }

    function remove() {
        if (!deleteArmed) {
            deleteArmed = true
            return
        }
        saveProc.command = ["python3", script, "remove", String(draft.index)]
        saveProc.running = true
    }

    function cancel() {
        stopCapture()
        closed()
    }

    Timer {
        id: captureGuard
        interval: 15000
        onTriggered: {
            root.stopCapture()
            root.status = "Capture timed out"
            root.captureEnded()
        }
    }

    Connections {
        target: LauncherState
        function onCaptureCancelled() {
            if (!root.capturing)
                return
            // The submap's own Esc has already left it
            root.capturing = false
            captureGuard.stop()
            root.captureEnded()
        }
    }

    Process {
        id: checkProc
        stdout: StdioCollector {
            onStreamFinished: root.conflict = text.trim()
        }
    }

    Process {
        id: saveProc
        stderr: StdioCollector {
            onStreamFinished: if (text !== "") root.status = text.trim()
        }
        onExited: code => {
            if (code === 0)
                root.closed()
        }
    }
}
