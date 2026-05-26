-- Hyprland Lua config — migrated from hyprland.conf (HyprLang) for Hyprland 0.55+
-- Original config preserved as hyprland.conf.bak
-- API reference: /usr/share/hypr/stubs/hl.meta.lua  |  Wiki: https://wiki.hypr.land

---@diagnostic disable: undefined-global
-- `hl` is provided by the Hyprland Lua runtime; LSP users should add
-- /usr/share/hypr/stubs/ to workspace.library for full type checking.

------------------
---- NVIDIA ----
------------------
hl.env("LIBVA_DRIVER_NAME",          "nvidia")
hl.env("XDG_SESSION_TYPE",           "wayland")
hl.env("GBM_BACKEND",                "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME",  "nvidia")
hl.env("WLR_NO_HARDWARE_CURSORS",    "1")
hl.env("NVD_BACKEND",                "direct")

hl.config({
    cursor = {
        no_hardware_cursors = true,
        zoom_factor         = 1.0,
        zoom_rigid          = true,
    },

    -- https://wiki.hypr.land/Configuring/Layouts/#scrolling
    scrolling = {
        fullscreen_on_one_column = true,
        column_width             = 0.75,
        follow_focus             = true,
        explicit_column_widths   = "0.333 0.5 0.667 1.0",
    },
})


--------------------------------------
---- split-monitor-workspaces (Lua) ----
--------------------------------------
-- Pure-Lua package (Hyprland 0.55+) — sostituisce il vecchio plugin C++ via hyprpm.
-- Repo: https://github.com/zjeffer/split-monitor-workspaces (branch `lua`)
-- Installato in: ~/.config/hypr/lib/split-monitor-workspaces/ (clone separato)
--
-- Il modulo registra event handlers su monitor.added / monitor.removed / config.reloaded
-- via hl.on(). Setup è idempotente cross-reload grazie al guard `_G.smw` qui sotto.
local SMW_LIB = os.getenv("HOME") .. "/.config/hypr/lib/split-monitor-workspaces/lua/?.lua"
if not _G.smw then
    if not package.path:find(SMW_LIB, 1, true) then
        package.path = package.path .. ";" .. SMW_LIB
    end
    _G.smw = require("split-monitor-workspaces")
    _G.smw.setup({
        workspace_count              = 10,
        monitor_priority             = { "DP-1", "HDMI-A-1" },
        enable_persistent_workspaces = false,  -- ws vuote si auto-rimuovono
        link_monitors                = false,  -- monitor indipendenti (non Gnome-style)
        keep_focused                 = true,   -- preserva focus al reload
        enable_notifications         = false,  -- niente toast smw
        enable_wrapping              = true,   -- cycle_workspaces avvolge
    })
end


------------------
---- MONITORS ----
------------------
-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})


---------------------
---- MY PROGRAMS ----
---------------------
local terminal    = "kitty"
local fileManager = "dolphin"
local menu        = "hyprlauncher"


-------------------
---- AUTOSTART ----
-------------------
-- Autostart necessary processes (notification daemons, status bars, etc.)
-- NB: hyprpm reload load the C++ plugins (borders-plus-plus, ...).
-- The smw plugin Lua-native is already loaded synchronously at the top of the file
-- via require("split-monitor-workspaces") and setup() - don't go through hyprpm
--
-- Plugin config NB (split-monitor-workspaces v1.2.0):
-- In Lua mode il plugin espone SOLO i function setter (monitor_priority,
-- max_workspaces) già chiamati in cima al file. Tutte le chiavi config classiche
-- (keep_focused, enable_notifications, enable_persistent_workspaces,
-- enable_wrapping) NON sono registrate → "unknown config key". Niente timer
-- differito qui: il comportamento "rimuovi workspace vuoti" lo otteniamo via
-- `hl.workspace_rule({persistent = false})` per tutti gli slot (vedi sotto).
hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpm reload -n")                                                                    -- start plugins
    hl.exec_cmd("xrandr --output DP-1 --primary")                                                      -- XWayland primary monitor
    hl.exec_cmd("qpwgraph")                                                                            -- audio
    hl.exec_cmd("easyeffects")                                                                         -- easyeffects
    hl.exec_cmd("python ~/.local/share/RazerBatteryTray/src/razer_battery_tray.py 'Razer Basilisk V3 Pro 35K Phantom Green Edition (Wireless)'")  -- razer battery tray
    hl.exec_cmd("nm-applet --indicator")                                                               -- network manager tray
    hl.exec_cmd("awww-daemon")                                                                         -- wallpaper daemon (awww)
    hl.exec_cmd("quickshell")                                                                          -- Quickshell
    hl.exec_cmd("~/.config/hypr/scripts/wallpaper-themer.sh")                                          -- set initial wallpapers
    -- hl.exec_cmd("hypridle")                                                                         -- idle management — disabled (desktop)
    hl.exec_cmd("swaync")                                                                              -- notification daemon
    -- hl.exec_cmd("hyprlauncher --daemon")                                                            -- app launcher (pre-loaded) - disabled: daemon herd by HL_INITIAL_WORKSPACE_TOKEN stale -> app always opened in the startup ws 
    hl.exec_cmd("wl-paste --watch cliphist store")                                                     -- clipboard history daemon
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")    -- fix Qt theme in portal
    hl.exec_cmd("xwaylandvideobridge")                                                                 -- Discord screen share
    -- hl.exec_cmd("cava")                                                                             -- cava — audio visualizer
    hl.exec_cmd("discord")                                                                             -- Discord
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------
hl.env("XCURSOR_SIZE",                    "24")
hl.env("HYPRCURSOR_SIZE",                 "24")

