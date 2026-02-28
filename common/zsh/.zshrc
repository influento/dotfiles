# ~/.zshrc — Zsh configuration with oh-my-zsh
# Managed by dotfiles repo. Do not edit directly — modify the source in dotfiles/common/zsh/

# --- Oh-My-Zsh ---
export ZSH="$HOME/.oh-my-zsh"

# Move compinit cache out of $HOME
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
export ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-${ZSH_VERSION}"

# Starship handles the prompt
ZSH_THEME=""

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)

# shellcheck disable=SC1091
source "$ZSH/oh-my-zsh.sh"

# --- Environment ---

export EDITOR="nvim"
export VISUAL="nvim"
export LANG="en_US.UTF-8"
export PATH="$HOME/.local/bin:$PATH"

# --- Aliases ---

# Modern replacements
alias ls='eza --group-directories-first --icons'
alias ll='eza -la --group-directories-first --icons'
alias lt='eza -T --group-directories-first --icons --level=2'
alias cat='bat --plain'
alias vim='nvim'
alias grep='rg'
alias find='fd'

# Git shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'
alias glg='git log --oneline --graph --decorate'

# Safety nets
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

# --- Tool integrations ---

# fzf
eval "$(fzf --zsh)"

# zoxide (smarter cd)
eval "$(zoxide init zsh)"

# yazi — cd into directory on exit
y() {
  local tmp
  tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
  yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd" || return
  fi
  rm -f -- "$tmp"
}

# --- Starship prompt ---
eval "$(starship init zsh)"

# --- First-login hint ---
if command -v gh &>/dev/null && ! gh auth status &>/dev/null 2>&1; then
  echo "→ Run setup-github to configure SSH + GitHub"
fi

# --- Auto-start Sway on tty1 ---
if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" = "1" ]; then
  exec sway
fi
