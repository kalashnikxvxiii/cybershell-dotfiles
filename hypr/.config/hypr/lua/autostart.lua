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
    -- Watchdog: qs gives up if its own restart crashes within 10 s (GPU still exhausted); retry every 10 s.
    -- Only the main shell counts: the panel instances (qs@*.service) and cyberlab all run with -p,
    -- and a dead shell nobody reaped yet (zombie) is not alive
    hl.exec_cmd([[while :; do pgrep -ax -r R,S,D,T 'quickshell|qs' | grep -qv -- ' -p ' || quickshell -n >$XDG_RUNTIME_DIR/quickshell.log 2>&1; sleep 10; done]])
    -- Panels in their own Quickshell process (systemd/qs@.service). The variables are the ones
    -- env.lua and nvidia.lua set and the systemd user manager lacks: without them the panel
    -- would get the default cursor and miss the NVIDIA setup
    hl.exec_cmd("systemctl --user import-environment XCURSOR_THEME XCURSOR_SIZE HYPRCURSOR_SIZE GTK_THEME"
        .. " QT_AUTO_SCREEN_SCALE_FACTOR QT_WAYLAND_DISABLE_WINDOWDECORATION QT_LOGGING_RULES"
        .. " LIBVA_DRIVER_NAME GBM_BACKEND __GLX_VENDOR_LIBRARY_NAME WLR_NO_HARDWARE_CURSORS NVD_BACKEND"
        .. " && systemctl --user start qs@wallpaper qs@manga qs@media")
    hl.exec_cmd("~/.config/hypr/scripts/wallpaper-themer.sh")                                          -- set initial wallpapers
    -- hl.exec_cmd("wl-paste --watch cliphist store")                                                     -- clipboard history daemon
    -- hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")    -- fix Qt theme in portal
    tray_exec("xwaylandvideobridge")                                                                   -- Discord screen share
    hl.exec_cmd("~/.local/bin/discord-guard")                                                          -- Discord (wrapper: ripara gli asar rotti dal repatch Vencord)
    hl.exec_cmd("spicetify watch -l -s")                                                               -- wallust spicetify
end)
