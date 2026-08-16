---@diagnostic disable: undefined-global

-- ── NVIDIA env vars ────────────────────────────────────────────────────
hl.env("LIBVA_DRIVER_NAME",          "nvidia")
hl.env("XDG_SESSION_TYPE",           "wayland")
hl.env("GBM_BACKEND",                "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME",  "nvidia")
hl.env("WLR_NO_HARDWARE_CURSORS",    "1")
hl.env("NVD_BACKEND",                "direct")

-- ── Cursor + scrolling base ────────────────────────────────────────────
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
