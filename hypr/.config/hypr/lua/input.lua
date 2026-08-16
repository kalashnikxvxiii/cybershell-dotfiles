---@diagnostic disable: undefined-global

-- ── INPUT ──────────────────────────────────────────────────────────────
hl.config({
    input = {
        kb_layout = "us",
        kb_model  = "pc105",   -- ISO form factor (return ad L)

        numlock_by_default = true,

        repeat_rate  = 50,    -- charater/second
        repeat_delay = 300,   -- ms before repeat

        follow_mouse  = 1,
        sensitivity   = 0,
        accel_profile = "flat",
    },
})

-- See https://wiki.hypr.land/Configuring/Gestures
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
