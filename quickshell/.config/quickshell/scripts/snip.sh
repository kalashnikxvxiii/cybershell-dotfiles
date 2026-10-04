#!/usr/bin/env bash
# snip.sh <screenshot|annotate|ocr|search|record> [--slurp]
#
# Freeze first, select second. grim runs BEFORE anything draws a selector, so
# the PNG we later crop from already holds the menus, tooltips and hover states
# that a keyboard grab would dismiss -- and no selector overlay, neither the QML
# one nor slurp's, can end up inside the capture.
#
# Default path hands the freeze to the QML overlay, which reports the region back
# through SnipState. With --slurp the region is picked here instead and the shell
# only runs the action: same result, no overlay, useful when debugging.
#
# Both verbs travel through the toggle file, same channel as sonar-toggle.sh;
# the nanosecond suffix keeps consecutive snips distinct.
set -uo pipefail

TRIGGER="/tmp/qs-snip-trigger"
PIDF="/tmp/qs-snip-recorder.pid"

action="${1:-screenshot}"
mode="overlay"
[ "${2:-}" = "--slurp" ] && mode="slurp"

emit() { printf '%s\n' "$*" > "$TRIGGER"; }

# Stopping a recording must not ask for a region again. The action script decides
# to stop by finding a live pid, so it needs no geometry and no freeze.
if [ "$action" = "record" ] && [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then
    emit "direct|record|0|0|1|1||0|0|1|$(date +%s%N)"
    exit 0
fi

dir="${XDG_RUNTIME_DIR:-/tmp}/qs-snip"
LOCK="$dir/session.lock"

# One selector at a time. If one is already up, re-arm its action instead of
# capturing a second freeze and stacking a second picker over the first. The lock
# holds quickshell's pid: a shell that died mid-session leaves a stale lock, and
# trusting it blindly would wedge the keybind until the next reboot.
if [ -f "$LOCK" ]; then
    if kill -0 "$(cat "$LOCK" 2>/dev/null)" 2>/dev/null; then
        emit "rearm|$action|$(date +%s%N)"
        exit 0
    fi
    rm -f "$LOCK"
fi

mon=$(hyprctl monitors -j | jq -c '.[] | select(.focused)')
[ -z "$mon" ] && mon=$(hyprctl monitors -j | jq -c '.[0]')
name=$(jq  -r '.name'  <<<"$mon")
mx=$(jq    -r '.x'     <<<"$mon")
my=$(jq    -r '.y'     <<<"$mon")
scale=$(jq -r '.scale' <<<"$mon")

mkdir -p "$dir" || exit 1
# Unique per capture: a reused path would let Qt serve a cached frame.
src="$dir/frozen-$name-$(date +%s%N).png"

grim -o "$name" "$src" || { notify-send -a Snip 'SNIP FAILED' 'grim capture failed'; exit 1; }

if [ "$mode" = "overlay" ]; then
    emit "overlay|$action|$name|$src|$mx|$my|$scale|$(date +%s%N)"
    exit 0
fi

# --slurp: neutral selector, it only produces x/y/w/h in global logical coords.
geom=$(slurp -b 00060e80 -c 25e1edff -s 00000000 -w 2) || { rm -f "$src"; exit 0; }
read -r gx gy gw gh < <(sed 's/[,x]/ /g' <<<"$geom")
if [ "${gw:-0}" -lt 1 ] || [ "${gh:-0}" -lt 1 ]; then
    rm -f "$src"
    exit 0
fi

emit "direct|$action|$gx|$gy|$gw|$gh|$src|$mx|$my|$scale|$(date +%s%N)"
