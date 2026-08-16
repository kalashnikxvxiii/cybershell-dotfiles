#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  NETRUNNER GREETING — CP2077 boot sequence, one-shot animated, then static║
# ╚═══════════════════════════════════════════════════════════════════════════╝
# Dependencies (all optional; degrades gracefully):
#   REQUIRED : bash, figlet, fastfetch
#   ENHANCED : tte (terminaltexteffects) — animated reveal
#              install: pipx install terminaltexteffects   (or)   paru -S terminaltexteffects
#   OPTIONAL : systemctl (for service status), ip / nmcli (network)
#
# Behaviour: runs once at shell start, ~1.2s total animation, no loops.

set -u
ASCII_DIR="$HOME/Immagini/ASCII"
COLS=$(tput cols 2>/dev/null || echo 80)
ROWS=$(tput lines 2>/dev/null || echo 24)
SMALL=0; (( COLS < 90 )) && SMALL=1

# ── CP2077 24-bit palette ─────────────────────────────────────────────────────
Y=$'\033[38;2;252;236;12m'   # corpo yellow   #fcec0c
C=$'\033[38;2;37;225;237m'   # netrunner cyan #25e1ed
M=$'\033[38;2;234;0;217m'    # magenta        #ea00d9
R=$'\033[38;2;197;0;60m'     # danger red     #c5003c
G=$'\033[38;2;0;255;159m'    # neon ok        #00ff9f
D=$'\033[38;2;80;80;90m'     # dim
B=$'\033[1m'; X=$'\033[0m'

HAS_TTE=0; command -v tte >/dev/null && HAS_TTE=1

# ── Helpers ───────────────────────────────────────────────────────────────────
rule() { printf '%s' "$1"; printf -- '─%.0s' $(seq 1 "$COLS"); printf '%s\n' "$X"; }

reveal() {  # $1 = color, stdin = text
    local color="$1"
    if (( HAS_TTE )); then
        printf '%s' "$color"
        tte --frame-rate 120 decrypt \
            --typing-speed 6 \
            --ciphertext-colors 25e1ed ea00d9 \
            --final-gradient-stops fcec0c fcec0c \
            --final-gradient-steps 4 2>/dev/null
        printf '%s' "$X"
    else
        printf '%s' "$color"; cat; printf '%s' "$X"
    fi
}