-- GTK
hl.env("GTK_THEME",                       "adw-gtk3-dark")

-- Qt
hl.env("QT_QPA_PLATFORMTHEME",            "qt6ct")
hl.env("QT_STYLE_OVERRIDE",               "kvantum")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR",     "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_LOGGING_RULES",                "qt.qml.propertyCache.append=false")

-- Flatpak
hl.env("XDG_DATA_DIRS", "/var/lib/flatpak/exports/share:" .. os.getenv("HOME") .. "/.local/share/flatpak/exports/share:/usr/local/share:/usr/share")


-----------------------
----- PERMISSIONS -----
-----------------------
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Permission changes require Hyprland restart (not applied on reload).
-- Spec keys (vedi /usr/share/hypr/stubs/hl.meta.lua HL.PermissionSpec):
-- { binary = ..., type = ..., mode = "allow"|"deny"|"ask" }
-- hl.config({ ecosystem = { enforce_permissions = true } })
-- hl.permission({ binary = "/usr/(bin|local/bin)/grim",                            type = "screencopy", mode = "allow" })
-- hl.permission({ binary = "/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", type = "screencopy", mode = "allow" })
-- hl.permission({ binary = "/usr/(bin|local/bin)/hyprpm",                          type = "plugin",     mode = "allow" })


-----------------------
---- LOOK AND FEEL ----
-----------------------
hl.config({
    general = {
        gaps_in     = 4,
        gaps_out    = 12,

        border_size = 2,

        col = {
            active_border   = { colors = { "rgba(ea00d9ee)", "rgba(0abdc6ee)" }, angle = 45 },
            inactive_border = "rgba(1a1a2e88)",
        },

        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 12,
        rounding_power = 2,

        -- ── Dim ────────
        dim_inactive     = true,
        dim_strength     = 0.20,    -- 0.0 no dim, 1.0 full black (range 0-1)
        dim_special      = 0.5,     -- dim on special workspace (scratchpad)
        dim_around       = 0.5,     -- dim on the rest of the screen when a floating has focus (dialog/popup)

        -- ── Screen shader: scanline + chromatic aberration ─────────
        screen_shader = os.getenv("HOME") .. "/.config/hypr/shaders/cyberpunk.frag",

        active_opacity   = 0.90,
        inactive_opacity = 0.95,

        shadow = {
            enabled      = true,
            range        = 12,
            render_power = 3,
            color        = "rgba(ea00d915)",
        },

        blur = {
            enabled  = true,
            size     = 9,
            passes   = 3,
            vibrancy = 1,
            noise    = 0.03,
            xray     = true,
            special  = true,
            popups   = true,
        },
    },

    animations = {
        enabled = true,
    },
})

