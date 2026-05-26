#!/usr/bin/env bash
# gamemode.sh — toggle effetti compositor per gaming
source "$(dirname "$0")/hyprctl-lua-compat.sh"

# In Lua mode `getoption animations:enabled` ritorna `bool: true/false`
# (in HyprLang era `int: 1/0`). Confronto con "true" per gestire entrambi.
GAMEMODE=$(hyprctl getoption animations:enabled | awk 'NR==1{print $2}')

if [ "$GAMEMODE" = "true" ] || [ "$GAMEMODE" = 1 ]; then
    he 'hl.config({
        animations  = { enabled = false },
        decoration  = {
            shadow          = { enabled = false },
            blur            = { enabled = false },
            rounding        = 0,
            screen_shader   = "",
            dim_inactive    = false,
        },
        general     = { gaps_in = 0, gaps_out = 0, border_size = 1 },
        plugin      = {
            borders_plus_plus = { add_borders = 0 },
        },
    })'
    hyprctl notify 1 4000 "rgb(00ff9d)" "  GAMEMODE ON"
else
    # do NOT use `hyprctl reload`: in Lua mode re-execute `hl.plugin.load` +
    # `monitor_priority` + `max_workspaces` on top of config, re-assigning
    # the workspaces and moving focus on another monitor.
    he 'hl.config({
        animations = { enabled = true },
        decoration = {
            shadow          = { enabled = true },
            blur            = { enabled = true },
            rounding        = 12,
            screen_shader   = os.getenv("HOME") .. "/.config/hypr/shaders/cyberpunk.frag",
            dim_inactive    = true,
        },
        general     = { gaps_in = 4, gaps_out = 12, border_size = 2 },
        plugin      = {
            borders_plus_plus = {add_borders = 2 },
        },
    })'
    hyprctl notify 1 4000 "rgb(ea00d9)" "  GAMEMODE OFF"
fi
