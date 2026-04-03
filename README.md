# dotfiles

Cyberpunk 2077-themed Wayland desktop environment on CachyOS (Arch-based).

## Stack

- **Compositor**: Hyprland
- **Shell/Bar**: QuickShell (Qt 6 / QML)
- **Terminal**: Kitty + Fish
- **Theming**: wallust (dynamic palette from wallpaper)
- **Notifications**: SwayNC
- **Launcher**: Wofi

## Install

Requires [GNU Stow](https://www.gnu.org/software/stow/):

```bash
git clone https://github.com/kalashnikxvxiii/dotfiles ~/dotfiles
cd ~/dotfiles
stow hypr kitty fish quickshell wallust swaync wofi
```

## Credits

This rice builds on ideas and code from:

- **[Caelestia](https://github.com/outfoxxed/quickshell-examples)** — Shell architecture inspiration: Colours singleton, BarConfig layout, Players MPRIS service, dashboard tab system with lazy loading, calendar, clock, media and weather widgets
- **[nierlock](https://github.com/xendak/nierlock)** — GlitchEffect overlay and glitch shader
- **[ilyamiro](https://github.com/ilyamiro)** — Wallpaper picker concept and implementation reference
