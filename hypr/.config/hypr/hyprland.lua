-- Hyprland Lua config — entry point.
-- Splitted section in the below modules ~/.config/hypr/lua/
-- Backup pre-refactor: hyprland.lua.bak-pre-refactor
-- API reference: /usr/share/hypr/stubs/hl.meta.lua  |  Wiki: https://wiki.hypr.land

---@diagnostic disable: undefined-global
-- `hl` is provided by the Hyprland Lua runtime; LSP users should add
-- /usr/share/hypr/stubs/ to workspace.library for full type checking.

-- ── package.path setup ───────────────────────────────────────────────
-- Add ~/.config/hypr/lua/ to require() lookup path
local CONFIG_HOME = os.getenv("HOME") .. "/.config/hypr"
local LUA_DIR     = CONFIG_HOME .. "/lua/?.lua"
if not package.path:find(LUA_DIR, 1, true) then
    package.path = package.path .. ";" .. LUA_DIR
end

-- ── Caricamento moduli ──────────────────────────────────────────────
-- Order: shared vars first, then env/system, then config, then rules/keybinds, autostart final
require("vars")
require("env")
require("nvidia")
require("smw")
require("displays")
require("look-and-feel")
require("plugins")
require("input")
require("keybindings")
require("rules")
require("autostart")