-- ── Curves ─────────────────────────────────────────────────────────────
hl.curve("easeOutExpo",    { type = "bezier", points = { {0.16, 1},    {0.3,   1}    } })  -- scatto rapido → decelerazione
hl.curve("easeInOutQuart", { type = "bezier", points = { {0.77, 0},    {0.175, 1}    } })  -- lento → veloce → lento
hl.curve("easeOutBack",    { type = "bezier", points = { {0.34, 1.36}, {0.64,  1}    } })  -- overshoot in avanti
hl.curve("easeInBack",     { type = "bezier", points = { {0.36, 0},    {0.66, -0.56} } })  -- pull-back iniziale
hl.curve("overshot",       { type = "bezier", points = { {0.05, 0.9},  {0.1,   1.1}  } })  -- overshoot aggressivo
hl.curve("snap",           { type = "bezier", points = { {0.1,  1.0},  {0.1,   1.0}  } })  -- snappissimo
-- "linear" è già definito di default da Hyprland (no need to redeclare).

-- ── Finestre ──────────────────────────────────────────────────────────
hl.animation({ leaf = "windows",      enabled = true, speed = 5, bezier = "easeOutBack"   })  -- base
hl.animation({ leaf = "windowsIn",    enabled = true, speed = 6, bezier = "snap",        style = "popin"  })  -- opening
hl.animation({ leaf = "windowsOut",   enabled = true, speed = 4, bezier = "linear",      style = "popin"  })  -- chiusura
hl.animation({ leaf = "windowsMove",  enabled = true, speed = 5, bezier = "easeOutExpo", style = "slide"  })  -- drag/swap

-- ── Fade ──────────────────────────────────────────────────────────────
hl.animation({ leaf = "fade",         enabled = true, speed = 5, bezier = "easeOutExpo"    })
hl.animation({ leaf = "fadeIn",       enabled = true, speed = 6, bezier = "easeOutExpo"    })
hl.animation({ leaf = "fadeOut",      enabled = true, speed = 4, bezier = "easeInOutQuart" })
hl.animation({ leaf = "fadeSwitch",   enabled = true, speed = 5, bezier = "easeOutExpo"    })
hl.animation({ leaf = "fadeShadow",   enabled = true, speed = 5, bezier = "easeOutExpo"    })

-- ── Layer (quickshell, swaync, wlogout…) ──────────────────────────────
hl.animation({ leaf = "layers",        enabled = true, speed = 4, bezier = "easeOutExpo"    })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 5, bezier = "easeOutExpo",   style = "slide top" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 3, bezier = "easeOutExpo",   style = "slide top" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 4, bezier = "easeOutExpo"    })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 3, bezier = "easeInOutQuart" })

-- ── Workspace ─────────────────────────────────────────────────────────
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "easeInOutQuart", style = "slide" })

-- ── Special workspace (scratchpad) ────────────────────────────────────
hl.animation({ leaf = "specialWorkspace",    enabled = true, speed = 6, bezier = "easeOutBack", style = "slidevert" })
hl.animation({ leaf = "specialWorkspaceIn",  enabled = true, speed = 6, bezier = "easeOutBack", style = "slidevert" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 5, bezier = "easeInBack",  style = "slidevert" })

-- ── Border ────────────────────────────────────────────────────────────
hl.animation({ leaf = "border",      enabled = true, speed = 50, bezier = "easeOutExpo" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 50, bezier = "linear",     style = "loop" })  -- gradiente rotante

-- ── Zoom ──────────────────────────────────────────────────────────────
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 5, bezier = "overshot" })

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║ FOCUS PULSE — VARIANTE A: bezier wobble su hyprfocus                 ║
-- ║ Hyprfocus deve restare attivo con mode="flash" e fade_opacity ≈ 0.85 ║
-- ║ Effetto: un singolo flash con overshoot + bounce-back. ~530ms.       ║
-- ╚══════════════════════════════════════════════════════════════════════╝
-- hl.curve("pulseSeq", { type = "bezier", points = { {0.05, 1.6}, {0.4, 0.2} } })

