#!/usr/bin/env bash
# Rimuove # dagli hex (Spicetify vuole "aabbcc" senza "#").
# spicetify watch -l si occupa del reload in-place via CDP — niente apply qui.

set -u
COLOR_INI="$HOME/.config/spicetify/Themes/marketplace/color.ini"
[ -f "$COLOR_INI" ] || exit 0

sed -i 's/= #\([0-9a-fA-F]\{6,8\}\)/= \1/g' "$COLOR_INI"
