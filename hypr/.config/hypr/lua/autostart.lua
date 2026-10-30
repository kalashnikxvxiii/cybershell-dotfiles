---@diagnostic disable: undefined-global

-- ── AUTOSTART ──────────────────────────────────────────────────────────
-- Autostart necessary processes (notification daemons, status bars, etc.)
-- NB: hyprpm reload load the C++ plugins (borders-plus-plus, ...).
-- The smw plugin Lua-native is already loaded synchronously al require("smw")
-- via require("split-monitor-workspaces") and setup() — don't go throu hyprpm.
--
-- Plugin config NB (split-monitor-workspaces v1.2.0):
-- In Lua mode the plugin expose ONLY the function setters (monitor_priority,
-- max_workspaces) already called in smw.lua. All the classic config keys
-- (keep_focused, enable_notifications, enable_persistent_workspaces,
-- enable_wrapping) are NOT registered → "unknown config key". No timer
-- differed here: the behaviour "remnove empty workspace" is obtained via
-- `hl.workspace_rule({persistent = false})` for all the slots (in rules.lua).
-- App tray avviate prima di Quickshell non si registrano: il watcher lo crea lui e le app non ritentano.
local function tray_exec(cmd)
    hl.exec_cmd("gdbus wait --session --timeout 60 org.kde.StatusNotifierWatcher && " .. cmd)
end

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpm reload -n")                                                                    -- start plugins
    hl.exec_cmd("xrandr --output DP-1 --primary")                                                      -- XWayland primary monitor
    tray_exec("qpwgraph")                                                                              -- easyeffects
    tray_exec("python ~/.local/share/RazerBatteryTray/src/razer_battery_tray.py 'Razer Basilisk V3 Pro 35K Phantom Green Edition (Wireless)'")  -- razer battery tray
    hl.exec_cmd("awww-daemon")                                                                         -- wallpaper daemon (awww)
    hl.exec_cmd("quickshell >$XDG_RUNTIME_DIR/quickshell.log 2>&1")                                    -- Quickshell
    hl.exec_cmd("~/.config/hypr/scripts/wallpaper-themer.sh")                                          -- set initial wallpapers
    hl.exec_cmd("~/.config/hypr/scripts/auto-dnd-fullscreen.sh")                                       -- auto DND in fullscreen
    -- hl.exec_cmd("wl-paste --watch cliphist store")                                                     -- clipboard history daemon
    -- hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")    -- fix Qt theme in portal
    tray_exec("xwaylandvideobridge")                                                                   -- Discord screen share
    hl.exec_cmd("~/.local/bin/discord-guard")                                                          -- Discord (wrapper: ripara gli asar rotti dal repatch Vencord)
    hl.exec_cmd("spicetify watch -l -s")                                                               -- wallust spicetify
end)
