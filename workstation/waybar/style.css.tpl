/* Waybar style — managed by dotfiles repo */

* {
  font-family: "JetBrainsMono Nerd Font", sans-serif;
  font-size: 12px;
  min-height: 0;
}

window#waybar {
  background-color: @@BASE@@;
  color: @@TEXT@@;
  border-bottom: 2px solid @@SURFACE0@@;
}

#workspaces button {
  padding: 0 8px;
  color: @@TEXT@@;
  background: transparent;
  border: none;
  border-radius: 4px;
  margin: 4px 2px;
}

#workspaces button.focused {
  background-color: @@BLUE@@;
  color: @@BASE@@;
}

#workspaces button.urgent {
  background-color: @@RED@@;
  color: @@BASE@@;
}

#workspaces button.visible {
  background-color: @@SURFACE1@@;
}

#workspaces button:hover {
  background-color: @@SURFACE2@@;
}

#mode {
  padding: 0 8px;
  color: @@RED@@;
  font-weight: bold;
}

#clock,
#cpu,
#memory,
#disk,
#network,
#pulseaudio,
#tray {
  padding: 0 10px;
  margin: 4px 2px;
  border-radius: 4px;
  background-color: @@SURFACE0@@;
  color: @@TEXT@@;
}

#clock {
  color: @@BLUE@@;
  font-weight: bold;
}

#cpu {
  color: @@GREEN@@;
}

#memory {
  color: @@YELLOW@@;
}

#disk {
  color: @@PEACH@@;
}

#network {
  color: @@TEAL@@;
}

#pulseaudio {
  color: @@MAUVE@@;
}

#pulseaudio.muted {
  color: @@SUBTEXT0@@;
}

#network.disconnected {
  color: @@SUBTEXT0@@;
}

#tray > .passive {
  -gtk-icon-effect: dim;
}

#tray > .needs-attention {
  -gtk-icon-effect: highlight;
  background-color: @@RED@@;
}
