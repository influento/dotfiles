# tmux configuration
# Managed by dotfiles repo.

# --- Prefix ---
unbind C-b
set -g prefix C-Space
bind C-Space send-prefix

# --- General ---
set -g mouse on
# tmux 3.8 opens a floating pane on a Ctrl+drag; a Ctrl+click that moves
# a little leaves a stray 1x1 one. Keep the mouse, drop that.
unbind -n C-MouseDrag1Pane
unbind -n C-MouseDrag1Empty
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -sg escape-time 0
set -g history-limit 50000
set -g focus-events on
# The terminal tmux runs in is titled "tmux": `terminal` ($mod+Return in
# sway) finds it by that, apart from Ghostty windows that run nvim.
set -g set-titles on
set -g set-titles-string "tmux"
set -g allow-passthrough on
set -s set-clipboard on
# Every run-shell -b in this file prints nothing and exits 0: tmux 3.8
# crashes (cmd-run-shell.c:94) when a background job prints or fails while
# its client sits in a session with no windows, as a closing ov-* session is.
# A failure that matters goes to display-message instead.
# OSC 52 copies from panes (nvim over ssh, Claude Code) reach the system
# clipboard through wl-copy: Ghostty denies OSC 52 writes, see its config.
set-hook -g pane-set-clipboard 'run-shell -b "{ command -v wl-copy && tmux save-buffer - | wl-copy; } >/dev/null 2>&1 || true"'

# --- True color ---
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"
set -ag terminal-overrides ",ghostty:RGB"

# --- Extended keys (lets terminals send distinct codes for Ctrl+;, Ctrl+/, etc.) ---
set -s extended-keys on
set -as terminal-features 'xterm*:extkeys'
set -as terminal-features 'ghostty:extkeys'

# --- Hyperlinks (OSC 8: delta's clickable file names and line numbers) ---
set -as terminal-features 'xterm*:hyperlinks'
set -as terminal-features 'ghostty:hyperlinks'

# --- Splits ---
# With the focus in tmux-agent's sidebar, | and - split the main pane used last,
# in its folder. tmux-agent sets the @sidebar_* options, so without it (servers)
# each key is the plain split.
bind | if -F '#{&&:#{@sidebar_client},#{P:#{?#{==:#{pane_id},#{@sidebar_last}},1,}}}' "run-shell -C \"select-pane -t #{@sidebar_last} ; split-window -h -c '##{pane_current_path}'\"" 'split-window -h -c "#{pane_current_path}"'
bind - if -F '#{&&:#{@sidebar_client},#{P:#{?#{==:#{pane_id},#{@sidebar_last}},1,}}}' "run-shell -C \"select-pane -t #{@sidebar_last} ; split-window -v -c '##{pane_current_path}'\"" 'split-window -v -c "#{pane_current_path}"'
unbind '"'
unbind %

# --- Window keys ---
# With tmux-agent's sidebar open, n/p/1-9 move the sidebar and switch windows in
# one draw; otherwise they are tmux's defaults.
bind n if -F '#{@sidebar_open}' "run-shell \"tmux-agent sidebar step '#{client_name}' +\"" 'next-window'
bind p if -F '#{@sidebar_open}' "run-shell \"tmux-agent sidebar step '#{client_name}' -\"" 'previous-window'
bind 1 if -F '#{@sidebar_open}' "run-shell \"tmux-agent sidebar step '#{client_name}' 1\"" 'select-window -t :=1'
bind 2 if -F '#{@sidebar_open}' "run-shell \"tmux-agent sidebar step '#{client_name}' 2\"" 'select-window -t :=2'
bind 3 if -F '#{@sidebar_open}' "run-shell \"tmux-agent sidebar step '#{client_name}' 3\"" 'select-window -t :=3'
bind 4 if -F '#{@sidebar_open}' "run-shell \"tmux-agent sidebar step '#{client_name}' 4\"" 'select-window -t :=4'
bind 5 if -F '#{@sidebar_open}' "run-shell \"tmux-agent sidebar step '#{client_name}' 5\"" 'select-window -t :=5'
bind 6 if -F '#{@sidebar_open}' "run-shell \"tmux-agent sidebar step '#{client_name}' 6\"" 'select-window -t :=6'
bind 7 if -F '#{@sidebar_open}' "run-shell \"tmux-agent sidebar step '#{client_name}' 7\"" 'select-window -t :=7'
bind 8 if -F '#{@sidebar_open}' "run-shell \"tmux-agent sidebar step '#{client_name}' 8\"" 'select-window -t :=8'
bind 9 if -F '#{@sidebar_open}' "run-shell \"tmux-agent sidebar step '#{client_name}' 9\"" 'select-window -t :=9'

# New window in current path
bind c new-window -c "#{pane_current_path}"