hl.animation({ leaf = "hyprfocusIn",  enabled = true, speed = 2.5,  bezier = "easeOutBack" })
hl.animation({ leaf = "hyprfocusOut", enabled = true, speed = 4,    bezier = "easeOutExpo" })


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║ FOCUS PULSE — VARIANTE B: custom event handler (sequence à la Clock) ║
-- ║ Hyprfocus va neutralizzato: setta fade_opacity = 1.0 nel suo config. ║
-- ║ Effetto: 3 burst alpha/colore in sequenza burst→settle→micro→settle. ║
-- ║ Tempo totale: ~325ms (rispecchia il pattern di Clock.qml).           ║
-- ║ Usa hl.dsp.window.set_prop (in-process) — niente race da hyprctl.    ║
-- ╚══════════════════════════════════════════════════════════════════════╝
hl.on("window.active", function(w)
    if not w or not w.address then return end
    local target = "address:" .. w.address
    local function setp(prop, val)
        hl.dispatch(hl.dsp.window.set_prop({ window = target, prop = prop, value = val }))
    end

    -- Slide hyprfocus dura ~250ms (speed 2.5). Aspettiamo che finisca
    -- prima di iniziare il flicker — alza D se lo slide appare tagliato.
    local D = 200

    -- Burst 1 @ D ms: dim leggero + magenta sussurrato
    hl.timer(function()
        setp("opacity", "0.78")
        setp("active_border_color", "rgba(ea00d9aa)")
    end, { timeout = D, type = "oneshot" })

    -- Reset 1 @ D+55
    hl.timer(function()
        setp("opacity", "0.92")
        setp("active_border_color", "rgb(ea00d9ee) rgb(0abdc6ee) 45deg")
    end, { timeout = D + 55, type = "oneshot" })

    -- Burst 2 @ D+110: cyan tick
    hl.timer(function()
        setp("opacity", "0.85")
        setp("active_border_color", "rgba(25e1edaa)")
    end, { timeout = D + 110, type = "oneshot" })

    -- Settle @ D+165
    hl.timer(function()
        setp("opacity", "0.92")
        setp("active_border_color", "rgb(ea00d9ee) rgb(0abdc6ee) 45deg")
    end, { timeout = D + 165, type = "oneshot" })

    -- Burst 3 @ D+285: micro magenta
    hl.timer(function()
        setp("opacity", "0.88")
        setp("active_border_color", "rgba(ea00d988)")
    end, { timeout = D + 285, type = "oneshot" })

    -- Cleanup @ D+325
    hl.timer(function()
        setp("opacity", "0.90")
        setp("active_border_color", "rgb(ea00d9ee) rgb(0abdc6ee) 45deg")
    end, { timeout = D + 325, type = "oneshot" })
end)

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/
hl.config({
    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper     = 0,
        disable_hyprland_logo       = true,
        animate_manual_resizes      = true,
        focus_on_activate           = false,
        enable_swallow              = true,
        swallow_regex               = "^(kitty)$",
        initial_workspace_tracking  = 2,
    },

    -- vfr spostato da misc: a debug: a partire da Hyprland 0.55
    debug = {
        vfr = false,
    },

    render = {
        direct_scanout = false,  -- attiva solo per gaming (può causare flickering su multi-monitor)
    },

    xwayland = {
        force_zero_scaling = true,  -- evita blur su app XWayland con scaling
    },

    binds = {
        allow_workspace_cycles = true,  -- Super+Tab torna al workspace precedente
    },

    cursor = {
        default_monitor = "DP-1",
    },
})

------------------------
---- PLUGINS CONFIG ----
------------------------
hl.config({
    plugin = {
        -- borders-plus-plus: multiple borders stacked for neon layered CP2077 style
        -- Order: main border (general) -> border_1 (inner) -> border_2 (outer)
        borders_plus_plus = {
            add_borders         = 2,
            natural_rounding    = true,
            col = {
                border_1 = "rgba(25e1edaa)",   -- cyan tech (netrunner)
                border_2 = "rgba(fcec0caa)",   -- yellow body (power)
            },
            border_size_1 = 2,
            border_size_2 = 1,
        },

        -- hyprfocus: animated pulse on focus change
        hyprfocus = {
            mode                    = "flash",  -- "flash" | "bounce" | "slide"
            only_on_monitor_change  = false,    -- true = pulse only on monitor changed (more discret)
            fade_opacity            = 1.0,      -- mode=flash: opacity on fade peak
            slide_height            = 20,       -- mode=slide: offset Y in px (0-150)
            bounce_strength         = 0.99,     -- mode=bounce: scale width (0-1)
        },
    },
})

---------------
---- INPUT ----
---------------
hl.config({
    input = {
        kb_layout = "us",
        kb_model  = "pc105",   -- ISO form factor (return ad L)

        numlock_by_default = true,

        repeat_rate  = 50,    -- caratteri al secondo
        repeat_delay = 300,   -- ms prima del repeat

        follow_mouse  = 1,
        sensitivity   = 0,
        accel_profile = "flat",
    },
})

-- See https://wiki.hypr.land/Configuring/Gestures
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })


