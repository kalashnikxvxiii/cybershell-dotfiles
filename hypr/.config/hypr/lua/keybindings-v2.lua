---@diagnostic disable: undefined-global

-- ── KEYBINDINGS (v2) ──────────────────────────────────────────────────
-- Grammar: the modifier is the verb, the key is the object.
--   SUPER          go to / open / toggle
--   SUPER + SHIFT  bring the active window there
--   SUPER + CTRL   same object, variant (silent, pull, DND, delete...)
--   SUPER + ALT    tune / configure (fine adjustments and menus)
-- Rarely used actions live in one-shot menus (submaps). The previous layout
-- is kept untouched in keybindings.lua: to roll back, require it again in
-- hyprland.lua.
local mainMod     = HL_MAIN_MOD
local terminal    = HL_TERMINAL
local fileManager = HL_FILE_MANAGER

local hypr_scripts = "~/.config/hypr/scripts/"
local qs_scripts   = "~/.config/quickshell/scripts/"
local themer       = hypr_scripts .. "wallpaper-themer.sh "
local snip         = qs_scripts .. "snip.sh "
local ws           = hypr_scripts .. "ws-switch.sh "

-- Every bind carries "SECTION|Name|Note" as its description. Hyprland keeps the
-- text as is, so `hyprctl binds` is the one source for the keymap and the wheel.
-- Binds with the same section, name and modifiers share one row in the keymap.
local current_section = ""

local function section(title)
    current_section = title
end

local function bind(keys, action, name, note, opts)
    local o = opts or {}
    o.description = current_section .. "|" .. name .. "|" .. note
    hl.bind(keys, action, o)
end

local function run(cmd)
    return hl.dsp.exec_cmd(cmd)
end

local function mod(keys)
    return mainMod .. " + " .. keys
end

-- Moves the active window to the other monitor: window.move({ monitor = ... })
-- wants a monitor name, it does not accept "l"/"r".
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

-- swapwindow on a floating window crashes Hyprland (std::bad_variant_access in
-- Layout::CAlgorithm::recalculate), so it only runs on tiled windows.
local function safe_swap(direction)
    return function()
        local w = hl.get_active_window()
        if not w or w.floating then return end
        hl.dispatch(hl.dsp.window.swap({ direction = direction }))
    end
end

-- Quickshell panels listen on /tmp/qs-*-toggle. The screen travels in the
-- payload and the nanosecond suffix keeps consecutive toggles distinct.
local function panel_toggle(file, format)
    return function()
        local m = hl.get_active_monitor()
        local payload = string.format(format, m and m.name or "DP-1")
        hl.exec_cmd('echo "' .. payload .. '$(date +%s%N)" > /tmp/qs-' .. file .. "-toggle")
    end
end

local function toggle_screen_shader()
    local cyberShader = os.getenv("HOME") .. "/.config/hypr/shaders/cyberpunk.frag"
    local cur = hl.get_config("decoration.screen_shader") or ""
    local enabling = (cur == "")
    -- The shader's `time` uniform needs full frames, hence no damage tracking
    hl.config({
        decoration = { screen_shader   = (enabling and cyberShader or "") },
        debug      = { damage_tracking = (enabling and 0 or 2) },
    })
end

-- ── Applications and panels ───────────────────────────────────────────
section("APPS")
bind(mod("Q"),     run(terminal),                       "Terminal",      "Open a kitty window")
bind(mod("grave"), run("kitten quick-access-terminal"), "Quick terminal", "Drop-down kitty, toggles")
bind(mod("E"),     run(fileManager),                    "Files",         "Open the file manager")
bind(mod("B"),     run("zen-browser"),                  "Browser",       "Open Zen")
-- Always through discord-guard: it repairs the asars broken by the Vencord
-- repatch and enforces software video decoding.
bind(mod("D"),     run("~/.local/bin/discord-guard"),   "Discord",       "Start Discord safely")
bind(mod("SPACE"), run("qs ipc call launcher toggle"),  "Launcher",      "Search and start apps")
bind(mod("A"),     panel_toggle("ai", "%s|"),           "AI drawer",     "Chat panel on this screen")
bind(mod("M"),     panel_toggle("manga", "%s_"),        "Manga",         "Library and reader")
bind(mod("R"),     panel_toggle("sonar", "%s|net|"),    "Sonar",         "Network and bluetooth radar")
bind(mod("N"),     run("swaync-client -t"),             "Notifications", "Open the notification center")
bind(mod("CTRL + N"), run("swaync-client -d"),          "Do not disturb", "Silence notifications")
bind(mod("W"),     run(themer .. "smart"),              "Next wallpaper", "Change wallpaper and palette")
bind(mod("slash"), function()
    local m = hl.get_active_monitor()
    hl.exec_cmd("qs ipc call cheatsheet toggle " .. (m and m.name or "DP-1"))
end, "Keymap", "This sheet")

