# Sway configuration
# Managed by dotfiles repo.
# Docs: https://man.archlinux.org/man/sway.5

# --- Variables ---
set $mod Mod1
set $term ghostty
set $menu launcher

# --- Input ---
input type:keyboard {
  xkb_layout us,ru
  xkb_options grp:caps_toggle
  repeat_delay 300
  repeat_rate 30
}

input type:touchpad {
  tap enabled
  natural_scroll enabled
  dwt enabled
}

# --- Output ---
include ~/.config/sway/scale.conf

# --- Appearance ---
gaps inner 0
gaps outer 0
smart_borders on
default_border pixel 1
default_floating_border pixel 2

# Theme border colors (rendered from palette)
# class                 border  bg      text    indicator child_border
client.focused          @@BLUE@@ @@BLUE@@ @@BASE@@ @@BLUE@@   @@BLUE@@
client.focused_inactive @@SURFACE1@@ @@SURFACE1@@ @@TEXT@@ @@SURFACE1@@   @@SURFACE1@@
client.unfocused        @@BASE@@ @@BASE@@ @@TEXT@@ @@BASE@@   @@BASE@@
client.urgent           @@RED@@ @@RED@@ @@BASE@@ @@RED@@   @@RED@@

# --- Keybindings: Applications ---
bindsym --to-code $mod+Return exec $term
bindsym --to-code $mod+d exec $menu
bindsym --to-code $mod+Shift+q kill
bindsym --to-code Mod4+v exec ~/.config/cliphist/cliphist-pick.sh
bindsym --to-code $mod+Escape exec ~/.local/bin/lock

# Headless mode: disable the monitor and serve the session over VNC instead
bindsym --to-code $mod+Shift+o exec ~/.local/bin/headless toggle

# Screenshots and GIF clips via `capture` (gtk-widgets). Kept for the whole
# session; wiped at the next sway start (see the capture lines in Autostart below).
bindsym --to-code $mod+p exec capture region --dir ~/pictures/screenshots --copy
bindsym --to-code $mod+Shift+p exec bash -c 'f=$(capture region --dir ~/pictures/screenshots) && drawdesk --image "$f"'
# $mod+g starts a recording, pressing it again stops and saves it.
bindsym --to-code $mod+g exec capture gif --dir ~/pictures/recordings --copy

# --- Keybindings: Focus (vim-style) ---
bindsym --to-code $mod+h focus left
bindsym --to-code $mod+j focus down
bindsym --to-code $mod+k focus up
bindsym --to-code $mod+l focus right

# Arrow key alternatives
bindsym --to-code $mod+Left focus left
bindsym --to-code $mod+Down focus down
bindsym --to-code $mod+Up focus up
bindsym --to-code $mod+Right focus right

# --- Keybindings: Move windows ---
bindsym --to-code $mod+Shift+h move left
bindsym --to-code $mod+Shift+j move down
bindsym --to-code $mod+Shift+k move up
bindsym --to-code $mod+Shift+l move right

bindsym --to-code $mod+Shift+Left move left
bindsym --to-code $mod+Shift+Down move down
bindsym --to-code $mod+Shift+Up move up
bindsym --to-code $mod+Shift+Right move right

# --- Keybindings: Layout ---
bindsym --to-code $mod+b splith
bindsym --to-code $mod+n splitv
bindsym --to-code $mod+s layout stacking
bindsym --to-code $mod+w layout tabbed
bindsym --to-code $mod+e layout toggle split
bindsym --to-code $mod+f fullscreen
bindsym --to-code $mod+Shift+space floating toggle
bindsym --to-code $mod+space focus mode_toggle
bindsym --to-code $mod+a focus parent

# --- Keybindings: Workspaces ---
bindsym --to-code $mod+1 workspace number 1
bindsym --to-code $mod+2 workspace number 2
bindsym --to-code $mod+3 workspace number 3
bindsym --to-code $mod+4 workspace number 4
bindsym --to-code $mod+5 workspace number 5
bindsym --to-code $mod+6 workspace number 6
bindsym --to-code $mod+7 workspace number 7
bindsym --to-code $mod+8 workspace number 8
bindsym --to-code $mod+9 workspace number 9

bindsym --to-code $mod+Shift+1 move container to workspace number 1
bindsym --to-code $mod+Shift+2 move container to workspace number 2
bindsym --to-code $mod+Shift+3 move container to workspace number 3
bindsym --to-code $mod+Shift+4 move container to workspace number 4
bindsym --to-code $mod+Shift+5 move container to workspace number 5
bindsym --to-code $mod+Shift+6 move container to workspace number 6
bindsym --to-code $mod+Shift+7 move container to workspace number 7
bindsym --to-code $mod+Shift+8 move container to workspace number 8
bindsym --to-code $mod+Shift+9 move container to workspace number 9

