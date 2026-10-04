#!/usr/bin/env bash
# Usage: sonar-toggle.sh [net|bt] — flips the Sonar panel on the focused monitor.
# Same channel as manga-toggle.sh: screen name and view travel through the
# toggle file, and the nanosecond suffix keeps consecutive toggles distinct.
TOGGLE_FILE="/tmp/qs-sonar-toggle"

view="${1:-net}"
[ "$view" != "net" ] && [ "$view" != "bt" ] && view="net"

screen=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
[ -z "$screen" ] && screen="DP-1"
echo "${screen}|${view}|$(date +%s%N)" > "$TOGGLE_FILE"