-- ── Windows ───────────────────────────────────────────────────────────
section("WINDOWS")
bind(mod("C"), hl.dsp.window.close(),                            "Close",     "Close the active window")
bind(mod("F"), hl.dsp.window.fullscreen({ mode = "maximized" }), "Maximize",  "Fill the workspace, keep the bar")
bind(mod("V"), hl.dsp.window.float({ action = "toggle" }),       "Float",     "Toggle floating")
bind(mod("P"), hl.dsp.window.pseudo(),                           "Pseudo-tile", "Keep size inside its tile")
bind(mod("J"), hl.dsp.layout("togglesplit"),                     "Split",     "Flip the split direction")
bind(mod("G"), hl.dsp.group.toggle(),                            "Group",     "Create or dissolve a group")
bind(mod("CTRL + Tab"), hl.dsp.group.next(),                     "Group next", "Next window in the group")
bind(mod("Tab"),         hl.dsp.window.cycle_next(),             "Cycle",     "Next window")
bind(mod("SHIFT + Tab"), hl.dsp.window.cycle_next("prev"),       "Cycle back", "Previous window")

bind(mod("mouse:272"), hl.dsp.window.drag(),   "Mouse move",   "Drag the window",   { mouse = true })
bind(mod("mouse:273"), hl.dsp.window.resize(), "Mouse resize", "Drag to resize",    { mouse = true })

-- Arrows: focus / swap / resize / nudge floating
local arrows = {
    { key = "left",  focus = "focus-horizontal.sh l", swap = "l", w = -40, h =   0, x = -20, y =   0 },
    { key = "right", focus = "focus-horizontal.sh r", swap = "r", w =  40, h =   0, x =  20, y =   0 },
    { key = "up",    focus = "focus-vertical.sh u",   swap = "u", w =   0, h = -40, x =   0, y = -20 },
    { key = "down",  focus = "focus-vertical.sh d",   swap = "d", w =   0, h =  40, x =   0, y =  20 },
}
for _, a in ipairs(arrows) do
    bind(mod(a.key),               run(hypr_scripts .. a.focus), "Focus", "Move focus in that direction")
    bind(mod("SHIFT + " .. a.key), safe_swap(a.swap),            "Swap",  "Trade places with the neighbour")
    bind(mod("ALT + " .. a.key),
        hl.dsp.window.resize({ x = a.w, y = a.h, relative = true }),
        "Resize", "Grow or shrink, hold to repeat", { repeating = true })
    bind(mod("ALT + SHIFT + " .. a.key),
        hl.dsp.window.move({ x = a.x, y = a.y, relative = true }),
        "Nudge", "Move a floating window", { repeating = true })
end

-- Two monitors: both directions mean "the other one"
bind(mod("SHIFT + comma"),  move_to_other_monitor, "To monitor", "Send to the other screen")
bind(mod("SHIFT + period"), move_to_other_monitor, "To monitor", "Send to the other screen")

-- ── Workspaces ────────────────────────────────────────────────────────
section("WORKSPACES")
for i = 1, 10 do
    local key = i % 10  -- 10 maps to key 0
    bind(mod(key),               run(ws .. "goto " .. i),       "Go to",     "Switch to workspace 1 to 10")
    bind(mod("SHIFT + " .. key), run(ws .. "move " .. i),       "Send",      "Move the window and follow it")
    bind(mod("CTRL + " .. key),  run(ws .. "movesilent " .. i), "Send quiet", "Move the window, stay here")
end
bind(mod("Insert"),     run(ws .. "insert"), "Insert",  "New workspace after this one")
bind(mod("mouse_down"), run(ws .. "next"),   "Browse",  "Scroll through workspaces")
bind(mod("mouse_up"),   run(ws .. "prev"),   "Browse",  "Scroll through workspaces")
bind(mod("O"), function() hl.plugin.hyprexpo.expo("toggle") end, "Overview", "All workspaces at a glance")

-- Hyprscrolling belt
bind(mod("comma"),         hl.dsp.layout("move -col"),       "Belt",       "Previous or next column")
bind(mod("period"),        hl.dsp.layout("move +col"),       "Belt",       "Previous or next column")
bind(mod("CTRL + comma"),  hl.dsp.layout("colresize -conf"), "Belt width", "Narrower or wider column")
bind(mod("CTRL + period"), hl.dsp.layout("colresize +conf"), "Belt width", "Narrower or wider column")

