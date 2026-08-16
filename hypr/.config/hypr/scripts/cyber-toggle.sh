#!/usr/bin/env bash
# Toggle glitch+flicker effect gates in cyberpunk.frag (entrambi insieme).
# Usage: cyber-toggle.sh

set -u
SHADER="$HOME/.config/hypr/shaders/cyberpunk.frag"

# Read current state: usiamo GLITCH_ENABLED come riferimento, flicker la segue
if grep -qE "const bool GLITCH_ENABLED\s*=\s*true;" "$SHADER"; then
    sed -i \
        -e "s|const bool GLITCH_ENABLED\s*=\s*true;|const bool GLITCH_ENABLED  = false;|" \
        -e "s|const bool FLICKER_ENABLED\s*=\s*true;|const bool FLICKER_ENABLED = false;|" \
        "$SHADER"
    NEW="OFF"
else
    sed -i \
        -e "s|const bool GLITCH_ENABLED\s*=\s*false;|const bool GLITCH_ENABLED  = true;|" \
        -e "s|const bool FLICKER_ENABLED\s*=\s*false;|const bool FLICKER_ENABLED = true;|" \
        "$SHADER"
    NEW="ON"
fi

hyprctl reload >/dev/null
notify-send -t 1500 "Cyberpunk shader" "Glitch + Flicker → $NEW"
