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

- **[Caelestia](https://github.com/caelestia-dots/shell)** (GPL-3.0) — `DashClock`, `DashCalendar`, `DashTabs`, `DashMediaTab`, `DashWeatherMini`, `DashWeatherTab`, `DashboardContent` and the `Colours` singleton are adapted from its code; the `BarConfig` layout and the `Players` MPRIS service follow its patterns
- **[nierlock](https://github.com/xendak/nierlock)** — `GlitchEffect` is inspired by it; `shaders/glitch.frag.qsb` and `shaders/success.frag.qsb` come from it unchanged
- **[ilyamiro](https://github.com/ilyamiro)** — Wallpaper picker concept and implementation reference
- **[cava](https://github.com/karlstav/cava)** (MIT) — the shaders in `cava/.config/cava/shaders/` are cava's own examples

## License

Everything written for this repository is licensed under the [GNU General Public License v3.0 or later](LICENSE).

Not covered, and still belonging to their authors:

- the nierlock shaders listed above, published upstream without a license
- the cava shaders, Copyright (c) 2015 Karl Stavestrand, under cava's MIT license
- the Cyberpunk 2077 and Cyberpunk: Edgerunners GIFs in `quickshell/.config/quickshell/assets/`, which belong to their respective rights holders
- the icons in `quickshell/.config/quickshell/assets/SVG/`, from [SVG Repo](https://www.svgrepo.com) under their individual licenses
