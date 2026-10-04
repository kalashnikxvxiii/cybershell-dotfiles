#!/usr/bin/env bash
# Usage: manga-toggle.sh — flips the manga panel on the focused monitor.
# Mirrors wallpaper-picker.sh cmd_toggle: the screen name travels through the
# toggle file, and the nanosecond suffix makes every write distinct so
# consecutive toggles on the same screen still register as a change.
TOGGLE_FILE="/tmp/qs-manga-toggle"

screen=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
[ -z "$screen" ] && screen="DP-1"
echo "${screen}_$(date +%s%N)" > "$TOGGLE_FILE"
