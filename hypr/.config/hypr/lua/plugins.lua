---@diagnostic disable: undefined-global

-- ── PLUGINS CONFIG ─────────────────────────────────────────────────────
hl.config({
    plugin = {
        dynamic_cursors = {
            -- Master switch
            enabled = true,

            -- Mode: "rotate" | "tilt" | "stretch" | "none"
            -- Start with tilt (more subtle and safe)
            mode = "tilt",

            -- Speed ​​threshold below which no deformation is applied (pixels)
            threshold = 2,

            -- Tilt: tilt cursor base on acceleration
            tilt = {
                limit = 5000,
                activation = "negative_quadratic",    -- keyword Lua -> string key
            },

            -- Stretch: stretch the cursor base on velocity
            stretch = {
                limit = 3000,
                activation = "quadratic",
            },

            -- Rotate: smooth rotate on direction changed
            rotate = {
                length = 20,
                offset = 0.0,
            },

            -- Shake to find: shaking mouse -> temporary enlarge the cursor
            shake = {
                enabled = true,
                effects = true,
                threshold = 6.0,
                base = 4.0,         -- base multiplier enlargement
                speed = 4.0,
                timeout = 2000,     -- ms before return normal
            },

            -- Hyprcursor compatibility (rendering nearest-neighbour to avoid blur)
            hyprcursor = {
                enabled = true,
                nearest = true,
            },
        },

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
        -- NB: 0.56 rewrite -> "mode" split into keyboard/mouse; "bounce" mode removed
        hyprfocus = {
            keyboard_focus_animation = "flash",  -- "flash" | "shrink" | "slide" | "none"
            mouse_focus_animation    = "flash",  -- set "none" to pulse only on keyboard focus
            only_on_monitor_change   = false,    -- true = pulse only on monitor changed (more discret)
            fade_opacity             = 1.0,      -- flash: opacity on fade peak
            slide_height             = 20,       -- slide: offset Y in px
            shrink_percentage        = 0.99,     -- shrink: scale factor (ex bounce_strength)
        },

        hyprexpo = {
            columns             = 3,
            gaps_in             = 4,
            gaps_out            = 8,
            bg_col              = "rgb(00060e)",
            workspace_method    = "center current",
            skip_empty          = false,
            -- Drag & drop ws
            drag_drop_enable    = true,
            enable_drag_move    = true,
            -- UX
            enable_keyboard_nav     = true,
            show_workspace_numbers  = true,
            show_pinned_windows     = true,
            animate_entry           = true,
            -- Trackpad gesture
            gesture_fingers     = 0,
            gesture_distance    = 300,
            gesture_direction   = "up",
        },
    },
})