# --- Keybindings: Local escape while a remote session holds the keyboard ---
# Remote desktop clients ask for the Wayland keyboard-shortcuts-inhibit
# protocol, which Sway honours: while such a window is focused, $mod+1 is
# delivered to the remote session and the local compositor never sees it. That
# is wanted — it is how the remote gets driven — but it leaves no way back.
# --inhibited marks bindings that fire regardless, so these stay local.
# $mod+N still goes to the remote; $mod+Ctrl+N always stays here.
bindsym --to-code --inhibited $mod+Ctrl+1 workspace number 1
bindsym --to-code --inhibited $mod+Ctrl+2 workspace number 2
bindsym --to-code --inhibited $mod+Ctrl+3 workspace number 3
bindsym --to-code --inhibited $mod+Ctrl+4 workspace number 4
bindsym --to-code --inhibited $mod+Ctrl+5 workspace number 5
bindsym --to-code --inhibited $mod+Ctrl+6 workspace number 6
bindsym --to-code --inhibited $mod+Ctrl+7 workspace number 7
bindsym --to-code --inhibited $mod+Ctrl+8 workspace number 8
bindsym --to-code --inhibited $mod+Ctrl+9 workspace number 9

# Move the focused window — typically the remote viewer itself — between local
# workspaces while it still holds the keyboard. Mirrors $mod+Shift+N, which is
# swallowed by the remote session.
bindsym --to-code --inhibited $mod+Ctrl+Shift+1 move container to workspace number 1
bindsym --to-code --inhibited $mod+Ctrl+Shift+2 move container to workspace number 2
bindsym --to-code --inhibited $mod+Ctrl+Shift+3 move container to workspace number 3
bindsym --to-code --inhibited $mod+Ctrl+Shift+4 move container to workspace number 4
bindsym --to-code --inhibited $mod+Ctrl+Shift+5 move container to workspace number 5
bindsym --to-code --inhibited $mod+Ctrl+Shift+6 move container to workspace number 6
bindsym --to-code --inhibited $mod+Ctrl+Shift+7 move container to workspace number 7
bindsym --to-code --inhibited $mod+Ctrl+Shift+8 move container to workspace number 8
bindsym --to-code --inhibited $mod+Ctrl+Shift+9 move container to workspace number 9

# Close the focused window even when it is holding the keyboard, so a
# misbehaving or unresponsive remote viewer can always be dismissed.
bindsym --to-code --inhibited $mod+Ctrl+q kill

# --- Keybindings: Brightness ---
# Fn brightness keys (XF86MonBrightness*), plus $mod+F5/F6 as a fallback for
# keyboards without them. Backend (laptop backlight / DDC) is picked by
# display-brightness from gtk-widgets. --locked: works on the lock screen.
bindsym --to-code --locked XF86MonBrightnessDown exec ~/.local/bin/display-brightness down
bindsym --to-code --locked XF86MonBrightnessUp exec ~/.local/bin/display-brightness up
bindsym --to-code --locked $mod+F5 exec ~/.local/bin/display-brightness down
bindsym --to-code --locked $mod+F6 exec ~/.local/bin/display-brightness up

# --- Keybindings: Resize mode ---
mode "resize" {
  bindsym --to-code h resize shrink width 10px
  bindsym --to-code j resize grow height 10px
  bindsym --to-code k resize shrink height 10px
  bindsym --to-code l resize grow width 10px

  bindsym --to-code Left resize shrink width 10px
  bindsym --to-code Down resize grow height 10px
  bindsym --to-code Up resize shrink height 10px
  bindsym --to-code Right resize grow width 10px

  bindsym --to-code Return mode "default"
  bindsym --to-code Escape mode "default"
}

bindsym --to-code $mod+r mode "resize"

# Language switching handled by xkb_options grp:caps_toggle

# --- Keybindings: Session ---
bindsym --to-code $mod+Shift+c reload

# --- Bar ---
bar {
  swaybar_command waybar
}

# --- Environment ---
exec systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP ELECTRON_OZONE_PLATFORM_HINT
exec dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP ELECTRON_OZONE_PLATFORM_HINT

# --- Autostart ---
exec gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
exec ~/.config/swaybg/wallpaper.sh
exec swayidle -w
exec mako
exec /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec wl-paste --watch cliphist -max-items 100 store
exec ~/.config/wlsunset/wlsunset.sh
exec swayosd-server
exec network-agent
exec launcher --daemon
exec env DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus dropbox
# Screenshots and recordings live for one session: clear the previous session's
# on start. exec, not exec_always -- a config reload must not wipe them mid-session.
exec bash -c 'mkdir -p ~/pictures/screenshots && find ~/pictures/screenshots -maxdepth 1 -name "screenshot-*.png" -delete'
exec bash -c 'mkdir -p ~/pictures/recordings && find ~/pictures/recordings -mindepth 1 -maxdepth 1 -type d -name "recording-*" -exec rm -rf {} +'
exec ~/.local/bin/startup-reminders
exec ~/.local/bin/auto-update

# Lock immediately at session start. Required by the tty1 autologin drop-in in
# arch-install: autologin exists so Sway comes up unattended after a reboot and
# can be reached remotely, not to remove authentication. The session starts
# locked and is unlocked with the password either at the keyboard or over VNC.
# Never enable autologin without this.
exec ~/.local/bin/lock

# Machine-specific overrides (not tracked by dotfiles)
include ~/.local/share/sway/*.conf
