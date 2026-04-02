#!/usr/bin/env bash
# Terminal greeting — Kitty: GIF animata (kitten icat) + fastfetch info fianco a fianco
#                    WezTerm/altro: ASCII + fastfetch + glitch animation

GIF_DIR="$HOME/Immagini/Gifs"
ASCII_DIR="$HOME/Immagini/ASCII"

COLS=$(tput cols 2>/dev/null || echo 80)
HALF=$(( COLS / 2 ))

# ── Rilevamento terminale ─────────────────────────────────────────────────────
if [[ -n "$KITTY_PID" || "$TERM" == "xterm-kitty" ]]; then
    TERM_TYPE="kitty"
elif [[ -n "$WEZTERM_PANE" || "$TERM_PROGRAM" == "WezTerm" ]]; then
    TERM_TYPE="wezterm"
else
    TERM_TYPE="other"
fi

# ── KITTY: kitten icat (animazione reale) + fastfetch info a destra ───────────
if [[ "$TERM_TYPE" == "kitty" ]]; then
    gifs=( "$GIF_DIR"/*.gif )
    if [[ ! -f "${gifs[0]}" ]]; then
        fastfetch; exit 0
    fi
    # Ordinamento alfabetico e selezione sequenziale (indice persistente)
    mapfile -t gifs_sorted < <(printf '%s\n' "${gifs[@]}" | sort)
    state_file="$HOME/.local/state/greeting_gif_index"
    mkdir -p "$(dirname "$state_file")"
    idx=$(cat "$state_file" 2>/dev/null)
    idx=$(( ${idx:-0} % ${#gifs_sorted[@]} ))
    gif="${gifs_sorted[$idx]}"
    echo $(( (idx + 1) % ${#gifs_sorted[@]} )) > "$state_file"

    # Rileva se il terminale occupa il 100% della larghezza del monitor (Hyprland)
    FULL_WIDTH=0
    if command -v hyprctl &>/dev/null; then
        _layout=$(python3 - <<'PY' 2>/dev/null
import json, subprocess
win  = json.loads(subprocess.check_output(["hyprctl","activewindow","-j"]))
mons = json.loads(subprocess.check_output(["hyprctl","monitors","-j"]))
mon_id = win.get("monitor", 0)
mon = next((m for m in mons if m["id"] == mon_id), mons[0])
print("full" if win["size"][0] >= mon["width"] else "partial")
PY
)
        [[ "$_layout" == "full" ]] && FULL_WIDTH=1
    fi

    # Dimensioni in pixel della GIF (solo primo frame)
    read -r gif_px_w gif_px_h < <(identify -format "%w %h\n" "${gif}[0]" 2>/dev/null | head -1)
    gif_px_w=${gif_px_w:-1}
    gif_px_h=${gif_px_h:-1}

    # Dimensioni cella in pixel via CSI 16t → per calcolare centramento verticale
    printf '\033[16t' > /dev/tty
    IFS=';' read -r -d 't' _ cell_h cell_w < /dev/tty
    cell_h="${cell_h//[^0-9]/}"; cell_h="${cell_h:-20}"
    cell_w="${cell_w//[^0-9]/}"; cell_w="${cell_w:-10}"

    if (( gif_px_w > gif_px_h && FULL_WIDTH == 0 )); then
        # ── LANDSCAPE + finestra parziale: GIF a larghezza piena, fastfetch sotto
        # --align center centra se la GIF è più stretta del terminale
        kitten icat --fit width --align center "$gif"
        fastfetch --logo-type none
    else
        # ── PORTRAIT / QUADRATA o FULL-WIDTH: layout adattivo (50/50 o stacked)
        mapfile -t FF_LINES < <(fastfetch --logo-type none 2>/dev/null)
        FF_H=${#FF_LINES[@]}
        [[ $FF_H -eq 0 ]] && { fastfetch; exit 0; }

        ROWS=$(tput lines 2>/dev/null || echo 24)
        right_w=$(( COLS - HALF - 2 ))
        # Larghezza massima output fastfetch (senza codici ANSI)
        ff_max_w=$(printf '%s\n' "${FF_LINES[@]}" | sed 's/\x1b\[[0-9;]*[A-Za-z]//g' | awk '{print length}' | sort -n | tail -1)
        ff_max_w=${ff_max_w:-0}

        if (( HALF >= 30 && right_w >= ff_max_w && FF_H <= ROWS - 2 )); then
            # ── 50/50: GIF a sinistra, fastfetch a destra
            for ((i=0; i<FF_H; i++)); do printf '\n'; done
            printf "\033[%dA" "$FF_H"

            printf '\033[6n' > /dev/tty
            IFS=';' read -r -d 'R' CROW CCOL < /dev/tty
            CROW="${CROW//[^0-9]/}"; CROW="${CROW:-1}"

            # Calcola altezza effettiva della GIF in celle e offset verticale
            read -r gif_actual_h gif_v_offset < <(python3 -c "
gh, gw   = $gif_px_h, $gif_px_w
cols     = $HALF
rows     = $FF_H
ch, cw   = $cell_h, $cell_w
dh = cols * (gh / gw) * (cw / ch)
actual = max(1, min(round(dh), rows))
offset = (rows - actual) // 2
print(actual, offset)
")
            gif_actual_h=${gif_actual_h:-$FF_H}
            gif_v_offset=${gif_v_offset:-0}

            kitten icat \
                --place "${HALF}x${gif_actual_h}@0x$((CROW - 1 + gif_v_offset))" \
                --align center --scale-up "$gif" 2>/dev/null

            for i in "${!FF_LINES[@]}"; do
                printf "\033[%d;%dH%s" "$((CROW + i))" "$((HALF + 2))" "${FF_LINES[$i]}"
            done

            printf "\033[%d;1H" "$((CROW + FF_H))"
        else
            # ── STACKED: finestra troppo stretta/bassa → GIF a tutta larghezza, info sotto
            kitten icat --fit width --align center "$gif" 2>/dev/null
            printf '%s\n' "${FF_LINES[@]}"
        fi
    fi
    exit 0
fi

# ── WEZTERM / ALTRO: ASCII + fastfetch + glitch ───────────────────────────────
txts=( "$ASCII_DIR"/*.txt )
[[ ! -f "${txts[0]}" ]] && { fastfetch; exit 0; }

ART_FILE="${txts[$((RANDOM % ${#txts[@]}))]}"

art_w=$(python3 -c "print(max(len(l.rstrip('\n')) for l in open('$ART_FILE')))" 2>/dev/null)
art_w=${art_w:-40}
ART_TOTAL=$(( 2 + art_w ))

if (( ART_TOTAL >= HALF )); then
    FF_ARGS=(--logo-type file --logo "$ART_FILE" --logo-position top)
else
    FF_ARGS=(--logo-type file --logo "$ART_FILE" --logo-padding-right $(( HALF - ART_TOTAL )))
fi

mapfile -t LINES < <(fastfetch "${FF_ARGS[@]}" 2>/dev/null)
HEIGHT=${#LINES[@]}
[[ $HEIGHT -eq 0 ]] && { fastfetch; exit 0; }

GLITCH_CHARS='!@#$%^*/<>|~?'
GC=($'\033[31m' $'\033[33m' $'\033[37;1m' $'\033[35m' $'\033[36;1m')
RESET=$'\033[0m'

old_stty=$(stty -g 2>/dev/null)
tput civis 2>/dev/null
trap 'tput cnorm 2>/dev/null; [[ -n "$old_stty" ]] && stty "$old_stty" 2>/dev/null' EXIT INT TERM

for line in "${LINES[@]}"; do printf "%s\n" "$line"; done

for ((frame = 1; frame <= 16; frame++)); do
    printf "\033[%dA" "$HEIGHT"

    n_glitch=0
    [[ $((frame % 4)) -eq 0 && frame -lt 16 ]] && n_glitch=1
    [[ $((frame % 7)) -eq 0 && frame -lt 16 ]] && n_glitch=2

    g1=-1; g2=-1
    [[ $n_glitch -ge 1 ]] && g1=$((RANDOM % HEIGHT))
    [[ $n_glitch -ge 2 ]] && g2=$((RANDOM % HEIGHT))

    for ((i = 0; i < HEIGHT; i++)); do
        if [[ $i -eq $g1 || $i -eq $g2 ]]; then
            gc="${GC[$((RANDOM % ${#GC[@]}))]}"
            plain=$(printf "%s" "${LINES[$i]}" | sed 's/\x1b\[[0-9;]*[mGKHFJA]//g')
            out="$gc"
            for ((c = 0; c < ${#plain}; c++)); do
                ch="${plain:$c:1}"
                if [[ "$ch" != " " && $((RANDOM % 3)) -eq 0 ]]; then
                    out+="${GLITCH_CHARS:$((RANDOM % ${#GLITCH_CHARS})):1}"
                else
                    out+="$ch"
                fi
            done
            printf "%s${RESET}\n" "$out"
        else
            printf "%s\n" "${LINES[$i]}"
        fi
    done

    sleep 0.07
done

tput cnorm 2>/dev/null
[[ -n "$old_stty" ]] && stty "$old_stty" 2>/dev/null
trap - EXIT INT TERM
while IFS= read -r -s -t 0 -n 1 _ 2>/dev/null; do :; done
