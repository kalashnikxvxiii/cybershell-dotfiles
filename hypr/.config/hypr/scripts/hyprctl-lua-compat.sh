#!/usr/bin/env bash
# Hyprland 0.55+ Lua mode compatibility shims.
#
# Under the Lua config provider, `hyprctl dispatch X args` wraps as
# `return hl.dispatch(X args)` and parses as Lua → syntax error for any
# multi-word legacy dispatcher (workspace 1, focuswindow address:0xABC,
# plugin dispatchers like split-workspace, etc.).
#
# `hl.dsp.exec_raw` is NOT the escape hatch: it spawns a program (fork+exec,
# no shell). My earlier guess was wrong — using it for legacy dispatchers
# silently fails because the dispatcher name is not a real binary.
#
# Real solutions:
# 1) Built-in dispatchers → use the Lua-native API on `hl.dsp.*` (focus,
#    window.move, window.close, layout, exit, ...). The socket auto-wraps
#    with hl.dispatch, so just pass the expression that returns a Dispatcher.
# 2) Plugin dispatchers → call the plugin function directly. Plugins are
#    exposed under `hl.plugin.<snake_case_name>.<func>`. e.g.
#    `split-monitor-workspaces` C++ plugin was esposto via `hl.plugin.split_monitor_workspaces.X`.
#    Ora usiamo la versione Lua pura (require("split-monitor-workspaces")), esposta
#    come `smw.X` globale da hyprland.lua. Vedi sotto.
#    These functions have IMMEDIATE side effects and return nil, so they
#    cannot be passed through `hyprctl dispatch` (which wraps with
#    hl.dispatch and erroes on nil). Use `hyprctl eval` instead.
# 3) Config keywords (animation, workspace rule, general:layout, ...) →
#    use `hyprctl eval 'hl.<api>({...})'`. `hyprctl keyword` is rejected:
#    "keyword can't work with non-legacy parsers. Use eval."
#
# Enumerate available APIs at runtime:
#   hyprctl eval 'for k in pairs(hl.dsp)    do print(k) end'   (no-op: eval discards output)
#   hyprctl eval 'local s={}; for k in pairs(hl.dsp) do table.insert(s,k) end;
#                 local f=io.open("/tmp/x","w"); f:write(table.concat(s,"\n")); f:close()'
#
# Source this lib from any script that needs dispatch/eval against Hyprland:
#   source "$(dirname "$0")/hyprctl-lua-compat.sh"

# Built-in dispatcher — pass a Lua expression that returns an HL.Dispatcher
# value. The dispatch socket auto-wraps with `return hl.dispatch(<expr>)`.
# Example: hd 'hl.dsp.focus({workspace = "name:1"})'
hd() {
    hyprctl dispatch "$*"
}

# Plugin dispatcher (immediate side effect, returns nil → can't go through
# the dispatch wrapper). Pass a full Lua call.
# Examples:
#   hp 'hl.dispatch(smw.workspace("2"))'                          (smw package)
#   hp 'hl.dispatch(smw.move_to_workspace("3"))'
#   hp 'hl.dispatch(smw.cycle_workspaces("next"))'
hp() {
    hyprctl eval "$*"
}

# Config keyword / Lua-only API (animations, workspace rules, hl.config, …).
# Example: he 'hl.config({general = {layout = "dwindle"}})'
he() {
    hyprctl eval "$*"
}
