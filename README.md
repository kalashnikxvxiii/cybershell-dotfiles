# dotfiles

Cyberpunk 2077-themed Wayland desktop environment on CachyOS (Arch-based).

## Stack

- **Compositor**: Hyprland
- **Shell/Bar**: QuickShell (Qt 6 / QML)
- **Terminal**: Kitty + Fish
- **Theming**: wallust (dynamic palette from wallpaper)
- **Qt/GTK**: qt6ct (Fusion + wallust palette), Kvantum KvFlat, adw-gtk3-dark
- **Notifications**: SwayNC
- **Launcher**: Wofi

## Install

Requires [GNU Stow](https://www.gnu.org/software/stow/):

```bash
git clone https://github.com/kalashnikxvxiii/cybershell-dotfiles ~/dotfiles
cd ~/dotfiles
stow hypr quickshell kitty fish wallust swaync wofi \
     gtk qt6ct kvantum systemd \
     btop cava fastfetch spicetify
```

Second line is the Qt/GTK theming the wallust palette feeds, plus the systemd
user units. After stowing `systemd`, run `systemctl --user daemon-reload`.

## GRUB

Boot theme: **[CyberGRUB-2077](https://github.com/adnksharp/CyberGRUB-2077)**, with a custom logo swapped in.

It is not part of this repo: GRUB reads it from `/boot/grub/themes/` at boot time, outside Stow's reach. Install it from upstream and point `GRUB_THEME` at it in `/etc/default/grub`.

## Credits

This rice builds on ideas and code from:

- **[Caelestia](https://github.com/caelestia-dots/shell)** — Shell architecture inspiration: Colours singleton, BarConfig layout, Players MPRIS service, dashboard tab system with lazy loading, calendar, clock, media and weather widgets
- **[nierlock](https://github.com/xendak/nierlock)** — GlitchEffect overlay and glitch shader
- **[ilyamiro](https://github.com/ilyamiro)** — Wallpaper picker concept and implementation reference
