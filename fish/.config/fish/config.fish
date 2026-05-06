source /usr/share/cachyos-fish-config/cachyos-config.fish

# ========== ALIASES ==========
# Disable Kill Switch
alias sos="sudo ufw default allow outgoing && echo 'Kill switch disabilitato - traffico in chiaro!'"
# Enable Kill Switch
alias lockdown="sudo ufw default deny outgoing && echo 'Kill switch attivato'"

# Add wallust theme
test -f ~/.cache/wallust/sequences && cat ~/.cache/wallust/sequences

# Git editor (override GIT_EDITOR=true injected by VS Code extensions)
set -e GIT_EDITOR

# Add to Path
fish_add_path /home/kalashnikxv/.spicetify

# XDG-compliant paths
fish_add_path $HOME/.local/share/cargo/bin
fish_add_path $HOME/.local/share/go/bin
fish_add_path $HOME/.local/share/npm/bin

# XDG-compliant aliases
alias wget="wget --hsts-file=$HOME/.local/share/wget/wget-hsts"
alias nvidia-settings="nvidia-settings --config=$HOME/.config/nvidia/settings"

# !!!Greetings!!!

function fish_greeting
    bash ~/.config/fish/greeting.sh
end
