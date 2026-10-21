---@diagnostic disable: undefined-global

-- ── KEYBINDINGS ────────────────────────────────────────────────────────
-- Adapter on globals: mantaining the short local variable to not
-- rewrite thousands of bind lines (mainMod .. " + ..." remain identic).
local mainMod     = HL_MAIN_MOD
local terminal    = HL_TERMINAL
local fileManager = HL_FILE_MANAGER
local menu        = HL_MENU

-- Helper: move the active window to the "adiacent monitor" (l/r). Necessary because
-- hl.dsp.window.move({monitor = "l"/"r"}) don't accept directional aliases — need the monitor's
-- name. For 2 monitor is easy: the other monitor is "the other".
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

-- Helper: swap "crash-proof". swapwindow (ITarget::swap) on a window
-- FLOATING send in SEGV Hyprland 0.55.2 (std::bad_variant_access in
-- Layout::CAlgorithm::recalculate: a floating do not have tiling target to
-- change). Guard: if the active window is floating (or is not there), the swap is
-- not applyable → do nothing. Only the tiled windows execute swapwindow.
local function safe_swap(direction)
    return function()
        local w = hl.get_active_window()
        if not w or w.floating then return end
        hl.dispatch(hl.dsp.window.swap({ direction = direction }))
        hl.dispatch(hl.dsp.exec_cmd(
            "canberra-gtk-play -i completion-rotation -V 0.4 " ..
            "--property=canberra.xdg-theme.name=cyberpunk-2077"
        ))
    end
end

-- +++++++++++++++++++ Quickshell +++++++++++++++++++
hl.bind(mainMod .. " + CTRL + Q", hl.dsp.exec_cmd("pkill quickshell && quickshell >$XDG_RUNTIME_DIR/quickshell.log 2>&1"))
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
-- Manga Reader
hl.bind(mainMod .. " + ALT + M", hl.dsp.exec_cmd("~/.config/quickshell/scripts/manga-toggle.sh"))

-- Sonar panel (network / bluetooth)
hl.bind(mainMod .. " + ALT + N", hl.dsp.exec_cmd("~/.config/quickshell/scripts/sonar-toggle.sh net"))
hl.bind(mainMod .. " + ALT + B", hl.dsp.exec_cmd("~/.config/quickshell/scripts/sonar-toggle.sh bt"))

-- +++++++++++++++++++ Applications +++++++++++++++++++
hl.bind(mainMod .. " + grave", hl.dsp.exec_cmd("kitten quick-access-terminal"))
-- Sempre via discord-guard, mai `discord` diretto: il wrapper ripara gli asar
-- rotti dal repatch Vencord e riafferma la decodifica video software.
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("~/.local/bin/discord-guard"))
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
-- Quickshell menu (modules/launcher); the old hyprlauncher bind is kept below, commented
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("qs ipc call launcher toggle"))
-- hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("pkill -KILL -x " .. menu .. "; rm -f $XDG_RUNTIME_DIR/.hyprlauncher.sock; " .. menu))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("zen-browser"))
hl.bind(mainMod .. " + slash", hl.dsp.exec_cmd("kitty --class floating -e less -R ~/.config/hypr/hyprland-keys.txt"))
-- hl.bind(mainMod .. " + F1",    hl.dsp.exec_cmd("kitty --class floating -e less -R ~/.config/hypr/hyprland-keys.txt"))

-- +++++++++++++++++++ Window management +++++++++++++++++++

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Resize active window — keep holding to repete (resizeactive: relative=true → delta)
hl.bind(mainMod ..         " + equal", hl.dsp.window.resize({ x =  40, y =   0, relative = true }), { repeating = true })  -- più larga
hl.bind(mainMod ..         " + minus", hl.dsp.window.resize({ x = -40, y =   0, relative = true }), { repeating = true })  -- più stretta
hl.bind(mainMod .. " + SHIFT + equal", hl.dsp.window.resize({ x =   0, y =  40, relative = true }), { repeating = true })  -- più alta
hl.bind(mainMod .. " + SHIFT + minus", hl.dsp.window.resize({ x =   0, y = -40, relative = true }), { repeating = true })  -- più bassa