---------------------
---- KEYBINDINGS ----
---------------------
local mainMod = "SUPER"

-- Helper: muovi la finestra attiva al "monitor adiacente" (l/r). Necessario perché
-- hl.dsp.window.move({monitor = "l"/"r"}) non accetta alias direzionali — serve il nome
-- del monitor. Per 2 monitor è semplice: l'altro monitor è "l'altro".
local function move_to_other_monitor()
    local cur = hl.get_active_monitor()
    if not cur then return end
    for _, m in ipairs(hl.get_monitors()) do
        if m.id ~= cur.id then
            hl.dispatch(hl.dsp.window.move({ monitor = m.name }))
            return
        end
    end
end

-- +++++++++++++++++++ Applications +++++++++++++++++++
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("pkill -KILL -x " .. menu .. "; rm -f $XDG_RUNTIME_DIR/.hyprlauncher.sock; " .. menu))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("zen-browser"))
hl.bind(mainMod .. " + slash", hl.dsp.exec_cmd("kitty --class floating -e less -R ~/.config/hypr/hyprland-keys.txt"))
hl.bind(mainMod .. " + F1",    hl.dsp.exec_cmd("kitty --class floating -e less -R ~/.config/hypr/hyprland-keys.txt"))

-- +++++++++++++++++++ Window management +++++++++++++++++++

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Resize active window — tieni premuto per ripetere (resizeactive: relative=true → delta)
hl.bind(mainMod ..         " + equal", hl.dsp.window.resize({ x =  40, y =   0, relative = true }), { repeating = true })  -- più larga
hl.bind(mainMod ..         " + minus", hl.dsp.window.resize({ x = -40, y =   0, relative = true }), { repeating = true })  -- più stretta
hl.bind(mainMod .. " + SHIFT + equal", hl.dsp.window.resize({ x =   0, y =  40, relative = true }), { repeating = true })  -- più alta
hl.bind(mainMod .. " + SHIFT + minus", hl.dsp.window.resize({ x =   0, y = -40, relative = true }), { repeating = true })  -- più bassa

-- Move focus
hl.bind(mainMod .. " + left",  hl.dsp.exec_cmd("~/.config/hypr/scripts/focus-horizontal.sh l"))
hl.bind(mainMod .. " + right", hl.dsp.exec_cmd("~/.config/hypr/scripts/focus-horizontal.sh r"))
hl.bind(mainMod .. " + up",    hl.dsp.exec_cmd("~/.config/hypr/scripts/focus-vertical.sh u"))
hl.bind(mainMod .. " + down",  hl.dsp.exec_cmd("~/.config/hypr/scripts/focus-vertical.sh d"))

-- Cicla focus tra finestre del workspace (swapnext)
hl.bind(mainMod ..         " + Tab", hl.dsp.window.cycle_next())
hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.window.cycle_next("prev"))

-- Scambia finestra adiacente (tiling, swapwindow l/r/u/d)
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.window.swap({ direction = "l" }))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.swap({ direction = "r" }))
hl.bind(mainMod .. " + CTRL + up",    hl.dsp.window.swap({ direction = "u" }))
hl.bind(mainMod .. " + CTRL + down",  hl.dsp.window.swap({ direction = "d" }))

-- Fullscreen monocle: toggle "maximized" (occupa il workspace rispettando bar/gaps).
-- NB: l'API Lua vuole {mode = "maximized"|"fullscreen"} — passare l'integer 1
-- (sintassi HyprLang) viene silenziosamente ignorato e cade sul default "fullscreen".
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized" }))

-- Pseudo-tile (dwindle)
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())

-- Toggle split
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))

-- Floating
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))

