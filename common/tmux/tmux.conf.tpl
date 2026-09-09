# tmux configuration
# Managed by dotfiles repo.

# --- Prefix ---
unbind C-b
set -g prefix C-Space
bind C-Space send-prefix

# --- General ---
set -g mouse on
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -sg escape-time 0
set -g history-limit 50000
set -g focus-events on
set -g allow-passthrough on
set -s set-clipboard on

# --- True color ---
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"
set -ag terminal-overrides ",ghostty:RGB"

# --- Extended keys (lets terminals send distinct codes for Ctrl+;, Ctrl+/, etc.) ---
set -s extended-keys on
set -as terminal-features 'xterm*:extkeys'
set -as terminal-features 'ghostty:extkeys'

# --- Splits ---
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind %

# New window in current path
bind c new-window -c "#{pane_current_path}"

# Reload config
bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded"

# Pane navigation handled by vim-tmux-navigator (Ctrl+hjkl, no prefix)

# --- Pane resizing ---
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# --- Sessions ---
bind S new-session
bind X confirm-before -p "kill session #S? (y/n)" "run-shell 'tmux switch-client -n \\; kill-session -t \"#S\"'"

# --- Attention: what each pane needs (common/scripts/CLAUDE.md) ---
# Panes flag themselves through tmux-attention; Claude Code does it via the
# hooks in common/claude-code/settings.json. The glyph sits before the window
# name, the counts on the status right, and split windows label their panes.
# In wb-* sessions workbench titles the windows itself, so no glyph there.
set -g @attention_fg_needs_you "@@RED@@"
set -g @attention_fg_done "@@GREEN@@"
set -g @attention_fg_working "@@BLUE@@"
set -g @attention_fg_dim "@@OVERLAY0@@"
set -g @attention_glyph "#{?#{m:wb-*,#{session_name}},,#{?#{==:#{@attention_win},needs-you},#[fg=@@RED@@]? ,#{?#{==:#{@attention_win},done},#[fg=@@GREEN@@]✓ ,#{?#{==:#{@attention_win},working},#[fg=@@BLUE@@]● ,}}}}"
set -g @attention_pane_glyph "#{?#{==:#{@attention},needs-you},#[fg=@@RED@@]? ,#{?#{==:#{@attention},done},#[fg=@@GREEN@@]✓ ,#{?#{==:#{@attention},working},#[fg=@@BLUE@@]● ,}}}"
bind f display-popup -E -w 70% -h 60% "tmux-attention pick"
bind o run-shell "tmux-attention jump"
set-hook -g pane-focus-in 'run-shell -b "tmux-attention seen #{pane_id}"'
set-hook -g after-select-window 'run-shell -b "tmux-attention seen #{pane_id}"'
set-hook -g after-select-pane 'run-shell -b "tmux-attention seen #{pane_id}"'
set-hook -g after-split-window 'run-shell -b "tmux-attention borders #{window_id}"'
set-hook -g after-kill-pane 'run-shell -b "tmux-attention borders #{window_id}"'
set-hook -g pane-exited 'run-shell -b "tmux-attention borders #{window_id}"'
set-hook -g session-closed 'run-shell -b "tmux-attention status"'
set -g pane-border-status off
set -g pane-border-format "#[fg=@@OVERLAY0@@] #{E:@attention_pane_glyph}#[fg=@@SUBTEXT0@@]#{pane_current_command}#{?@attention_reason, · #{@attention_reason},#{?#{==:#{pane_current_command},claude}, · #{s/^[^A-Za-z0-9]* *//:pane_title},}} "

# --- Popups ---
bind g display-popup -E -w 85% -h 85% -d "#{pane_current_path}" lazygit
bind t display-popup -E -w 80% -h 80% -d "#{pane_current_path}"
# One nvim per tmux session, kept alive in a hidden session; the same key
# inside the popup hides it again (common/scripts/CLAUDE.md, "tmux-overlay").
bind v run-shell "tmux-overlay nvim nvim"
# The pane's whole history in nvim, in a window of its own; :q cleans up.
bind e run-shell 'f=$(mktemp -t tmux-scrollback.XXXXXX) && tmux capture-pane -pJ -S - -t "#{pane_id}" > "$f" && tmux new-window -n "e:#{window_name}" "nvim +\$ \"$f\"; rm -f \"$f\""'

# --- Vi copy mode ---
setw -g mode-keys vi
bind -T copy-mode-vi v send-keys -X begin-selection
bind -T copy-mode-vi y send-keys -X copy-selection-and-cancel

# --- tmux-warp (flash.nvim-style jump) ---
# NOTE: must run in the foreground (no -b). Backgrounding detaches warp's
# command-prompt + label overlay from the client, so labels never paint.
bind s run-shell '~/.local/bin/tmux-warp.sh'

# --- Status bar (themed) ---
set -g status-position top
set -g status-interval 5
set -g status-style "bg=@@BASE@@,fg=@@TEXT@@"
set -g status-left "#[bg=@@BLUE@@,fg=@@BASE@@,bold] #S #[default] "
set -g status-left-length 30
set -g status-right "#{E:@attention_status}#[fg=@@SUBTEXT0@@] %H:%M "
set -g status-right-length 60

# Active window
setw -g window-status-current-format "#[bg=@@SURFACE0@@,fg=@@TEXT@@,bold] #{E:@attention_glyph}#[fg=@@TEXT@@]#I:#W "
# Inactive window
setw -g window-status-format "#[fg=@@OVERLAY0@@] #{E:@attention_glyph}#[fg=@@OVERLAY0@@]#I:#W "

# Pane borders
set -g pane-border-style "fg=@@SURFACE0@@"
set -g pane-active-border-style "fg=@@BLUE@@"

# Message style
set -g message-style "bg=@@SURFACE0@@,fg=@@TEXT@@"

# --- TPM (auto-bootstrap) ---
# Plugins live outside the repo; TMUX_PLUGIN_MANAGER_PATH must be set before tpm runs
set-environment -g TMUX_PLUGIN_MANAGER_PATH "$HOME/.local/share/tmux/plugins/"
if "test ! -d ~/.local/share/tmux/plugins/tpm" \
  "run 'git clone --depth 1 https://github.com/tmux-plugins/tpm ~/.local/share/tmux/plugins/tpm && ~/.local/share/tmux/plugins/tpm/bin/install_plugins'"

set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'christoomey/vim-tmux-navigator'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-yank'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'

# Session persistence. Saving stays with continuum; restoring does not --
# it decides whether to run from a `ps | grep "^tmux"` count and then restores
# in the background while the shell is already live, which both skips restores
# at random and corrupts window layouts. workstation/scripts/tmux-attach does
# the restore instead, before the shell exists. `prefix + Ctrl-r` still works.
set -g @resurrect-capture-pane-contents 'on'
set -g @continuum-restore 'off'

run '~/.local/share/tmux/plugins/tpm/tpm'
