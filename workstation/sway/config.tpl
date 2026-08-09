# Sway configuration
# Managed by dotfiles repo.
# Docs: https://man.archlinux.org/man/sway.5

# --- Variables ---
set $mod Mod1
set $term ghostty
set $menu wofi --show drun

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
bindsym $mod+Return exec $term
bindsym $mod+d exec $menu
bindsym $mod+Shift+q kill
bindsym Mod4+v exec ~/.config/cliphist/cliphist-pick.sh
bindsym $mod+Escape exec ~/.local/bin/lock

# Headless mode: disable the monitor and serve the session over VNC instead
bindsym $mod+Shift+o exec ~/.local/bin/headless toggle

# Screenshots
bindsym $mod+p exec bash -c 'mkdir -p ~/pictures && f=~/pictures/screenshot-$(date +%Y%m%d-%H%M%S).png && grim -g "$(slurp)" "$f" && wl-copy -t text/uri-list "file://$f" && (sleep 20 && rm -f "$f") &'
bindsym $mod+Shift+p exec bash -c 'mkdir -p ~/pictures && f=~/pictures/screenshot-$(date +%Y%m%d-%H%M%S).png && grim -g "$(slurp)" "$f" && drawdesk --image "$f" && (sleep 20 && rm -f "$f") &'

# --- Keybindings: Focus (vim-style) ---
bindsym $mod+h focus left
bindsym $mod+j focus down
bindsym $mod+k focus up
bindsym $mod+l focus right

# Arrow key alternatives
bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right

# --- Keybindings: Move windows ---
bindsym $mod+Shift+h move left
bindsym $mod+Shift+j move down
bindsym $mod+Shift+k move up
bindsym $mod+Shift+l move right

bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Right move right

# --- Keybindings: Layout ---
bindsym $mod+b splith
bindsym $mod+n splitv
bindsym $mod+s layout stacking
bindsym $mod+w layout tabbed
bindsym $mod+e layout toggle split
bindsym $mod+f fullscreen
bindsym $mod+Shift+space floating toggle
bindsym $mod+space focus mode_toggle
bindsym $mod+a focus parent

# --- Keybindings: Workspaces ---
bindsym $mod+1 workspace number 1
bindsym $mod+2 workspace number 2
bindsym $mod+3 workspace number 3
bindsym $mod+4 workspace number 4
bindsym $mod+5 workspace number 5
bindsym $mod+6 workspace number 6
bindsym $mod+7 workspace number 7
bindsym $mod+8 workspace number 8
bindsym $mod+9 workspace number 9

bindsym $mod+Shift+1 move container to workspace number 1
bindsym $mod+Shift+2 move container to workspace number 2
bindsym $mod+Shift+3 move container to workspace number 3
bindsym $mod+Shift+4 move container to workspace number 4
bindsym $mod+Shift+5 move container to workspace number 5
bindsym $mod+Shift+6 move container to workspace number 6
bindsym $mod+Shift+7 move container to workspace number 7
bindsym $mod+Shift+8 move container to workspace number 8
bindsym $mod+Shift+9 move container to workspace number 9

# --- Keybindings: Local escape while a remote session holds the keyboard ---
# Remote desktop clients ask for the Wayland keyboard-shortcuts-inhibit
# protocol, which Sway honours: while such a window is focused, $mod+1 is
# delivered to the remote session and the local compositor never sees it. That
# is wanted — it is how the remote gets driven — but it leaves no way back.
# --inhibited marks bindings that fire regardless, so these stay local.
# $mod+N still goes to the remote; $mod+Ctrl+N always stays here.
bindsym --inhibited $mod+Ctrl+1 workspace number 1
bindsym --inhibited $mod+Ctrl+2 workspace number 2
bindsym --inhibited $mod+Ctrl+3 workspace number 3
bindsym --inhibited $mod+Ctrl+4 workspace number 4
bindsym --inhibited $mod+Ctrl+5 workspace number 5
bindsym --inhibited $mod+Ctrl+6 workspace number 6
bindsym --inhibited $mod+Ctrl+7 workspace number 7
bindsym --inhibited $mod+Ctrl+8 workspace number 8
bindsym --inhibited $mod+Ctrl+9 workspace number 9

# Close the focused window even when it is holding the keyboard, so a
# misbehaving or unresponsive remote viewer can always be dismissed.
bindsym --inhibited $mod+Ctrl+q kill

# --- Keybindings: Resize mode ---
mode "resize" {
  bindsym h resize shrink width 10px
  bindsym j resize grow height 10px
  bindsym k resize shrink height 10px
  bindsym l resize grow width 10px

  bindsym Left resize shrink width 10px
  bindsym Down resize grow height 10px
  bindsym Up resize shrink height 10px
  bindsym Right resize grow width 10px

  bindsym Return mode "default"
  bindsym Escape mode "default"
}

bindsym $mod+r mode "resize"

# Language switching handled by xkb_options grp:caps_toggle

# --- Keybindings: Session ---
bindsym $mod+Shift+c reload

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
exec wl-paste --watch cliphist store
exec ~/.config/wlsunset/wlsunset.sh
exec swayosd-server
exec nm-applet --indicator
exec env DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus dropbox
exec env DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus PATH=$HOME/.local/share/JetBrains/Toolbox/bin:$PATH jetbrains-toolbox
exec startup-reminders
exec auto-update

# Lock immediately at session start. Required by the tty1 autologin drop-in
# (see docs/arch-install-staging.md): autologin exists so Sway comes up
# unattended after a reboot and can be reached remotely, not to remove
# authentication. The session starts locked and is unlocked with the password
# either at the keyboard or over VNC. Never enable autologin without this.
exec ~/.local/bin/lock

# Machine-specific overrides (not tracked by dotfiles)
include ~/.local/share/sway/*.conf
