# ~/.zshrc — Zsh configuration with oh-my-zsh
# Managed by dotfiles repo. Do not edit directly — modify the source in dotfiles/common/zsh/

# --- Oh-My-Zsh ---
export ZSH="$HOME/.oh-my-zsh"

# Move compinit cache out of $HOME
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
export ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-${ZSH_VERSION}"

# Starship handles the prompt
ZSH_THEME=""

# Auto-update silently (never prompt — it blocks tty login before sway starts)
zstyle ':omz:update' mode auto
zstyle ':omz:update' frequency 7

# Plugin config (before sourcing omz)
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

plugins=(
  git
  sudo                      # ESC ESC to prepend sudo to last/current command
  extract                   # `extract archive.tar.gz` — handles any archive format
  zsh-autosuggestions
  zsh-syntax-highlighting   # must be last
)

# shellcheck disable=SC1091
source "$ZSH/oh-my-zsh.sh"

# --- History ---
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS   # remove older duplicate entries
setopt HIST_FIND_NO_DUPS      # don't show dupes when searching
setopt HIST_REDUCE_BLANKS     # remove unnecessary whitespace
setopt HIST_IGNORE_SPACE      # prefix with space to skip history
setopt SHARE_HISTORY          # share history across sessions
setopt INC_APPEND_HISTORY     # write immediately, not on exit

# --- Zsh options ---
setopt AUTO_CD                # type a dir name to cd into it
setopt CORRECT                # suggest corrections for mistyped commands
setopt EXTENDED_GLOB          # advanced globbing (#, ~, ^)
setopt NO_BEEP                # silence
setopt INTERACTIVE_COMMENTS   # allow # comments in interactive shell
setopt AUTO_PUSHD             # cd pushes onto dir stack
setopt PUSHD_IGNORE_DUPS      # no duplicate dirs on stack
setopt PUSHD_SILENT           # don't print dir stack on pushd/popd

# --- Completion ---
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'           # case-insensitive
zstyle ':completion:*' menu select                             # arrow-key menu
zstyle ':completion:*' group-name ''                           # group by category
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
zstyle ':completion:*:warnings' format '%F{red}-- no matches --%f'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"        # colored completions
zstyle ':completion:*' squeeze-slashes true                    # /a//b → /a/b
zstyle ':completion:*:*:kill:*' menu yes select                # nice kill menu
zstyle ':completion:*:kill:*' force-list always

# --- Key bindings (emacs mode) ---
bindkey -e

# Edit current command in $EDITOR with Ctrl-X Ctrl-E
autoload -z edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# Word navigation with Ctrl+Left/Right
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word

# Delete word backward with Ctrl+Backspace
bindkey '^H' backward-kill-word

# --- Environment ---
export EDITOR="nvim"
export VISUAL="nvim"
export LANG="en_US.UTF-8"
export PATH="$HOME/.local/bin:$PATH"

# --- Aliases ---

# Modern replacements
alias ls='eza --group-directories-first --icons'
alias ll='eza -la --group-directories-first --icons'
alias la='eza -a --group-directories-first --icons'
alias lt='eza -T --group-directories-first --icons --level=2'
alias lta='eza -Ta --group-directories-first --icons --level=2'
alias cat='bat --plain'
alias vim='nvim'
alias grep='rg'
alias find='fd'
alias diff='diff --color=auto'

# Git shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gds='git diff --staged'
alias gco='git checkout'
alias gb='git branch'
alias glg='git log --oneline --graph --decorate'
alias gla='git log --oneline --graph --decorate --all'
alias gst='git stash'
alias gstp='git stash pop'
alias lg='lazygit'

# Quick navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'
alias dots='cd ~/dev/infra/dotfiles'

# Docker
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dpsa='docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dlogs='docker logs -f'
alias dexec='docker exec -it'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcl='docker compose logs -f'

# Systemctl
alias sc='systemctl'
alias scu='systemctl --user'
alias scst='systemctl status'
alias jrn='journalctl -eu'

# Safety nets
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

# Tmux
alias ts='tmux-session'

# Misc
alias reload='source ~/.zshrc'
alias path='echo $PATH | tr ":" "\n"'
alias ip='ip -color=auto'

# --- FZF ---
eval "$(fzf --zsh)"

# Theme colors for fzf (rendered from theme palette)
export FZF_DEFAULT_OPTS=" \
  --color=bg+:@@SURFACE0@@,bg:@@BASE@@,spinner:@@ROSEWATER@@,hl:@@RED@@ \
  --color=fg:@@TEXT@@,header:@@RED@@,info:@@MAUVE@@,pointer:@@ROSEWATER@@ \
  --color=marker:@@LAVENDER@@,fg+:@@TEXT@@,prompt:@@MAUVE@@,hl+:@@RED@@ \
  --color=selected-bg:@@SURFACE1@@ \
  --height=40% --layout=reverse --border=rounded --margin=0,1"

# Use fd for file finding (respects .gitignore)
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {}'"
export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --color=always --icons {}'"

# --- zoxide (smarter cd) ---
eval "$(zoxide init zsh)"

# --- yazi — cd into directory on exit ---
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
  export ELECTRON_OZONE_PLATFORM_HINT=wayland
  exec sway
fi
