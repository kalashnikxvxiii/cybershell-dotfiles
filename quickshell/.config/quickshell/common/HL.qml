pragma Singleton

import Quickshell
import Quickshell.Hyprland

// Hyprland IPC helper for the 0.55+ Lua provider.
//
// `Hyprland.dispatch(...)` sends a `dispatch <arg>` message. The Lua manager
// wraps it as `return hl.dispatch(<arg>)`. So:
//   • Built-in dispatcher (returns an HL.Dispatcher) → pass `hl.dsp.X({...})`,
//     the wrapper fires it.
//   • Plugin function (immediate side effect, returns nil) → wrap in
//     `function() hl.plugin.NAME.FUNC(...) end` so hl.dispatch calls the
//     function and the side effect runs without a nil-dispatch error.
//   • `exit` etc. → `hl.dsp.exit()` (built-in).
//
// The legacy `hyprctl dispatch "name args"` syntax is BROKEN in Lua mode —
// the wrap becomes `hl.dispatch(name args)` which is invalid Lua.
Singleton {
    id: root

    // Pass a Lua expression that returns a Dispatcher (e.g. `hl.dsp.X({...})`).
    // The dispatch socket auto-wraps with `hl.dispatch(...)`.
    function dispatch(luaExpr) {
        Hyprland.dispatch(luaExpr)
    }

    // Pass arbitrary Lua code with side effects (e.g. plugin function calls).
    // Wrapped in `function() <code> end` so hl.dispatch invokes it without
    // requiring a Dispatcher return value.
    function run(luaCode) {
        Hyprland.dispatch("function() " + luaCode + " end")
    }

    // ── Convenience wrappers for common operations ──────────────────────────
    // workspace target = numeric id, "name:X", "e+1", etc.
    function focusWorkspace(target) {
        if (typeof target === "number")
            dispatch("hl.dsp.focus({workspace = " + target + "})")
        else
            dispatch("hl.dsp.focus({workspace = \"" + target + "\"})")
    }

    function closeWindow(addr) {
        if (!addr) return
        var a = String(addr)
        if (a.indexOf("0x") !== 0) a = "0x" + a
        run("hl.dispatch(hl.dsp.window.close(\"address:" + a + "\"))")
    }

    // Renumbers workspaces. The windows stay where they are and the view stays
    // on the same workspace. The whole batch goes in one dispatch, so a reorder
    // can never be left halfway.
    function changeWorkspaceIds(steps) {
        if (!steps || steps.length === 0) return
        var lua = ""
        for (var i = 0; i < steps.length; i++)
            lua += "hl.dispatch(hl.dsp.workspace.change_id({ workspace = \""
                + steps[i].from + "\", id = " + steps[i].to + " })) "
        run(lua)
    }

    function exit() {
        dispatch("hl.dsp.exit()")
    }
}
