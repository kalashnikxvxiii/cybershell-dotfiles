---@diagnostic disable: undefined-global

-- ── split-monitor-workspaces (Lua) ─────────────────────────────────────
-- Pure-Lua package (Hyprland 0.55+) — replace the old plugin C++ via hyprpm.
-- Repo: https://github.com/zjeffer/split-monitor-workspaces (branch `lua`)
-- Installed in: ~/.config/hypr/lib/split-monitor-workspaces/ (separated clone)
--
-- The module register event handlers on monitor.added / monitor.removed / config.reloaded
-- via hl.on(). Setup is ineffective cross-reload thanks to the guard `_G.smw` down here.
local SMW_LIB = os.getenv("HOME") .. "/.config/hypr/lib/split-monitor-workspaces/lua/?.lua"
if not _G.smw then
    if not package.path:find(SMW_LIB, 1, true) then
        package.path = package.path .. ";" .. SMW_LIB
    end
    _G.smw = require("split-monitor-workspaces")
    _G.smw.setup({
        workspace_count              = 10,
        monitor_priority             = { "DP-1", "HDMI-A-1" },
        enable_persistent_workspaces = false,  -- empty ws gets auto-removed
        link_monitors                = false,  -- independents monitor (non Gnome-style)
        keep_focused                 = true,   -- retain focus on reload
        enable_notifications         = false,  -- no toast smw
        enable_wrapping              = true,   -- cycle_workspaces
    })
end
