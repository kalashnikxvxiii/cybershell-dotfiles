---@diagnostic disable: undefined-global

-- ── ENVIRONMENT VARIABLES ──────────────────────────────────────────────
hl.env("XCURSOR_SIZE",                    "24")
hl.env("HYPRCURSOR_SIZE",                 "24")

-- GTK
hl.env("GTK_THEME",                       "adw-gtk3-dark")

-- Qt
hl.env("QT_QPA_PLATFORMTHEME",            "kde")
-- hl.env("QT_STYLE_OVERRIDE",               "kvantum")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR",     "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_LOGGING_RULES",                "qt.qml.propertyCache.append=false")

-- Flatpak
hl.env("XDG_DATA_DIRS", "/var/lib/flatpak/exports/share:" .. os.getenv("HOME") .. "/.local/share/flatpak/exports/share:/usr/local/share:/usr/share")


-- ── PERMISSIONS ────────────────────────────────────────────────────────
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Permission changes require Hyprland restart (not applied on reload).
-- Spec keys (vedi /usr/share/hypr/stubs/hl.meta.lua HL.PermissionSpec):
-- { binary = ..., type = ..., mode = "allow"|"deny"|"ask" }
-- hl.config({ ecosystem = { enforce_permissions = true } })
-- hl.permission({ binary = "/usr/(bin|local/bin)/grim",                            type = "screencopy", mode = "allow" })
-- hl.permission({ binary = "/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", type = "screencopy", mode = "allow" })
-- hl.permission({ binary = "/usr/(bin|local/bin)/hyprpm",                          type = "plugin",     mode = "allow" })