-- Sposta finestra floating (moveactive: relative=true → delta)
hl.bind(mainMod .. " + ALT + left",  hl.dsp.window.move({ x = -20, y =   0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + ALT + right", hl.dsp.window.move({ x =  20, y =   0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + ALT + up",    hl.dsp.window.move({ x =   0, y = -20, relative = true }), { repeating = true })
hl.bind(mainMod .. " + ALT + down",  hl.dsp.window.move({ x =   0, y =  20, relative = true }), { repeating = true })

-- Sposta finestra tra monitor (con 2 monitor l/r equivalgono a "l'altro")
hl.bind(mainMod .. " + SHIFT + comma",  move_to_other_monitor)
hl.bind(mainMod .. " + SHIFT + period", move_to_other_monitor)

-- Minimize
hl.bind(mainMod ..         " + H", hl.dsp.exec_cmd("~/.config/hypr/scripts/minimize.sh minimize"))
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.exec_cmd("~/.config/hypr/scripts/minimize.sh restore"))

-- +++++++++++++++++++ Utilities +++++++++++++++++++
-- Clipboard
hl.bind(mainMod .. " + SHIFT + V",        hl.dsp.exec_cmd("~/.config/hypr/scripts/clipboard.sh"))         -- incolla da history
hl.bind(mainMod .. " + CTRL + V",         hl.dsp.exec_cmd("~/.config/hypr/scripts/clipboard.sh delete"))  -- elimina singola voce
hl.bind(mainMod .. " + CTRL + SHIFT + V", hl.dsp.exec_cmd("~/.config/hypr/scripts/clipboard.sh wipe"))    -- svuota tutto

-- Color picker (hyprpicker)
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd("hyprpicker -a"))

-- Toggle notification center
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("swaync-client -t"))

-- Toggle cursor zoom (in-process: legge config corrente e aggiorna)
hl.bind(mainMod .. " + ALT + mouse_down", function()
    local cur = hl.get_config("cursor.zoom_factor") or 1.0
    hl.config({ cursor = { zoom_factor = cur + 0.5 } })
end)
hl.bind(mainMod .. " + ALT + mouse_up", function()
    local cur = hl.get_config("cursor.zoom_factor") or 1.0
    local nxt = cur - 0.5
    if nxt < 1.0 then nxt = 1.0 end
    hl.config({ cursor = { zoom_factor = nxt } })
end)

-- +++++++++++++++++++ Workspaces +++++++++++++++++++
-- Switch workspaces — animation randomized per script
for i = 1, 10 do
    local key = i % 10  -- 10 maps to key 0
    hl.bind(mainMod ..         " + " .. key, hl.dsp.exec_cmd("~/.config/hypr/scripts/ws-switch.sh goto " .. i))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.exec_cmd("~/.config/hypr/scripts/ws-switch.sh move " .. i))
end

-- Scratchpad
hl.bind(mainMod ..         " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind(mainMod .. " + CTRL + S",         hl.dsp.exec_cmd("~/.config/hypr/scripts/scratchpad.sh pull-one"))
hl.bind(mainMod .. " + CTRL + SHIFT + S", hl.dsp.exec_cmd("~/.config/hypr/scripts/scratchpad.sh pull-all"))

-- Hyprscrolling - navigazione nastro e resize colonne
hl.bind(mainMod ..         " + comma",  hl.dsp.layout("move -col"))
hl.bind(mainMod ..         " + period", hl.dsp.layout("move +col"))
hl.bind(mainMod .. " + CTRL + comma",   hl.dsp.layout("colresize -conf"))
hl.bind(mainMod .. " + CTRL + period",  hl.dsp.layout("colresize +conf"))

-- Scroll workspace
hl.bind(mainMod .. " + mouse_down", hl.dsp.exec_cmd("~/.config/hypr/scripts/ws-switch.sh next"))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.exec_cmd("~/.config/hypr/scripts/ws-switch.sh prev"))

-- +++++++++++++++++++ Screenshot +++++++++++++++++++
hl.bind(            "Print", hl.dsp.exec_cmd("hyprshot -m region"))
hl.bind(mainMod ..         " + Print", hl.dsp.exec_cmd("hyprshot -m output"))
hl.bind(mainMod .. " + SHIFT + Print", hl.dsp.exec_cmd("hyprshot -m window"))

-- Wallpaper
hl.bind(mainMod ..                " + W", hl.dsp.exec_cmd("~/.config/hypr/scripts/wallpaper-themer.sh smart"))
hl.bind(mainMod .. " + SHIFT + W",        hl.dsp.exec_cmd("~/.config/hypr/scripts/wallpaper-themer.sh toggle-mode"))
hl.bind(mainMod .. " + CTRL + W",         hl.dsp.exec_cmd("~/.config/hypr/scripts/wallpaper-themer.sh toggle-auto"))
hl.bind(mainMod .. " + ALT + W",          hl.dsp.exec_cmd("~/.config/hypr/scripts/wallpaper-themer.sh toggle-order"))
hl.bind(mainMod .. " + SHIFT + ALT + W",  hl.dsp.exec_cmd("~/.config/hypr/scripts/wallpaper-themer.sh toggle-pool"))
hl.bind(mainMod .. " + M",                hl.dsp.exec_cmd("~/.config/hypr/scripts/wallpaper-themer.sh audio-toggle"))
hl.bind(mainMod .. " + SHIFT + M",        hl.dsp.exec_cmd("~/.config/hypr/scripts/wallpaper-themer.sh audio-up"))
hl.bind(mainMod .. " + CTRL + M",         hl.dsp.exec_cmd("~/.config/hypr/scripts/wallpaper-themer.sh audio-down"))
hl.bind(mainMod .. " + SHIFT + P",        hl.dsp.exec_cmd("~/.config/quickshell/scripts/wallpaper-picker.sh toggle"))

