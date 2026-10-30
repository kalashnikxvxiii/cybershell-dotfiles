-- Variabili condivise tra tutti i moduli.
-- Prefisso HL_ per evitare collisioni col namespace globale Lua.

_G.HL_MAIN_MOD     = "SUPER"
_G.HL_TERMINAL     = "kitty"
_G.HL_FILE_MANAGER = "dolphin"
_G.HL_MENU         = "hyprlauncher"

-- Per-app border colors (rgb hex; alpha is added per focus state)
_G.HL_BORDER_APPS = {
    ["Spotify"]     = "fcec0c",     -- yellow
    ["harbor"]      = "fcec0c",
    ["kitty"]       = "c5003c",     -- red
    ["discord"]     = "c5003c",
    ["cursor"]      = "8474fb",     -- purple
    ["zen"]         = "25e1ed",     -- cyan
    ["firefox"]     = "25e1ed",
    ["brave-browser"] = "25e1ed",
    ["steam"]       = "25e1ed",
}