-- Move focus
hl.bind(mainMod .. " + left",  hl.dsp.exec_cmd("~/.config/hypr/scripts/focus-horizontal.sh l"))
hl.bind(mainMod .. " + right", hl.dsp.exec_cmd("~/.config/hypr/scripts/focus-horizontal.sh r"))
hl.bind(mainMod .. " + up",    hl.dsp.exec_cmd("~/.config/hypr/scripts/focus-vertical.sh u"))
hl.bind(mainMod .. " + down",  hl.dsp.exec_cmd("~/.config/hypr/scripts/focus-vertical.sh d"))

-- Cicle focus between workspace's windows (swapnext)
hl.bind(mainMod ..         " + Tab", hl.dsp.window.cycle_next())
hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.window.cycle_next("prev"))

-- Change near window (tiling, swapwindow l/r/u/d). Via safe_swap: no-op
-- on floating, where swapwindow would crash the compositor (see helper above).
hl.bind(mainMod .. " + CTRL + left",  safe_swap("l"))
hl.bind(mainMod .. " + CTRL + right", safe_swap("r"))
hl.bind(mainMod .. " + CTRL + up",    safe_swap("u"))
hl.bind(mainMod .. " + CTRL + down",  safe_swap("d"))

-- Fullscreen monocle: toggle "maximized" (occupy the workspace respecting bar/gaps).
-- NB: l'API Lua want {mode = "maximized"|"fullscreen"} — pass the integer 1
-- (HyprLang syntax) gets ignored silently and goes on default "fullscreen".
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized" }))

-- Pseudo-tile (dwindle)
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())

-- Toggle split
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))

-- Floating
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))

-- Move floating window (moveactive: relative=true → delta)
hl.bind(mainMod .. " + ALT + left",  hl.dsp.window.move({ x = -20, y =   0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + ALT + right", hl.dsp.window.move({ x =  20, y =   0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + ALT + up",    hl.dsp.window.move({ x =   0, y = -20, relative = true }), { repeating = true })
hl.bind(mainMod .. " + ALT + down",  hl.dsp.window.move({ x =   0, y =  20, relative = true }), { repeating = true })

-- Move window between monitor (with 2 monitor l/r are the same to "the other")
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
hl.bind(mainMod .. " + CTRL + N", hl.dsp.exec_cmd("swaync-client -d"))      -- toggle DND

-- Toggle cursor zoom (in-process: read current config and update)
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
    hl.bind(mainMod .. " + CTRL + "  .. key, hl.dsp.exec_cmd("~/.config/hypr/scripts/ws-switch.sh movesilent " .. i))
end

-- Create new inserted workspace
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("~/.config/hypr/scripts/ws-switch.sh insert"))

-- Scratchpad
hl.bind(mainMod ..         " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind(mainMod .. " + CTRL + S",         hl.dsp.exec_cmd("~/.config/hypr/scripts/scratchpad.sh pull-one"))
hl.bind(mainMod .. " + CTRL + SHIFT + S", hl.dsp.exec_cmd("~/.config/hypr/scripts/scratchpad.sh pull-all"))

-- Hyprscrolling - belt navigation and coloumn resize
hl.bind(mainMod ..         " + comma",  hl.dsp.layout("move -col"))
hl.bind(mainMod ..         " + period", hl.dsp.layout("move +col"))
hl.bind(mainMod .. " + CTRL + comma",   hl.dsp.layout("colresize -conf"))
hl.bind(mainMod .. " + CTRL + period",  hl.dsp.layout("colresize +conf"))

-- Scroll workspace
hl.bind(mainMod .. " + mouse_down", hl.dsp.exec_cmd("~/.config/hypr/scripts/ws-switch.sh next"))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.exec_cmd("~/.config/hypr/scripts/ws-switch.sh prev"))

-- Hyprexpo
hl.bind(mainMod .. " + O", function() hl.plugin.hyprexpo.expo("toggle") end)

-- +++++++++++++++++++ Screenshot / Snip +++++++++++++++++++
local snip = "~/.config/quickshell/scripts/snip.sh "
hl.bind(                      "Print", hl.dsp.exec_cmd(snip .. "screenshot"))
hl.bind(              "SHIFT + Print", hl.dsp.exec_cmd(snip .. "annotate"))
hl.bind(mainMod ..         " + Print", hl.dsp.exec_cmd(snip .. "ocr"))
hl.bind(mainMod .. " + SHIFT + Print", hl.dsp.exec_cmd(snip .. "search"))
hl.bind(mainMod ..   " + ALT + Print", hl.dsp.exec_cmd(snip .. "record"))

-- +++++++++++++++++++ Multimedia +++++++++++++++++++
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })

