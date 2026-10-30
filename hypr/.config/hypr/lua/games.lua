---@diagnostic disable: undefined-global

-- ── Auto-detect finestre di gioco → niente trasparenza/blur/dim ───────
-- Ad ogni window.open ispeziona /proc/<pid> (in-process, niente daemon) e,
-- se la finestra sembra un gioco, la tagga "game" e forza l'opacità piena.
--
-- Segnali (basta uno):
--   1. content_type == "game"            (protocollo wp_content_type_v1)
--   2. class steam_app_N / gamescope
--   3. environ: SteamGameId, STEAM_COMPAT_APP_ID, LUTRIS_GAME_UUID,
--      HEROIC_APP_NAME, GAMEID (umu)     → Steam/Proton/Lutris/Heroic
--   4. Godot: processo godot senza --editor (= "Esegui progetto"),
--      oppure export *.x86_64
--   5. librerie mappate: SDL2/3, GLFW, raylib, Unity, LWJGL, SFML, LÖVE…
--      (ignorate se c'è anche Qt/GTK: EasyEffects e Quickshell caricano SDL3)
--   6. Wine con DXVK/VKD3D/wined3d caricati (ricontrollato dopo qualche
--      secondo: Wine crea la finestra prima del device D3D)
--   7. ~/.config/hypr/games.list        (class:/title: con pattern Lua)
--
-- Debug: `hyprctl clients -j | jq '.[]|{class,tags}'` → tag "game".
-- SUPER+ALT+G marca/smarca a mano la finestra attiva (persistito in games.list).

local M = {}

local GAMES_LIST = os.getenv("HOME") .. "/.config/hypr/games.list"

-- Mai trattati come giochi (launcher/client che caricano SDL o girano in Wine)
local DENY_CLASS = {
    ["steam"] = true, ["steamwebhelper"] = true,
    ["heroic"] = true, ["com.heroicgameslauncher.hgl"] = true,
    ["lutris"] = true, ["net.lutris.Lutris"] = true,
    ["vortex.exe"] = true, ["Vortex"] = true,
    ["org.godotengine.Editor"] = true,
}

local GAME_ENV = { "SteamGameId", "STEAM_COMPAT_APP_ID", "LUTRIS_GAME_UUID", "HEROIC_APP_NAME", "GAMEID" }

local GAME_LIBS = {
    "/libSDL2%-2%.0%.so", "/libSDL3%.so", "/libglfw%.so", "/libraylib%.so",
    "/UnityPlayer%.so", "/liblwjgl%.so", "/libsfml%-window", "/liblove",
    "/libUnrealEngine", "%-Linux%-Shipping",
}

-- App desktop che caricano SDL per gamepad/audio (EasyEffects, Quickshell…)
local DESKTOP_TOOLKITS = { "/libQt[56]Widgets%.so", "/libQt[56]Quick%.so", "/libgtk%-[34]%.so" }

local WINE_D3D = { "/d3d9%.dll", "/d3d11%.dll", "/d3d12%.dll", "/dxgi%.dll", "/wined3d%.dll" }

local function read(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("a")
    f:close()
    return s
end

local function any_match(s, patterns)
    for _, p in ipairs(patterns) do
        if s:find(p) then return p end
    end
end

local function load_list()
    local rules = {}
    local s = read(GAMES_LIST)
    if not s then return rules end
    for line in s:gmatch("[^\n]+") do
        local kind, pat = line:match("^%s*(%a+):(.+)$")
        if kind and not line:match("^%s*#") then
            rules[#rules + 1] = { kind = kind, pat = pat }
        end
    end
    return rules
end

local function in_list(w)
    for _, r in ipairs(load_list()) do
        local v = (r.kind == "class" and w.class) or (r.kind == "title" and (w.initial_title or w.title)) or nil
        if v and v:find(r.pat) then return "games.list " .. r.kind end
    end
end

local function is_wine(cmdline)
    local argv0 = (cmdline:match("^[^\0]*") or ""):lower()
    return argv0:find("wine") or argv0:find("%.exe$")
end

-- Ritorna il motivo (stringa) se è un gioco, nil altrimenti
function M.detect(w)
    if not w or DENY_CLASS[w.class or ""] then return nil end
    if w.content_type == "game" then return "content_type" end
    local class = w.class or ""
    if class:find("^steam_app_%d+$") or class == "gamescope" then return "class" end

    local reason = in_list(w)
    if reason then return reason end

    local pid = w.pid
    if not pid or pid <= 0 then return nil end
    local proc = "/proc/" .. pid

    local env = read(proc .. "/environ")
    if env then
        env = "\0" .. env
        for _, k in ipairs(GAME_ENV) do
            local v = env:match("\0" .. k .. "=([^\0]*)")
            if v and v ~= "" and v ~= "0" then return "env " .. k end
        end
    end

    local cmdline = read(proc .. "/cmdline") or ""
    local argv0 = cmdline:match("^[^\0]*") or ""
    local exe = argv0:match("[^/]*$") or ""
    if exe:find("^godot") then
        local editor = ("\0" .. cmdline .. "\0"):find("\0%-%-editor\0") or ("\0" .. cmdline .. "\0"):find("\0%-e\0")
        if not editor and not ("\0" .. cmdline .. "\0"):find("\0%-%-project%-manager\0") then return "godot run" end
        return nil
    end
    if exe:find("%.x86_64$") then return "godot export" end

    local maps = read(proc .. "/maps")
    if maps then
        local lib = any_match(maps, GAME_LIBS)
        if lib and not any_match(maps, DESKTOP_TOOLKITS) then return "lib " .. lib:gsub("%%", "") end
        if is_wine(cmdline) and any_match(maps, WINE_D3D) then return "wine d3d" end
    end
    return nil
end

local function set(addr, prop, value)
    hl.dispatch(hl.dsp.window.set_prop({ prop = prop, value = value, window = "address:" .. addr }))
end

local PROPS = {
    opacity = "1.0", opacity_inactive = "1.0", opacity_fullscreen = "1.0",
    opacity_override = "1", opacity_inactive_override = "1", opacity_fullscreen_override = "1",
    no_blur = "1", opaque = "1", no_dim = "1",
}

-- Il tag attiva la regola "games-opaque" (no_blur/opaque/no_dim, ri-valutata
-- dinamicamente); l'override opacità invece non viene ri-applicato dalle
-- regole dinamiche, quindi lo forziamo con set_prop.
function M.apply(w, reason)
    local addr = w.address
    if not addr then return end
    hl.dispatch(hl.dsp.window.tag({ tag = "+game", window = "address:" .. addr }))
    for k, v in pairs(PROPS) do set(addr, k, v) end
    M.marked[addr] = reason or true
end

function M.unapply(addr)
    hl.dispatch(hl.dsp.window.tag({ tag = "-game", window = "address:" .. addr }))
    -- Le prop float non accettano "unset": 1.0 è neutro senza override
    for k, v in pairs(PROPS) do set(addr, k, v == "1.0" and "1.0" or "unset") end
    M.marked[addr] = nil
end

local function check(w)
    if not w or not w.address or M.marked[w.address] then return true end
    local ok, reason = pcall(M.detect, w)
    if ok and reason then
        M.apply(w, reason)
        return true
    end
    return false
end

local function recheck_later(addr, ms)
    hl.timer(function()
        if M.marked[addr] then return end
        local w = hl.get_window("address:" .. addr)
        if w then check(w) end
    end, { timeout = ms, type = "oneshot" })
end

-- SUPER+ALT+G: marca/smarca la finestra attiva e lo ricorda in games.list
function M.toggle_active()
    local w = hl.get_active_window()
    if not w or not w.class or w.class == "" then return end
    local entry = "class:^" .. w.class:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0") .. "$"
    local lines, found = {}, false
    for line in (read(GAMES_LIST) or ""):gmatch("(.-)\n") do
        if line == entry then found = true else lines[#lines + 1] = line end
    end
    if not found then lines[#lines + 1] = entry end
    local f = io.open(GAMES_LIST, "w")
    if f then f:write(table.concat(lines, "\n") .. "\n"); f:close() end

    for _, win in ipairs(hl.get_windows()) do
        if win.class == w.class then
            if found then M.unapply(win.address) else M.apply(win, "manual") end
        end
    end
    hl.exec_cmd(string.format('hyprctl notify 1 2000 "rgb(%s)" "  %s: %s"',
        found and "ff003c" or "fcee0a", found and "non è un gioco" or "gioco", w.class))
end

-- ── Setup (idempotente: un reload ri-esegue il file) ─────────────────
if _G.__games and _G.__games.subs then
    for _, s in ipairs(_G.__games.subs) do pcall(function() s:remove() end) end
end
M.marked = (_G.__games and _G.__games.marked) or {}
_G.__games = M

hl.window_rule({
    name    = "games-opaque",
    match   = { tag = "game" },
    opacity = "override 1.0 override 1.0 override 1.0",
    no_blur = true,
    opaque  = true,
    no_dim  = true,
    no_wobble = true,
    no_glow = true,
})

-- Giochi che dichiarano content-type "game" anche dopo l'apertura
hl.window_rule({
    name    = "games-content-type",
    match   = { content = "game" },
    opacity = "override 1.0 override 1.0 override 1.0",
    no_blur = true,
    opaque  = true,
    no_dim  = true,
})

-- Un errore qui dentro non deve mai propagarsi al compositor
local function safe(fn)
    return function(w) pcall(fn, w) end
end

M.subs = {
    hl.on("window.open", safe(function(w)
        if check(w) then return end
        local addr = w.address
        -- Wine/Proton caricano D3D dopo aver creato la finestra
        recheck_later(addr, 2000)
        recheck_later(addr, 8000)
    end)),
    -- Alcuni client Wayland impostano app_id dopo il map. window.class scatta
    -- anche PRIMA di window.open: lì il map ri-applica le regole e cancella
    -- le prop, quindi agiamo solo su finestre già mappate.
    hl.on("window.class", safe(function(w) if w.mapped then check(w) end end)),
    -- Un gioco va spesso fullscreen a caricamento finito: ultimo controllo
    hl.on("window.fullscreen", safe(check)),
    hl.on("window.destroy", safe(function(w) M.marked[w.address] = nil end)),
}

-- Finestre già aperte (reload / caricamento a sessione avviata)
for _, w in ipairs(hl.get_windows()) do pcall(check, w) end

hl.bind("SUPER + ALT + G", function() M.toggle_active() end)

return M
