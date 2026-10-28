---@diagnostic disable: undefined-global

-- ── Base config (general/decoration/animations toggle) ─────────────────
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
        rounding       = 34,
        rounding_power = 1,

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
            size     = 6,
            passes   = 3,
            vibrancy = 4,
            noise    = 0.01,
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
hl.curve("easeOutExpo",    { type = "bezier", points = { {0.16, 1},    {0.3,   1}    } })  -- rapid snap → decelleration
hl.curve("easeInOutQuart", { type = "bezier", points = { {0.77, 0},    {0.175, 1}    } })  -- slow → fast  → slow
hl.curve("easeOutBack",    { type = "bezier", points = { {0.34, 1.36}, {0.64,  1}    } })  -- overshoot ahead
hl.curve("easeInBack",     { type = "bezier", points = { {0.36, 0},    {0.66, -0.56} } })  -- initial pull-back
hl.curve("overshot",       { type = "bezier", points = { {0.05, 0.9},  {0.1,   1.1}  } })  -- aggressive overshoot
hl.curve("snap",           { type = "bezier", points = { {0.1,  1.0},  {0.1,   1.0}  } })  -- snappier
-- "linear" is already defined by default from Hyprland (no need to redeclare).

-- ── Windows ──────────────────────────────────────────────────────────
hl.animation({ leaf = "windows",      enabled = true, speed = 5, bezier = "easeOutBack"   })  -- base
hl.animation({ leaf = "windowsIn",    enabled = true, speed = 6, bezier = "snap",        style = "popin"  })  -- opening
hl.animation({ leaf = "windowsOut",   enabled = true, speed = 4, bezier = "linear",      style = "popin"  })  -- closing
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
hl.animation({ leaf = "borderangle", enabled = true, speed = 50, bezier = "linear",     style = "loop" })  -- rotate gradient

-- ── Zoom ──────────────────────────────────────────────────────────────
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 5, bezier = "overshot" })

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║ FOCUS PULSE — VARIANT A: bezier wobble on hyprfocus                      ║
-- ║ Hyprfocus have to keep enable with mode="flash" and fade_opacity ≈ 0.85  ║
-- ║ Effect: one flash with overshoot + bounce-back. ~530ms.                  ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
-- hl.curve("pulseSeq", { type = "bezier", points = { {0.05, 1.6}, {0.4, 0.2} } })

-- NB: the hyprfocusIn/Out leaves exist only once the C++ plugin is loaded, and
-- that happens in `hyprpm reload -n` (autostart.lua) — i.e. AFTER this first
-- parse. Without the guard parse #1 throws "no such animation leaf" and pops
-- the error overlay at boot; hyprpm then reloads the config and parse #2
-- applies them fine. Skip silently until the plugin is actually there.
local function plugin_loaded(name)
    local ok, plugins = pcall(hl.get_loaded_plugins)
    if not ok or type(plugins) ~= "table" then return false end
    for _, p in ipairs(plugins) do
        if type(p) == "table" and p.name == name then return true end
    end
    return false
end

if plugin_loaded("hyprfocus") then
    hl.animation({ leaf = "hyprfocusIn",  enabled = true, speed = 2.5,  bezier = "easeOutBack" })
    hl.animation({ leaf = "hyprfocusOut", enabled = true, speed = 4,    bezier = "easeOutExpo" })
end


-- ╔═════════════════════════════════════════════════════════════════════════════╗
-- ║ FOCUS PULSE — VARIANT B: custom event handler (sequence like Clock)         ║
-- ║ Hyprfocus need to be neutralized: set the fade_opacity = 1.0 in its config. ║
-- ║ Effect: 3 burst alpha/color in sequence burst→settle→micro→settle.          ║
-- ║ Total time: ~325ms (mirros the Clock.qml pattern).                          ║
-- ║ Use hl.dsp.window.set_prop (in-process) — no race from hyprctl.             ║
-- ╚═════════════════════════════════════════════════════════════════════════════╝
hl.on("window.active", function(w)
    if not w or not w.address then return end
    local target = "address:" .. w.address
    local function setp(prop, val)
        hl.dispatch(hl.dsp.window.set_prop({ window = target, prop = prop, value = val }))
    end

    -- Slide hyprfocus lasts ~250ms (speed 2.5). Wait its end
    -- before starting flicker — rise D if the slide appear cutted.
    local D = 200

    -- Burst 1 @ D ms: light dim + whispered magenta
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

    -- vfr moved from misc: on debug: starting from Hyprland 0.55
    debug = {
        vfr = false,
        damage_tracking = 0,
    },

    render = {
        direct_scanout = false,  -- enable only for gaming (can cause flickering on multi-monitor)
    },

    xwayland = {
        force_zero_scaling = true,  -- avoid blur on XWayland apps with scaling
    },

    binds = {
        allow_workspace_cycles = true,  -- Super+Tab return to the last workspace
    },

    cursor = {
        default_monitor = "DP-1",
    },
})
