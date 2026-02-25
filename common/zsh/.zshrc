# ~/.zshrc — Zsh configuration with oh-my-zsh
# Managed by dotfiles repo. Do not edit directly — modify the source in dotfiles/common/zsh/

# --- Oh-My-Zsh ---
export ZSH="$HOME/.oh-my-zsh"

# TODO: Choose theme (powerlevel10k, robbyrussell, etc.)
ZSH_THEME="robbyrussell"

# TODO: Configure plugins
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

# --- Aliases ---

# TODO: Add aliases

# --- Starship prompt ---
# Uncomment once starship.toml is configured:
# eval "$(starship init zsh)"

# --- Tool integrations ---
# TODO: Add fzf, zoxide, etc. integrations
