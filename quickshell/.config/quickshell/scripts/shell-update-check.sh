#!/usr/bin/env bash
# shell-update-check.sh -- prints how many commits this shell's repo is behind its upstream.
# Prints nothing when it can't tell, or when ~/.config/quickshell/.no-shell-updates exists:
# that is for the machine the shell is developed on.
[ -e "$HOME/.config/quickshell/.no-shell-updates" ] && exit 0
root=$(git -C "$(dirname "$(readlink -f "$0")")" rev-parse --show-toplevel 2>/dev/null) || exit 0
git -C "$root" fetch --quiet 2>/dev/null || exit 0
git -C "$root" rev-list --count 'HEAD..@{u}' 2>/dev/null