-- +++++++++++++++++++ Multimedia +++++++++++++++++++
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })

-- Toggle screen_shader (scanline + chromatic) on/off
hl.bind(mainMod .. " + F11", function()
    local cyberShader = os.getenv("HOME") .. "/.config/hypr/shaders/cyberpunk.frag"
    local cur = hl.get_config("decoration.screen_shader") or ""
    hl.config({ decoration = { screen_shader = (cur == "" and cyberShader or "") } })
end)

hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- +++++++++++++++++++ Display +++++++++++++++++++
hl.bind(mainMod .. " + F8",       hl.dsp.exec_cmd("pgrep hyprsunset && pkill hyprsunset || hyprsunset -t 4500"))
hl.bind(mainMod .. " + F9",       hl.dsp.exec_cmd("~/.config/hypr/scripts/gamemode.sh"))
hl.bind(mainMod .. " + F10",      hl.dsp.exec_cmd("nwg-displays"))
hl.bind(mainMod .. " + ALT + R",  hl.dsp.exec_cmd("~/.config/hypr/scripts/recorder.sh"))

-- Window opacity (xglass-style)
hl.bind("CTRL + ALT + V", hl.dsp.exec_cmd("~/.config/hypr/scripts/opacity.sh toggle"))  -- 100% ↔ 60%
hl.bind("CTRL + ALT + X", hl.dsp.exec_cmd("~/.config/hypr/scripts/opacity.sh up"))      -- +10%
hl.bind("CTRL + ALT + Z", hl.dsp.exec_cmd("~/.config/hypr/scripts/opacity.sh down"))    -- -10%

-- Brightness
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

