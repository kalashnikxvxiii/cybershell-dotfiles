---@diagnostic disable: undefined-global

-- ── WINDOWS AND WORKSPACES ─────────────────────────────────────────────

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
-- ws 12+ would be created on active monitor during the request.
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

-- Quickshell LogoutOverlay: blur del wallpaper sottostante
hl.layer_rule({
    name  = "qs-logout-blur",
    match = { namespace = "qs-logout" },
    blur  = true,
    animation = "fade",
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

-- Quickshell menu (SUPER+SPACE)
hl.layer_rule({
    name      = "qs-launcher",
    match     = { namespace = "qs-launcher" },
    animation = "fade",
})

-- Standalone radioport (menu → Media)
hl.layer_rule({
    name      = "qs-mediapanel",
    match     = { namespace = "qs-mediapanel" },
    animation = "fade",
})

-- Hyprshot: diable slurp overlay animation + hyprpicker
-- Without this,the overlay selection's fade goes inside the
-- screenshot as white band semi-transparent (issue Gustash/Hyprshot #147)
hl.layer_rule({
    name        = "slurp-no-anim",
    match       = { namespace = "selection" },
    animation   = "none",
})

-- Snip overlay: a region selector must appear instantly, or the first frames of
-- the drag land on a surface that is still fading in. The capture itself cannot
-- be contaminated -- grim runs before this surface exists -- so this is purely
-- about the selector feeling immediate.
hl.layer_rule({
    name        = "snip-overlay-no-anim",
    match       = { namespace = "snip-overlay" },
    animation   = "none",
})

hl.layer_rule({
    name        = "hyprpicker-no-anim",
    match       = { namespace = "hyprpicker" },
    animation   = "none",
})

-- Swaync floating notif: right slide-in / right slide-out
-- Override the global animation "slide top" (layersIn/Out line 237-238)
-- notifications namespace limited, so the other layers are not being touched
hl.layer_rule({
    name        = "swaync-notif-slide",
    match       = { namespace = "swaync-notification-window" },
    animation   = "slide right",
})

-- Swaync control center: slide-in/out from right
hl.layer_rule({
    name        = "swaync-cc-slide",
    match       = { namespace = "swaync-control-center" },
    animation   = "slide-right",
})

-- Manga reader: the panel animates itself in QML — the drawer slides
-- horizontally while the dark backdrop fades on its own timing. Hyprland's
-- global "slide top" would drag the whole surface vertically instead and hide
-- both, so the compositor keeps its hands off this layer.
hl.layer_rule({
    name        = "manga-reader-noanim",
    match       = { namespace = "manga-reader" },
    animation   = "none",
})

-- ── Common app floating ────────────────────────────────────────────────

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

-- xwaylandvideobridge — invisible, needed for screen share on XWayland app
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

-- Steam — tiling for the main window, float for the others
hl.window_rule({
    name  = "steam-main",
    match = { class = "^(steam)$", title = "^(Steam)$" },
    tile  = true,
})

hl.window_rule({
    name  = "steam-popups",
    match = { class = "^(steam)$",
            -- Match every title beside exactly "Steam" (Re2-safe, no lookahead):
            -- empty / <5 char / >5 char / 5 char che non è "Steam"
            title = "^([^S].*|.{0,4}|.{6,}|S[^t].*|St[^e].*|Ste[^a].*|Stea[^m].*|Steam.+)$" },
    float  = true,
    center = true,
})

-- Media player: no blur, full opacity
hl.window_rule({
    name    = "media-players-opaque",
    match   = { class = "^(mpv|vlc|gimp|fl64\\.exe)$" },
    opacity = "override 1.0 override 1.0 override 1.0",
    no_blur = true,
    opaque  = true,
})

-- Stremio + client alternativi (Harbor): always opaque, no blur, no dim when no-focused
-- Real Electron class reverse-DNS: com.stremio.stremio
-- Harbor (Tauri): class runtime "Harbor", StartupWMClass "harbor" -> matcho entrambe
hl.window_rule({
    name    = "stremio-opaque",
    match   = { class = "^(com\\.stremio\\.stremio|[Hh]arbor)$" },
    opacity = "override 1.0 override 1.0 override 1.0",
    opaque  = true,
    no_blur = true,
    no_dim   = true,
}) 

-- Minecraft + PrismLauncher: niente blur/trasparenza
-- "Minecraft\\*.*" matcha tutte le versioni (es. "Minecraft* 26.2", "Minecraft* 1.21.5", …)
hl.window_rule({
    name    = "minecraft-opaque",
    match   = { class = "^(org\\.prismlauncher\\.PrismLauncher|Minecraft\\*.*)$" },
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

-- Video editor
hl.window_rule({
    name    = "video-editor-opaque",
    match   = { class = "^(org\\.kde\\.kdenlive)$" },
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
    match       = { class = "^(steam)$", title = "^(Steam)$" },
    workspace   = "2 silent",
})

hl.window_rule({
    name        = "spotify-ws",
    match       = { class = "^(Spotify)$" },
    workspace   = "12 silent",
})

-- ── Wine ───────────────────────────────────
-- Rete di sicurezza per il systray di Wine. Normalmente non serve: xembedsniproxy
-- (autostart.lua) intercetta le icone XEmbed e le pubblica come StatusNotifierItem,
-- quindi finiscono in Quickshell. Ma se il proxy non sta girando, explorer.exe apre
-- una propria finestrella senza titolo (~166x52) che atterra sopra la barra.
-- Qui la si manda su un workspace speciale invece di vedersela in faccia.
hl.window_rule({
    name        = "wine-systray-hide",
    match       = { class = "^(explorer\\.exe)$", title = "^$" },
    workspace   = "special:winetray silent",
})
