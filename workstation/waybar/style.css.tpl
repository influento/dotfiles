/* Waybar style — managed by dotfiles repo */

* {
  font-family: "JetBrainsMono Nerd Font", sans-serif;
  font-size: 15px;
  min-height: 0;
}

window#waybar {
  background-color: @@BASE@@;
  color: @@TEXT@@;
  border-bottom: 2px solid @@SURFACE0@@;
}

#workspaces button {
  padding: 0 10px;
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

#group-connectivity {
  background-color: @@SURFACE0@@;
  border-radius: 8px;
  padding: 0 4px;
  margin: 4px 2px;
}

#clock,
#language,
#network,
#pulseaudio,
#custom-bluetooth,
#custom-claude-usage,
#custom-scaling,
#custom-stale-kernel,
#custom-power,
#tray {
  padding: 0 8px;
  margin: 4px 2px;
  border-radius: 4px;
  min-width: 30px;
  color: @@TEXT@@;
}

#custom-claude-usage.low {
  color: @@GREEN@@;
}

#custom-claude-usage.medium {
  color: @@YELLOW@@;
}

#custom-claude-usage.high {
  color: @@RED@@;
}

#custom-claude-usage.error {
  color: @@SURFACE2@@;
}

#custom-scaling {
  color: @@SAPPHIRE@@;
}

#tray {
  background-color: @@SURFACE0@@;
}

#clock {
  color: @@BLUE@@;
  font-weight: bold;
}

#language {
  color: @@LAVENDER@@;
  font-weight: bold;
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

#custom-stale-kernel.active {
  color: @@PEACH@@;
}

#custom-stale-kernel.inactive {
  font-size: 0;
  padding: 0;
  margin: 0;
  min-width: 0;
}

#custom-bluetooth {
  color: @@BLUE@@;
}

#custom-bluetooth.off {
  color: @@SUBTEXT0@@;
}

#custom-bluetooth.connected {
  color: @@GREEN@@;
}

#custom-bluetooth.error {
  color: @@RED@@;
}

#custom-power {
  color: @@SUBTEXT0@@;
  font-size: 18px;
}

#tray > .passive {
  -gtk-icon-effect: dim;
}

#tray > .needs-attention {
  -gtk-icon-effect: highlight;
  background-color: @@RED@@;
}
