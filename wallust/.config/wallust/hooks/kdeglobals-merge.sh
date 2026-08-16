#!/usr/bin/env bash
# Merge sezioni [Colors:*], [ColorEffects:*], [WM] dal color scheme KDE
# generato da wallust dentro ~/.config/kdeglobals.
# Necessario perché Plasma 6 vuole i colori INLINE in kdeglobals,
# non solo il nome dello schema (workflow Plasma-less).

# Notify D-Bus to KDE apps to reload the palette
dbus-send --session --type=signal /KGlobalSettings.notifyChange int32:0 int32:0 2>/dev/null || true

set -e
SCHEME="$HOME/.local/share/color-schemes/Cyberpunk-Wallust.colors"
KDEGLOBALS="$HOME/.config/kdeglobals"

[ -f "$SCHEME" ] || { echo "scheme not found: $SCHEME" >&2; exit 0; }
[ -f "$KDEGLOBALS" ] || { echo "kdeglobals not found" >&2; exit 0; }

python3 - <<PY
import re
from pathlib import Path

scheme = Path("$SCHEME").read_text()
kdg    = Path("$KDEGLOBALS").read_text()

def split_sections(text):
    """Yield (header, body) coppie per ogni sezione INI."""
    cur_head = None; cur_body = []
    for line in text.splitlines(keepends=True):
        if line.lstrip().startswith('['):
            if cur_head is not None:
                yield cur_head, ''.join(cur_body)
            cur_head = line.rstrip('\n')
            cur_body = []
        else:
            (cur_body if cur_head is not None else []).append(line)
    if cur_head is not None:
        yield cur_head, ''.join(cur_body)

WANTED = re.compile(r'^\[(Colors:|ColorEffects:|WM\])')

# 1. Rimuovi sezioni color esistenti da kdeglobals (per evitare duplicati)
keep_lines = []
preamble_lines = []
skip = False
saw_section = False
for line in kdg.splitlines(keepends=True):
    if line.lstrip().startswith('['):
        saw_section = True
        skip = bool(WANTED.match(line.lstrip()))
    if not skip:
        keep_lines.append(line)

kdg_clean = ''.join(keep_lines).rstrip() + '\n'

# 2. Estrai le sezioni color dallo scheme
new_sections = []
for head, body in split_sections(scheme):
    if WANTED.match(head):
        new_sections.append(head + '\n' + body.rstrip() + '\n')

merged = kdg_clean + '\n' + '\n'.join(new_sections)
Path("$KDEGLOBALS").write_text(merged)
PY
