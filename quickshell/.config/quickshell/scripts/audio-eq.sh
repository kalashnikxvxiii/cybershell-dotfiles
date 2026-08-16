#!/usr/bin/env bash
# audio-eq.sh — EasyEffects wrapper for the QuickShell Audio Control Center
# Commands:
#   get                  → echo current state JSON
#   set_band <idx> <val> → update band idx (1-10) to val (-12..+12), mark pending=true
#   apply                → write EasyEffects preset + load it, clear pending
#   preset <name>        → load preset values (Flat/Bass/Treble/Vocal/Pop/Rock/Jazz/Classic) + apply

set -u

CACHE_DIR="$HOME/.cache/qs-audio"
STATE_FILE="$CACHE_DIR/eq_state.json"
PRESET_DIR="$HOME/.local/share/easyeffects/output"
PRESET_NAME="qs_live_eq"
PRESET_FILE="$PRESET_DIR/${PRESET_NAME}.json"

EASYEFFECTS=$(command -v easyeffects 2>/dev/null)

mkdir -p "$CACHE_DIR" "$PRESET_DIR" || {
    echo "audio-eq.sh: cannot create state directories" >&2
    exit 1
}

# Serialize concurrent invocations (rapid slider drags spawn parallel scripts via
# Quickshell.execDetached; without this lock, read-modify-write races lose updates).
exec 9>"$CACHE_DIR/.lock"
flock 9

# Default state if missing
if [ ! -f "$STATE_FILE" ]; then
    echo '{"b1":0,"b2":0,"b3":0,"b4":0,"b5":0,"b6":0,"b7":0,"b8":0,"b9":0,"b10":0,"preset":"Flat","pending":false}' > "$STATE_FILE"
fi

# Atomic write: write to tmp then rename
write_state() {
    local content="$1"
    printf '%s' "$content" > "${STATE_FILE}.tmp"
    mv "${STATE_FILE}.tmp" "$STATE_FILE"
}

apply_eq() {
    # If easyeffects is unavailable, skip preset write/load silently;
    # state file already reflects the requested change.
    [ -z "$EASYEFFECTS" ] && return 0
    local vals
    vals=$(cat "$STATE_FILE")
    # slider_to_band_idx: maps the 10 user-facing slider indices to the 32 EasyEffects bands.
    # Sliders are at logarithmic frequency centers: 31, 63, 125, 250, 500, 1k, 2k, 4k, 8k, 16k Hz.
    # We place each slider's gain at every 3rd EE band (0, 3, 6, ..., 27) so adjacent EE bands stay
    # at 0dB and the perceived equalizer shape matches a classic 10-band graphic EQ.
    python3 - "$vals" <<'PY' > "${PRESET_FILE}.tmp"
import sys, json
data = json.loads(sys.argv[1])
# Map 10 slider bands to EasyEffects 32-band layout (one band gets the slider's gain,
# all other bands are bypass=0 since EE 32-band always wants 32 entries)
slider_to_band_idx = {0:0, 1:3, 2:6, 3:9, 4:12, 5:15, 6:18, 7:21, 8:24, 9:27}
# 32 frequency anchors for the EE band layout; only indices in slider_to_band_idx receive
# user gain, the rest stay at 0dB. Tail values (22000, 24000) pad to 32 entries.
freqs = [32,40,50,63,80,100,125,160,200,250,315,400,500,630,800,1000,1250,1600,2000,2500,3150,4000,5000,6300,8000,10000,12500,16000,20000,22000,24000,24000]  # pad to 32
gains = [float(data['b%d' % (i+1)]) for i in range(10)]
bands = {}
for i in range(32):
    freq = freqs[i] if i < len(freqs) else 20000.0
    gain = 0.0
    for s_idx, b_idx in slider_to_band_idx.items():
        if i == b_idx:
            gain = gains[s_idx]
            break
    bands[f"band{i}"] = {
        "frequency": freq, "gain": gain, "mode": "Bell",
        "mute": False, "q": 1.0, "solo": False, "width": 1.0, "slope": "x1"
    }
preset = {
    "output": {
        "blocklist": [],
        "plugins_order": ["equalizer"],
        "equalizer": {
            "bypass": False, "input-gain": 0.0, "output-gain": 0.0,
            "left": bands, "right": bands, "mode": "IIR",
            "num-bands": 32, "split-channels": False
        }
    }
}
print(json.dumps(preset, indent=4))
PY
    mv "${PRESET_FILE}.tmp" "$PRESET_FILE"
    "$EASYEFFECTS" -l "$PRESET_NAME" >/dev/null 2>&1 &
}

