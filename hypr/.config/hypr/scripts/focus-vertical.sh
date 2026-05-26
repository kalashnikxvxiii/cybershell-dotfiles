#!/usr/bin/env bash
# Focus verticale — gestisce dwindle, monocle, scrolling
direction="$1"  # "u" o "d"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/safe-focus-lib.sh"

layout=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.tiledLayout // "dwindle"')

if [ "$layout" = "monocle" ]; then
    if [ "$direction" = "u" ]; then
        hd 'hl.dsp.layout("cyclenext")'
    else
        hd 'hl.dsp.layout("cycleprev")'
    fi
else
    # dwindle / scrolling — naviga per coordinate, niente cross-monitor
    # (i monitor sono affiancati orizzontalmente)
    safe_movefocus "$direction"
fi