section("SCRATCHPAD")
bind(mod("S"),                hl.dsp.workspace.toggle_special("magic"),            "Show",     "Toggle the scratchpad")
bind(mod("SHIFT + S"),        hl.dsp.window.move({ workspace = "special:magic" }), "Stash",    "Send the window there")
bind(mod("CTRL + S"),         run(hypr_scripts .. "scratchpad.sh pull-one"),       "Pull one", "Bring one window back")
bind(mod("CTRL + SHIFT + S"), run(hypr_scripts .. "scratchpad.sh pull-all"),       "Pull all", "Bring every window back")

-- ── Utilities ─────────────────────────────────────────────────────────
section("TOOLS")
bind(mod("H"),                run(hypr_scripts .. "clipboard.sh"),        "Clipboard",       "Paste from the history")
bind(mod("CTRL + H"),         run(hypr_scripts .. "clipboard.sh delete"), "Clipboard drop",  "Delete one entry")
bind(mod("CTRL + SHIFT + H"), run(hypr_scripts .. "clipboard.sh wipe"),   "Clipboard wipe",  "Empty the history")
bind(mod("I"),                run("hyprpicker -a"),                       "Color picker",    "Copy a color from the screen")
bind(mod("L"),                run("hyprlock"),                            "Lock",            "Lock the session")

-- Cursor zoom and window opacity share the scroll wheel
bind(mod("ALT + mouse_down"), function()
    local cur = hl.get_config("cursor.zoom_factor") or 1.0
    hl.config({ cursor = { zoom_factor = cur + 0.5 } })
end, "Cursor zoom", "Scroll to zoom around the cursor")
bind(mod("ALT + mouse_up"), function()
    local cur = hl.get_config("cursor.zoom_factor") or 1.0
    local nxt = cur - 0.5
    if nxt < 1.0 then nxt = 1.0 end
    hl.config({ cursor = { zoom_factor = nxt } })
end, "Cursor zoom", "Scroll to zoom around the cursor")
bind(mod("CTRL + mouse_up"),   run(hypr_scripts .. "opacity.sh up"),   "Opacity", "Scroll to fade the window")
bind(mod("CTRL + mouse_down"), run(hypr_scripts .. "opacity.sh down"), "Opacity", "Scroll to fade the window")

section("CAPTURE")
bind("Print",              run(snip .. "screenshot"), "Screenshot", "Select an area, copy it")
bind("SHIFT + Print",      run(snip .. "annotate"),   "Annotate",   "Select, then draw on it")
bind(mod("Print"),         run(snip .. "ocr"),        "OCR",        "Select, copy the text in it")
bind(mod("SHIFT + Print"), run(snip .. "search"),     "Image search", "Select, search it online")
bind(mod("ALT + Print"),   run(snip .. "record"),     "Record",     "Record an area of the screen")