-- +++++++++++++++++++ System +++++++++++++++++++
hl.bind(mainMod .. " + L",                hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + SHIFT + E",        hl.dsp.exec_cmd("wlogout -b 3 -c 20 -r 20 -m 200"))
-- Quick logout (no menu): `uwsm stop` turns off the session compositor + user's
-- services in order, so sddm-helper exit with code 0 and SDDM restart the greeter.
-- (The old `hyprctl dispatch exit` is HyprLang syntax — in Lua mode it would give parse error
-- "return hl.dispatch(exit)". Furthermore `loginctl terminate-user` would force-kill sddm-helper,
-- leaving SDDM blocked on a black TTY — see wlogout layout for the
-- same fix menu side.)
hl.bind(mainMod .. " + SHIFT + ESCAPE",   hl.dsp.exec_cmd("uwsm stop"))


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- Layout per-workspace.
-- DP-1 (priority 0): ws 1-10 | HDMI-A-1 (priority 1): ws 11-20
-- Persistence is managed by the Lua smw module (enable_persistent_workspaces=false):
-- adding `persistent = false` here is not needed anymore — smw don't add persistent rules
-- and Hyprland remove empty ws by default.
hl.workspace_rule({ workspace = "1", monitor = "DP-1", default = true,  layout = "scrolling" })
hl.workspace_rule({ workspace = "2",  layout = "scrolling" })
hl.workspace_rule({ workspace = "11", layout = "monocle"   })
hl.workspace_rule({ workspace = "12", layout = "master"    })
-- Pin extra ws in HDMI-A-1 (smw binds only the "first" workspace of each
-- monitor with enabled_persistent_workspace=false). Without this rule,
-- ws 12+ would be created on the active monitor during the request.
hl.workspace_rule({ workspace = "12", monitor = "HDMI-A-1" })

-- ── Window rules ──────────────────────────────────────────────────────

hl.window_rule({
    name           = "suppress-maximize-events",
    match          = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move  = "20 monitor_h-120",
    float = true,
})

-- ── Layer rules ───────────────────────────────────────────────────────

hl.layer_rule({
    name  = "wlogout-blur",
    match = { namespace = "wlogout" },
    blur  = true,
})

hl.layer_rule({
    name      = "wpe-animation",
    match     = { namespace = "linux-wallpaperengine" },
    animation = "none",
})

hl.layer_rule({
    name      = "wallpaper-picker",
    match     = { namespace = "wallpaper-picker" },
    animation = "popin 80%",
})

-- ── App floating comuni ────────────────────────────────────────────────

hl.window_rule({
    name   = "float-pavucontrol",
    match  = { class = "^(pavucontrol)$" },
    float  = true,
    size   = "800 500",
    center = true,
})

hl.window_rule({
    name   = "float-nm-editor",
    match  = { class = "^(nm-connection-editor)$" },
    float  = true,
    center = true,
})

hl.window_rule({
    name   = "float-file-chooser",
    match  = { title = "^(Open File|Save File|Open Folder|Choose Files?|Apri|Salva|Seleziona)(.*)$" },
    float  = true,
    size   = "900 600",
    center = true,
})

hl.window_rule({
    name   = "float-dialogs",
    match  = { class = "^(xdg-desktop-portal-gtk)$" },
    float  = true,
    center = true,
})

hl.window_rule({
    name   = "float-confirm-dialogs",
    match  = { class = ".+", title = "^(Confirm|Conferma|Warning|Avviso|Error|Errore|Question|Are you sure.*)$" },
    float  = true,
    center = true,
})

hl.window_rule({
    name  = "float-picture-in-picture",
    match = { title = "^(Picture.in.[Pp]icture)$" },
    float = true,
    pin   = true,
    size  = "640 360",
    move  = "100%-660 100%-380",
})

hl.window_rule({
    name   = "float-calculator",
    match  = { class = "^(gnome-calculator|qalculate-gtk|kcalc)$" },
    float  = true,
    center = true,
})

hl.window_rule({
    name   = "float-blueman",
    match  = { class = "^(blueman-manager)$" },
    float  = true,
    size   = "600 500",
    center = true,
})

hl.window_rule({
    name   = "float-hyprlock-input",
    match  = { class = "^(org.kde.polkit-kde-authentication-agent-1)$" },
    float  = true,
    center = true,
})

-- xwaylandvideobridge — invisibile, serve per screen share su app XWayland
hl.window_rule({
    name             = "xwayland-video-bridge-fixes",
    match            = { class = "xwaylandvideobridge" },
    no_initial_focus = true,
    no_focus         = true,
    no_anim          = true,
    no_blur          = true,
    max_size         = "1 1",
    opacity          = 0.0,
})

-- Steam — tiling per la finestra principale, float per le altre
hl.window_rule({
    name  = "steam-main",
    match = { class = "^(steam)$", title = "^(Steam)$" },
    tile  = true,
})

hl.window_rule({
    name   = "steam-popups",
    match  = { class = "^(steam)$", title = "^(?!Steam$).*$" },
    float  = true,
    center = true,
})

-- Media player: niente blur, opacità piena
hl.window_rule({
    name    = "media-players-opaque",
    match   = { class = "^(mpv|vlc|gimp|stremio)$" },
    opacity = "override 1.0 override 1.0 override 1.0",
    no_blur = true,
    opaque  = true,

})

hl.window_rule({
    name    = "browser-opaque-blur",
    match   = { class = "^(zen)$" },
    opacity = "override 1.0 override 1.0 override 1.0",
    opaque  = true,
})

-- Image viewers
hl.window_rule({
    name    = "image-viewers-opaque",
    match   = { class = "^(eog|geeqie|imv|vimiv|feh)$" },
    opacity = "override 1.0 override 1.0 override 1.0",
    no_blur = true,
    opaque  = true,
})

-- ── Apps in dedicated workspaces ───────────
hl.window_rule({
    name        = "discord-ws",
    match       = { class = "^(discord)$" },
    workspace   = "11 silent",
})

hl.window_rule({
    name        = "cursor-ws",
    match       = { class = "^(cursor)$" },
    workspace   = "1 silent",
})

hl.window_rule({
    name        = "steam-ws",
    match       = { class = "^(steam)$" },
    workspace   = "2 silent",
})

hl.window_rule({
    name        = "spotify-ws",
    match       = { class = "^(Spotify)$" },
    workspace   = "12 silent",
})