save_preset() {
    # args: b1..b10 preset_name
    local out
    out=$(python3 -c "
import json, sys
vals = sys.argv[1:11]
name = sys.argv[11]
print(json.dumps({'b%d'%(i+1): int(vals[i]) for i in range(10)} | {'preset': name, 'pending': False}))
" "$@") || exit 1
    [ -n "$out" ] || exit 1
    write_state "$out"
}

cmd="${1:-}"

case "$cmd" in
    "get")
        cat "$STATE_FILE"
        ;;
    "set_band")
        idx="${2:-}"
        val="${3:-}"
        [[ "$idx" =~ ^([1-9]|10)$ ]] || { echo "set_band: idx must be 1..10" >&2; exit 1; }
        [[ "$val" =~ ^-?([0-9]|1[0-2])$ ]] || { echo "set_band: val must be -12..12" >&2; exit 1; }
        cur=$(cat "$STATE_FILE")
        out=$(python3 -c "
import json, sys
data = json.loads(sys.argv[1])
data['b%s' % sys.argv[2]] = int(sys.argv[3])
data['preset'] = 'Custom'
data['pending'] = True
print(json.dumps(data))
" "$cur" "$idx" "$val") || exit 1
        [ -n "$out" ] || exit 1
        write_state "$out"
        ;;
    "apply")
        cur=$(cat "$STATE_FILE")
        out=$(python3 -c "
import json, sys
data = json.loads(sys.argv[1])
data['pending'] = False
print(json.dumps(data))
" "$cur") || exit 1
        [ -n "$out" ] || exit 1
        write_state "$out"
        apply_eq
        ;;
    "preset")
        name="${2:-}"
        # Preset values are b1..b10 gains in dB (-12..+12). The slider order corresponds to
        # frequencies 31Hz, 63Hz, 125Hz, 250Hz, 500Hz, 1kHz, 2kHz, 4kHz, 8kHz, 16kHz.
        #               b1  b2  b3  b4  b5  b6  b7  b8  b9  b10
        case "$name" in
            "Flat")    save_preset 0 0 0 0 0 0 0 0 0 0 "Flat" ;;
            "Bass")    save_preset 5 7 5 2 1 0 0 0 1 2 "Bass" ;;
            "Treble")  save_preset -2 -1 0 1 2 3 4 5 6 6 "Treble" ;;
            "Vocal")   save_preset -2 -1 1 3 5 5 4 2 1 0 "Vocal" ;;
            "Pop")     save_preset 2 4 2 0 1 2 4 2 1 2 "Pop" ;;
            "Rock")    save_preset 5 4 2 -1 -2 -1 2 4 5 6 "Rock" ;;
            "Jazz")    save_preset 3 3 1 1 1 1 2 1 2 3 "Jazz" ;;
            "Classic") save_preset 0 1 2 2 2 2 1 2 3 4 "Classic" ;;
            *)         echo "preset: unknown name '$name' (valid: Flat|Bass|Treble|Vocal|Pop|Rock|Jazz|Classic)" >&2; exit 1 ;;
        esac
        apply_eq
        ;;
    *)
        echo "usage: $0 {get|set_band <idx> <val>|apply|preset <name>}" >&2
        exit 1
        ;;
esac