-- Scorciatoie Discord — F7 mute microfono, F8 silenzia audio.
-- Discord legge le sue scorciatoie dal modulo nativo discord_utils via XInput2 sul
-- server X, non da Wayland. Da Electron 38 (`ELECTRON_OZONE_PLATFORM_HINT` rimosso,
-- Wayland default) Discord gira Wayland-nativo: il compositor non inoltra più i tasti
-- a Xwayland, quindi non li vede mai. `discord-key` li reinietta dentro Xwayland via
-- XTEST, dove Discord li intercetta anche senza avere il focus.
-- non_consuming replica il comportamento originale — XInput2 in raw mode non consumava
-- l'evento — così F7/F8 restano disponibili anche alle altre applicazioni.
-- Da Discord 1.0.164 usa il portale GlobalShortcuts: i nomi sono in `hyprctl globalshortcuts`.
-- Il vecchio metodo XTEST (discord-key) non serve più; resta come fallback commentato.
hl.bind("F7", hl.dsp.global("discord:discord-toggle-mute"),   { non_consuming = true })
hl.bind("F8", hl.dsp.global("discord:discord-toggle-deafen"), { non_consuming = true })
-- hl.bind("F7", hl.dsp.exec_cmd("~/.local/bin/discord-key F7"), { non_consuming = true })
-- hl.bind("F8", hl.dsp.exec_cmd("~/.local/bin/discord-key F8"), { non_consuming = true })

-- Toggle screen_shader (scanline + chromatic) on/off — sincronizza damage_tracking:
-- shader on → damage_tracking 0 (no track, full-frame, richiesto da uniform `time`)
-- shader off → damage_tracking 2 (default, ottimizzato)
hl.bind(mainMod .. " + F11", function()
    local cyberShader = os.getenv("HOME") .. "/.config/hypr/shaders/cyberpunk.frag"
    local cur = hl.get_config("decoration.screen_shader") or ""
    local enabling = (cur == "")
    hl.config({
        decoration = { screen_shader   = (enabling and cyberShader or "") },
        debug      = { damage_tracking = (enabling and 0 or 2) },
    })
end)
-- Toggle glitch + flicker insieme (chromatic/scanlines/vignette restano sempre)
hl.bind(mainMod .. " + CTRL + F11", hl.dsp.exec_cmd("~/.config/hypr/scripts/cyber-toggle.sh"))

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
hl.bind(mainMod .. " + L",                hl.dsp.exec_cmd(
    "canberra-gtk-play -i window-minimize -V 0.4 " ..
    "--property=canberra.xdg-theme.name=cyberpunk-2077 & hyprlock"
))
-- Toggle bar only on screen where the mouse is
hl.bind(mainMod .. " + CTRL + B", hl.dsp.exec_cmd("bash ~/.config/quickshell/scripts/bar-toggle.sh"))
-- Toggle bar on all the screens
hl.bind(mainMod .. " + CTRL + SHIFT + B", hl.dsp.exec_cmd("bash ~/.config/quickshell/scripts/bar-toggle.sh all"))
-- New Quickshell logout overlay (main)
hl.bind(mainMod .. " + SHIFT + E",        hl.dsp.exec_cmd("~/.config/quickshell/scripts/logout-toggle.sh"))
-- Fallback wlogout
hl.bind(mainMod .. " + CTRL + SHIFT + E",        hl.dsp.exec_cmd("wlogout -b 3 -c 20 -r 20 -m 200"))
-- Quick logout (no menu): hl.dsp.exit() ends the compositor, sddm-helper exits
-- with code 0 and SDDM restarts the greeter. Not `uwsm stop`: this session is
-- not uwsm-managed, and there it fails with "Compositor is not running".
-- (`loginctl terminate-user` would force-kill sddm-helper, leaving SDDM blocked
-- on a black TTY.)
hl.bind(mainMod .. " + CTRL + SHIFT + ESCAPE",   hl.dsp.exit())