# Windows name themselves after the foreground command; an ssh window takes
# the destination as typed instead, `myserver(ssh)` or the IP when that is
# what was typed. The shell's preexec hook puts it in the pane option
# @ssh_host (common/zsh/.zshrc.tpl) and clears it at the next prompt, so the
# name falls back to the shell when ssh ends. A window renamed by hand has
# automatic-rename off, so it keeps its name.
setw -g automatic-rename-format "#{?pane_in_mode,[tmux],#{?#{==:#{pane_current_command},ssh},#{?@ssh_host,#{@ssh_host}(ssh),ssh},#{pane_current_command}}}#{?pane_dead,[dead],}"

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
# Kill the session after moving the client to the next one, so the terminal
# stays open. tmux-revive forgets it first: a session killed by hand never
# comes back on a restore, the last one included.
bind X confirm-before -p "kill session #S? (y/n)" "run-shell 'command -v tmux-revive >/dev/null && tmux-revive forget-session \"#S\"; tmux switch-client -n \\; kill-session -t \"=#S\"'"

# --- Attention: what each pane needs (tmux-agent, influento/tmux-plugins) ---
# tmux-agent flags each pane from its agent's launcher and hooks (Claude
# Code's are in common/claude-code/settings.json). It draws the flags with
# these colours into @attention_mark on each pane, @attention_win_mark on each
# window and @attention_status; the formats below only print them, and
# prefix r redraws them with new colours.
set -g @attention_fg_needs_you "@@RED@@"
set -g @attention_fg_done "@@GREEN@@"
set -g @attention_fg_working "@@BLUE@@"
set -g @attention_fg_failed "@@PEACH@@"
set -g @attention_fg_dim "@@OVERLAY0@@"
set -g @attention_fg_role "@@MAUVE@@"
set -g @attention_fg_repo "@@TEAL@@"
# tmux-overlay's hidden sessions: tmux-agent's lists and tmux-revive's attach
# skip them.
set -g @skip_sessions 'ov-*'
bind f run-shell -b "{ if command -v tmux-agent; then tmux-agent popup #{client_name} || tmux display-message -c '#{client_name}' 'tmux-agent popup failed'; else tmux display-message -c '#{client_name}' 'tmux-agent is not installed'; fi; } >/dev/null 2>&1 || true"
bind o run-shell "if command -v tmux-agent >/dev/null; then tmux-agent jump; else tmux display-message 'tmux-agent is not installed'; fi"
# Hooks: tmux-agent sets its own at index [10] and tmux-revive at [20], from
# their tmux-init lines at the end of this file; [0] is free for this file.
# Never `set-hook -u` without an index: it unsets every index of the hook.

# --- Popups ---
# tmux 3.8 made popups grey by default (themedarkgrey); keep them on the theme.
set -g popup-style "bg=@@BASE@@,fg=@@TEXT@@"
set -g popup-border-style "bg=@@BASE@@,fg=@@LAVENDER@@"
# Programs in popups: lazygit and nvim kept in hidden sessions, one per git
# repo shared by every session; the shell new at every open and ended when
# its popup closes (common/scripts/CLAUDE.md, "tmux-overlay"). run-shell
# sets no pane and no client, so the bindings pass both.
%hidden OV_G="TMUX_PANE='#{pane_id}' tmux-overlay -c '#{client_name}' -s repo lazygit lazygit"
%hidden OV_V="TMUX_PANE='#{pane_id}' tmux-overlay -c '#{client_name}' -s repo nvim nvim"
%hidden OV_T="TMUX_PANE='#{pane_id}' tmux-overlay -c '#{client_name}' -s popup shell \"\${SHELL:-sh}\""
bind g run-shell "$OV_G"
bind v run-shell "$OV_V"
bind t run-shell "$OV_T"
# Inside an overlay popup: its hidden session has no prefix and uses these
# tables, so a popup never opens another popup or leaves for a session.
# Prefix + the popup's own key closes it, another overlay's key swaps the
# popup to that overlay, the prefix twice reaches the program, every other
# prefix key does nothing. Keep C-Space equal to the prefix.
bind -T ov-root C-Space switch-client -T ov-prefix
bind -T ov-prefix C-Space send-keys C-Space
bind -T ov-prefix g run-shell "$OV_G"
bind -T ov-prefix v run-shell "$OV_V"
bind -T ov-prefix t run-shell "$OV_T"
# A closed session can leave hidden ones nothing owns; each press checks too.
set-hook -g session-closed[0] 'run-shell -b "tmux-overlay --reap >/dev/null 2>&1 || true"'
# The pane's whole history in nvim, in a window of its own; :q cleans up. The
# file name is what lua/scrollback.lua keys on for ]] and [[ between prompts.
bind e run-shell 'f=$(mktemp -t tmux-scrollback.XXXXXX) && tmux capture-pane -pJ -S - -t "#{pane_id}" > "$f" && tmux new-window -n "e:#{window_name}" "nvim +\$ \"$f\"; rm -f \"$f\""'

# --- Vi copy mode ---
setw -g mode-keys vi
bind -T copy-mode-vi v send-keys -X begin-selection
bind -T copy-mode-vi y send-keys -X copy-selection-and-cancel

# --- tmux-warp (flash.nvim-style jump) ---
# Works in the foreground and with run-shell -b alike on tmux 3.8.
bind s run-shell '~/.local/bin/tmux-warp.sh'

