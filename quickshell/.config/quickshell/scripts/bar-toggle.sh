#!/usr/bin/env bash
# Usage: bar.toggle.sh [focused|all]
mode="${1:-focused}"
case "$mode" in
    focused) touch /tmp/qs-bar-toggle-focused ;;
    all)     touch /tmp/qs-bar-toggle-all ;;
    *)       echo "Usage: 50 [focused|all]" >$2; exit 1
esac