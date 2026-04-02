#!/usr/bin/env bash
# init-workspaces.sh — applica layout iniziali per-workspace.
# split-monitor-workspaces gestisce il mapping per-monitor (count=10).
# DP-1 usa workspace 1-10, HDMI-A-1 usa 11-20 internamente.

sleep 1  # attendi che Hyprland e il plugin siano avviati

# DP-1: slot 1,2 → scrolling
hyprctl keyword workspace "1, layout:scrolling"   >/dev/null 2>&1
hyprctl keyword workspace "2, layout:scrolling"   >/dev/null 2>&1

# HDMI-A-1: slot 1 (ws 11) → monocle, slot 3 (ws 13) → master
hyprctl keyword workspace "11, layout:monocle"    >/dev/null 2>&1
hyprctl keyword workspace "13, layout:master"     >/dev/null 2>&1

echo "scrolling" > "/tmp/hypr-layout-DP-1"
echo "monocle"   > "/tmp/hypr-layout-HDMI-A-1"

# Default per workspace non mappati
hyprctl keyword general:layout "dwindle" >/dev/null 2>&1