status() {  # $1=label  $2=ok|warn|err  $3=detail
    local lbl="$1" st="$2" det="$3" tag pad
    case "$st" in
        ok)   tag="${G}[ OK ]${X}" ;;
        warn) tag="${Y}[WARN]${X}" ;;
        err)  tag="${R}[FAIL]${X}" ;;
        *)    tag="${D}[ -- ]${X}" ;;
    esac
    local left="${C}>${X} ${lbl}"
    local right="${D}${det}${X} ${tag}"
    local lvis=$((${#lbl}+2))
    local rvis=$((${#det}+7))
    pad=$(( COLS - lvis - rvis ))
    (( pad < 2 )) && pad=2
    printf '%s' "$left"
    printf "${D}%.0s.${X}" $(seq 1 "$pad")
    printf '%s\n' "$right"
}

bar() {  # $1 percent  $2 color
    local pct="$1" col="$2" w=20
    local f=$(( pct * w / 100 ))
    local e=$(( w - f ))
    printf '%s' "$col"
    printf '█%.0s' $(seq 1 "$f")
    printf '%s' "$D"
    printf '░%.0s' $(seq 1 "$e")
    printf '%s %3d%%%s' "$col" "$pct" "$X"
}

# ── 1. Header banner (animated decrypt-reveal via tte) ────────────────────────
clear 2>/dev/null
HOSTUP="$(hostname | tr '[:lower:]' '[:upper:]')"
if (( ! SMALL )); then
    figlet -w "$COLS" -f slant "${HOSTUP}" 2>/dev/null | reveal "$Y"
else
    printf "${Y}${B}▌ NODE: %s${X}\n" "$HOSTUP"
fi

# ── 2. Status strip ───────────────────────────────────────────────────────────
rule "$C"
printf "${Y}${B}▌${X} ${Y}NETWATCH PROTOCOL${X} ${M}//${X} "
printf "${C}KERNEL $(uname -r)${X} ${M}//${X} "
printf "${Y}$(date +'%Y-%m-%d %H:%M:%S')${X}\n"
rule "$C"

# ── 3. Boot-sequence status (computed, static) ────────────────────────────────
if ip -4 route get 1.1.1.1 >/dev/null 2>&1; then
    NET_IF=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}')
    NET_IP=$(ip -4 addr show "$NET_IF" 2>/dev/null | awk '/inet /{print $2; exit}')
    status "MILITECH SECURE LINK"     ok   "${NET_IF} ${NET_IP}"
else
    status "MILITECH SECURE LINK"     err  "OFFLINE"
fi
if pgrep -x Hyprland >/dev/null 2>&1; then
    status "HYPRLAND COMPOSITOR"      ok   "WAYLAND"
else
    status "HYPRLAND COMPOSITOR"      warn "NOT RUNNING"
fi
if pgrep -x quickshell >/dev/null 2>&1; then
    status "QUICKSHELL HUD"           ok   "$(pgrep -cx quickshell) PROC"
else
    status "QUICKSHELL HUD"           warn "INACTIVE"
fi
if command -v nvidia-smi >/dev/null 2>&1; then
    GPU=$(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null | head -1)
    status "NEURAL ACCELERATOR"       ok   "${GPU}"
else
    status "NEURAL ACCELERATOR"       warn "NO CUDA NODE"
fi
FAIL=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
if (( FAIL == 0 )); then
    status "SYSTEMD SUBSYSTEM"        ok   "ALL UNITS NOMINAL"
else
    status "SYSTEMD SUBSYSTEM"        err  "${FAIL} UNIT(S) DOWN"
fi

# ── 4. Resource bars (static snapshot) ────────────────────────────────────────
read -r _ tot used _ <<<"$(free -m | awk '/^Mem:/{print $1,$2,$3}')"
MEM_PCT=$(( used * 100 / tot ))
CPU_PCT=$(awk '/cpu /{u=$2+$4; t=u+$5; print int(u*100/t)}' /proc/stat)
DISK_PCT=$(df --output=pcent / | tail -1 | tr -dc '0-9')
printf "\n"
printf "  ${Y}CPU${X}  "; bar "$CPU_PCT"  "$Y"; printf "    "
printf "${M}MEM${X}  "; bar "$MEM_PCT"  "$M"; printf "    "
printf "${C}DSK${X}  "; bar "$DISK_PCT" "$C"; printf "\n\n"

# ── 5. Random ASCII art + fastfetch side-by-side ──────────────────────────────
shopt -s nullglob
txts=( "$ASCII_DIR"/*.txt )
shopt -u nullglob
if (( ${#txts[@]} > 0 )) && (( ! SMALL )); then
    ART="${txts[RANDOM % ${#txts[@]}]}"
    aw=$(awk '{l=length($0); if(l>m)m=l} END{print m+0}' "$ART")
    pad=$(( COLS/2 - aw - 2 )); (( pad < 0 )) && pad=0
    fastfetch --logo-type file --logo "$ART" --logo-padding-right "$pad" 2>/dev/null \
        || fastfetch
else
    fastfetch
fi

# ── 6. Footer ─────────────────────────────────────────────────────────────────
rule "$M"
UP=$(uptime -p | sed 's/^up //')
printf "${C}${B}▌${X} ${C}UPTIME ${UP}${X} ${M}//${X} "
printf "${Y}SHELL ${SHELL##*/}${X} ${M}//${X} "
printf "${G}CYBERDECK ONLINE${X}\n"
rule "$M"