-- ── Media keys ────────────────────────────────────────────────────────
section("MEDIA")
bind("XF86AudioRaiseVolume",  run("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), "Volume",     "Output up or down 5%", { locked = true, repeating = true })
bind("XF86AudioLowerVolume",  run("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      "Volume",     "Output up or down 5%", { locked = true, repeating = true })
bind("XF86AudioMute",         run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     "Mute",       "Mute the output",      { locked = true, repeating = true })
bind("XF86AudioMicMute",      run("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   "Mic mute",   "Mute the microphone",  { locked = true, repeating = true })
bind("XF86MonBrightnessUp",   run("brightnessctl -e4 -n2 set 5%+"), "Brightness", "Screen up or down 5%", { locked = true, repeating = true })
bind("XF86MonBrightnessDown", run("brightnessctl -e4 -n2 set 5%-"), "Brightness", "Screen up or down 5%", { locked = true, repeating = true })
bind("XF86AudioPrev",  run("playerctl previous"),   "Track",      "Previous or next track", { locked = true })
bind("XF86AudioNext",  run("playerctl next"),       "Track",      "Previous or next track", { locked = true })
bind("XF86AudioPlay",  run("playerctl play-pause"), "Play/pause", "Toggle the player",      { locked = true })
bind("XF86AudioPause", run("playerctl play-pause"), "Play/pause", "Toggle the player",      { locked = true })

-- Discord reads these through the GlobalShortcuts portal (names listed by
-- `hyprctl globalshortcuts`). non_consuming leaves F7/F8 to other apps too.
bind("F7", hl.dsp.global("discord:discord-toggle-mute"),   "Discord mic",  "Mute in Discord, works anywhere",   { non_consuming = true })
bind("F8", hl.dsp.global("discord:discord-toggle-deafen"), "Discord deaf", "Deafen in Discord, works anywhere", { non_consuming = true })

-- ── Menus ─────────────────────────────────────────────────────────────
-- One-shot by default: every item leaves the submap once it fires, except the
-- ones marked { stay = true }, which keep the menu open until Escape.
-- Press the entry bind, release the modifiers, then press the plain key.
-- Actions live here and not in Quickshell, so the menus survive a dead shell.
local menu_actions = {}

local function wheel(args)
    hl.exec_cmd("qs ipc call wheel " .. args)
end

-- Entry point for the mouse: QuickWheel.qml calls it through HL.run
_G.HL_MENU_FIRE = function(name, key)
    local actions = menu_actions[name]
    if actions and actions[key] then actions[key]() end
end

local function menu(name, entry, note, fn)
    menu_actions[name] = {}
    local function item(key, action, label, item_note, opts)
        local stay = opts and opts.stay
        local function activate()
            if stay then
                wheel("flash " .. key)
            else
                hl.dispatch(hl.dsp.submap("reset"))
                wheel("pick " .. key)
            end
            if type(action) == "function" then action() else hl.dispatch(action) end
        end
        menu_actions[name][key] = activate
        bind(key, activate, label, item_note)
    end
    -- "@" marks a menu's entry: the keymap shows it in that section's header
    section("@" .. name:upper())
    bind(entry, function()
        local m = hl.get_active_monitor()
        hl.dispatch(hl.dsp.submap(name))
        wheel("open " .. name .. " " .. (m and m.name or "DP-1"))
    end, name, note)
    section(name:upper())
    hl.define_submap(name, function()
        fn(item)
        bind("escape", function()
            hl.dispatch(hl.dsp.submap("reset"))
            wheel("close")
        end, "Leave", "Close the menu")
    end)
end

menu("wallpaper", mod("ALT + W"), "Wheel, then press a key", function(item)
    item("P",     run(qs_scripts .. "wallpaper-picker.sh toggle"), "Picker",  "Browse all wallpapers")
    item("M",     run(themer .. "toggle-mode"),  "Mode",        "Switch the wallpaper mode")
    item("A",     run(themer .. "toggle-auto"),  "Auto",        "Toggle automatic rotation")
    item("O",     run(themer .. "toggle-order"), "Order",       "Toggle the rotation order")
    item("L",     run(themer .. "toggle-pool"),  "Pool",        "Static, Wallpaper Engine or mixed")
    item("S",     run(themer .. "audio-toggle"), "Audio",       "Wallpaper sound on or off")
    item("equal", run(themer .. "audio-up"),     "Audio up",    "Louder, menu stays open",  { stay = true })
    item("minus", run(themer .. "audio-down"),   "Audio down",  "Quieter, menu stays open", { stay = true })
end)

menu("look", mod("ALT + L"), "Wheel, then press a key", function(item)
    item("B", run("bash " .. qs_scripts .. "bar-toggle.sh"),     "Bar here", "Show or hide this screen's bar")
    item("A", run("bash " .. qs_scripts .. "bar-toggle.sh all"), "Bar all",  "Show or hide every bar")
    item("Z", run("qs ipc call contrast-scrim toggle"),          "Dim Zen",  "Darken the wallpaper behind Zen")
    item("S", run("pgrep hyprsunset && pkill hyprsunset || hyprsunset -t 4500"), "Night light", "Warm screen at 4500K")
    item("F", toggle_screen_shader,                              "Shader",   "Scanlines and chromatic aberration")
    item("X", run(hypr_scripts .. "cyber-toggle.sh"),            "Glitch",   "Shader glitch and flicker")
    item("V", run(hypr_scripts .. "opacity.sh toggle"),          "Opacity",  "Window opacity 100 or 60%")
    item("G", run(hypr_scripts .. "gamemode.sh"),                "Game mode", "Toggle the gaming profile")
    item("D", run("nwg-displays"),                               "Displays", "Arrange the monitors")
end)

menu("system", mod("ALT + escape"), "Wheel, then press a key", function(item)
    item("R", hl.dsp.reload_config(), "Reload", "Reload the Hyprland config")
    item("Q", run("pkill quickshell && quickshell >$XDG_RUNTIME_DIR/quickshell.log 2>&1"), "Quickshell", "Restart the shell")
    item("E", run(qs_scripts .. "logout-toggle.sh"), "Logout", "Open the logout overlay")
    item("W", run("wlogout -b 3 -c 20 -r 20 -m 200"), "Wlogout", "Fallback logout screen")
    item("X", hl.dsp.exit(), "Exit", "Leave Hyprland at once")
end)
