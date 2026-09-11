# ~/.zshrc — Zsh configuration with oh-my-zsh
# Managed by dotfiles repo. Do not edit directly — modify the source in dotfiles/common/zsh/

# --- Oh-My-Zsh ---
export ZSH="$HOME/.oh-my-zsh"

# Move compinit cache out of $HOME
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
export ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-${ZSH_VERSION}"

# Starship handles the prompt
ZSH_THEME=""

# Auto-update silently (never prompt — it blocks tty login)
zstyle ':omz:update' mode auto
zstyle ':omz:update' frequency 7

# Plugin config (before sourcing omz)
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

plugins=(
  git
  sudo                      # ESC ESC to prepend sudo to last/current command
  extract                   # `extract archive.tar.gz` — handles any archive format
  vi-mode                   # vim keybindings on the command line (ESC for normal mode)
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

# --- Key bindings (vi mode) ---
# vi-mode plugin runs `bindkey -v`; KEYTIMEOUT makes ESC switch modes instantly
KEYTIMEOUT=1

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
[[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && export PATH="$HOME/.local/bin:$PATH"
[[ -d "$HOME/.dotnet/tools" && ":$PATH:" != *":$HOME/.dotnet/tools:"* ]] && export PATH="$HOME/.dotnet/tools:$PATH"
# Let `require()` find globally-installed npm libs (prefix ~/.local), e.g. the
# `docx` lib used by the Claude docx skill. CLI bins resolve via PATH already.
[[ -d "$HOME/.local/lib/node_modules" ]] && export NODE_PATH="$HOME/.local/lib/node_modules${NODE_PATH:+:$NODE_PATH}"

# --- Aliases ---

# Modern replacements, interactive shells only. An agent that sources this
# file from a `zsh -c` shell (Claude Code snapshots it that way into every
# Bash tool call) would otherwise get eza and bat rejecting the flags a
# model passes to ls and cat, and -i prompts hanging a tool call until its
# timeout, since nobody is there to answer.
if [[ -o interactive ]]; then
  alias ls='eza --group-directories-first --icons'
  alias ll='eza -la --group-directories-first --icons'
  alias la='eza -a --group-directories-first --icons'
  alias lt='eza -T --group-directories-first --icons --level=2'
  alias lta='eza -Ta --group-directories-first --icons --level=2'
  alias cat='bat --plain'
fi
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

# Quick navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'
alias dots='cd ~/dev/infra/dotfiles'
alias cpwd='pwd | wl-copy'

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

# Safety nets, interactive shells only (see "Modern replacements")
if [[ -o interactive ]]; then
  alias rm='rm -i'
  alias mv='mv -i'
  alias cp='cp -i'
fi

# Tmux
alias ts='tmux-session'

# Misc
alias reload='source ~/.zshrc'
alias path='echo $PATH | tr ":" "\n"'
alias ip='ip -color=auto'

# --- tmux: ssh windows named after the host ---
# preexec sees the command line before it runs. The ssh destination, as
# typed and without the user part, goes into the pane option @ssh_host;
# tmux's automatic-rename-format (common/tmux/tmux.conf.tpl) renders it as
# `host(ssh)` while ssh is the foreground command. The next prompt clears it.
if [[ -n "$TMUX" ]]; then
  _tmux_ssh_host() {
    setopt local_options extended_glob
    local -a words
    local w host= skip=0 seen=0
    words=(${(z)1})
    for w in "${words[@]}"; do
      if (( ! seen )); then
        case "$w" in
          [A-Za-z_][A-Za-z0-9_]#=*|nocorrect|noglob|command|exec) continue ;;
          ssh) seen=1; continue ;;
          *) return 1 ;;
        esac
      fi
      if (( skip )); then skip=0; continue; fi
      case "$w" in
        '|'|'||'|'&&'|';'|'&') break ;;
        # a flag cluster ending in an option that takes a value: skip the value
        -[46AaCfGgKkMNnqsTtVvXxYy]#[bcDEeFIiJLlmOopQRSWw]) skip=1 ;;
        -*) ;;
        *) host="$w"; break ;;
      esac
    done
    [[ -n "$host" ]] || return 1
    if [[ "$host" == ssh://* ]]; then
      host="${host#ssh://}"; host="${host%%/*}"; host="${host%:[0-9]##}"
    fi
    print -r -- "${host##*@}"
  }
  _tmux_ssh_preexec() {
    local host
    host=$(_tmux_ssh_host "$2") || return 0
    tmux set -p @ssh_host "$host" 2>/dev/null && _tmux_ssh_set=1
  }
  _tmux_ssh_precmd() {
    [[ -n "${_tmux_ssh_set:-}" ]] || return 0
    unset _tmux_ssh_set
    tmux set -pu @ssh_host 2>/dev/null
  }
  autoload -Uz add-zsh-hook
  add-zsh-hook preexec _tmux_ssh_preexec
  add-zsh-hook precmd _tmux_ssh_precmd
fi

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

# --- Starship prompt ---
eval "$(starship init zsh)"

# --- First-login hint ---
# `gh auth token` reads stored credentials only — no network call on shell startup
if command -v gh &>/dev/null && ! gh auth token &>/dev/null; then
  echo "→ Run setup-github to configure SSH + GitHub"
fi

# --- Workstation extras (deployed only on workstation profile) ---
# shellcheck disable=SC1091
[[ -f "$HOME/.zshrc-workstation" ]] && source "$HOME/.zshrc-workstation"
