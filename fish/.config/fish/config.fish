source /usr/share/cachyos-fish-config/cachyos-config.fish

# ========== ALIASES ==========
# Disabilita Kill Switch
alias sos="sudo ufw default allow outgoing && echo 'Kill switch disabilitato - traffico in chiaro!'"
# Attiva Kill Switch
alias lockdown="sudo ufw default deny outgoing && echo 'Kill switch attivato'"

# Add wallust theme
test -f ~/.cache/wallust/sequences && cat ~/.cache/wallust/sequences

# SSH agent managed by systemd (ssh-agent.socket)
# SSH_AUTH_SOCK set via ~/.config/environment.d/ssh-agent.conf
# Key added automatically on first use via ~/.ssh/config AddKeysToAgent

# Git editor (override GIT_EDITOR=true injected by VS Code extensions)
set -e GIT_EDITOR

# Add to Path
fish_add_path /home/kalashnikxv/.spicetify

# !!!Greetings!!!

function fish_greeting
    bash ~/.config/fish/greeting.sh
end