# --- Status bar (themed) ---
set -g status-position top
set -g status-interval 5
set -g status-style "bg=@@BASE@@,fg=@@TEXT@@"
set -g status-left "#[fg=@@LAVENDER@@,bold] #S #[default] "
set -g status-left-length 30
set -g status-right "#{E:@attention_status} "
set -g status-right-length 60

# Active window
setw -g window-status-current-format "#[bg=@@SURFACE0@@,fg=@@TEXT@@,bold] #{@attention_win_mark}#[fg=@@TEXT@@]#I:#W "
# Inactive window
setw -g window-status-format "#[fg=@@OVERLAY0@@] #{@attention_win_mark}#[fg=@@OVERLAY0@@]#I:#W "

# Panes: main area mantle, panel base, the gap beside the panel in the
# main colour; surface1 lines between main panes, lavender on the
# focused one; unfocused text subtext0. No label lines.
set -g @attention_borders off
set -g pane-border-status off
set -g pane-border-indicators off
set -g pane-border-lines single
set -g pane-border-style "#{?#{@sidebar_client},bg=@@MANTLE@@ fg=@@MANTLE@@,bg=@@MANTLE@@ fg=@@SURFACE1@@}"
set -g pane-active-border-style "#{?#{@sidebar_client},bg=@@MANTLE@@ fg=@@MANTLE@@,bg=@@MANTLE@@ fg=@@LAVENDER@@}"
set -g window-style "bg=@@MANTLE@@,fg=@@SUBTEXT0@@"
set -g window-active-style "bg=@@MANTLE@@,fg=@@TEXT@@"
# The panel (prefix f): its colours, focused, and its cursor row
set -g @sidebar_style "bg=@@BASE@@,fg=@@SUBTEXT0@@"
set -g @sidebar_active_style "bg=@@BASE@@,fg=@@TEXT@@"
set -g @sidebar_cursor_style "bg=@@SURFACE1@@,fg=@@LAVENDER@@"

# Copy mode: selection, search matches, the current match
set -g mode-style "bg=@@LAVENDER@@,fg=@@CRUST@@"
set -g copy-mode-match-style "bg=@@YELLOW@@,fg=@@CRUST@@"
set -g copy-mode-current-match-style "bg=@@PEACH@@,fg=@@CRUST@@"

# No menus (right-click, prefix < and >) and no pane numbers (prefix q).
# A right-click still reaches programs that use the mouse.
unbind '<'
unbind '>'
unbind q
unbind -n MouseDown3Status
unbind -n MouseDown3StatusLeft
unbind -n MouseDown3Empty
unbind -n M-MouseDown3Pane
unbind -n M-MouseDown3Status
unbind -n M-MouseDown3StatusLeft
unbind -n M-MouseDown3Empty
bind -n MouseDown3Pane { select-pane -t= ; send-keys -M }

# Message style
set -g message-style "bg=@@SURFACE0@@,fg=@@TEXT@@"

# --- Saved sessions (tmux-revive, influento/tmux-plugins) ---
# tmux-revive saves every session, window and pane on each change, and
# tmux-attach restores them when a terminal starts a new server. Scrollback
# is captured on a timer instead: every minute and the whole history-limit,
# as resurrect captured it at each of its 1-minute saves. prefix C-s saves
# and captures now, before a planned reboot say; prefix C-r adds back what
# the live server lacks. A save adds a snapshot only when the sessions,
# windows or panes change, and 500 are kept: the 31 days of resurrect saves
# held 79 such changes.
set -g @revive_snapshots 500
set -g @revive_scrollback_lines 50000
set -g @revive_scrollback_interval 60
bind C-s run-shell "if command -v tmux-revive >/dev/null; then tmux-revive save && tmux-revive capture && tmux display-message 'Sessions saved'; else tmux display-message 'tmux-revive is not installed'; fi"
bind C-r run-shell "if command -v tmux-revive >/dev/null; then tmux-revive restore; else tmux display-message 'tmux-revive is not installed'; fi"

# --- TPM (auto-bootstrap) ---
# Plugins live outside the repo; TMUX_PLUGIN_MANAGER_PATH must be set before tpm runs
set-environment -g TMUX_PLUGIN_MANAGER_PATH "$HOME/.local/share/tmux/plugins/"
if "test ! -d ~/.local/share/tmux/plugins/tpm" \
  "run 'git clone --depth 1 https://github.com/tmux-plugins/tpm ~/.local/share/tmux/plugins/tpm && ~/.local/share/tmux/plugins/tpm/bin/install_plugins'"

set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'christoomey/vim-tmux-navigator'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-yank'

run '~/.local/share/tmux/plugins/tpm/tpm'

# Last, after tpm: each plugin sets its hooks at its own index and draws its
# options again, so prefix r applies a new tmux.conf without duplicates.
run-shell 'command -v tmux-agent >/dev/null && tmux-agent tmux-init || true'
run-shell 'command -v tmux-revive >/dev/null && tmux-revive tmux-init || true'
