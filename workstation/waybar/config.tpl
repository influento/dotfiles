{
  "layer": "top",
  "position": "top",
  "height": 32,
  "spacing": 8,
  "modules-left": [
    "group/workspaces"
  ],
  "modules-center": [
    "group/center"
  ],
  "modules-right": [
    "custom/stale-kernel",
    "group/connectivity",
    "group/controls"
  ],
  "group/workspaces": {
    "orientation": "horizontal",
    "modules": [
      "sway/workspaces",
      "sway/mode"
    ]
  },
  "group/center": {
    "orientation": "horizontal",
    "modules": [
      "custom/claude-usage",
      "custom/calendar"
    ]
  },
  "group/controls": {
    "orientation": "horizontal",
    "modules": [
      "custom/display",
      "tray",
      "custom/power"
    ]
  },
  "sway/workspaces": {
    "disable-scroll": true,
    "all-outputs": true,
    "format": "{icon}",
    "format-icons": {
      "1": "<span color=\"@@BLUE@@\"></span>",
      "2": "<span color=\"@@PEACH@@\"></span>",
      "3": "<span color=\"@@GREEN@@\"></span>",
      "4": "<span color=\"@@MAUVE@@\"></span>",
      "default": "<span color=\"@@OVERLAY1@@\"></span>"
    }
  },
  "group/connectivity": {
    "orientation": "horizontal",
    "modules": [
      "custom/usb",
      "sway/language",
      "pulseaudio",
      "custom/bluetooth",
      "network"
    ]
  },
  "sway/mode": {
    "format": "{}"
  },
  "network": {
    "format-wifi": "  {signalStrength}%",
    "format-ethernet": "  {bandwidthTotalBytes}",
    "format-disconnected": "  off",
    "interval": 5,
    "tooltip": false,
    "on-click": "bash -c \"$HOME/.local/bin/nmgui-toggle\""
  },
  "pulseaudio": {
    "format": "  {volume}%",
    "format-muted": "  mute",
    "on-click": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
    "tooltip": false,
    "on-click-right": "bash -c \"$HOME/.local/bin/pavucontrol-toggle\"",
    "on-scroll-up": "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+",
    "on-scroll-down": "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
  },
  "custom/bluetooth": {
    "exec": "bluetooth-status",
    "return-type": "json",
    "interval": 5,
    "signal": 10,
    "tooltip": false,
    "on-click": "bash -c \"$HOME/.local/bin/widget-toggle bluetooth\"",
    "on-click-right": "bash -c \"bluetoothctl show | grep -q 'Powered: yes' && bluetoothctl power off || bluetoothctl power on; pkill -RTMIN+10 waybar\""
  },
  "sway/language": {
    "format": " {short}",
    "tooltip": false
  },
  "custom/claude-usage": {
    "exec": "claude-usage-status",
    "return-type": "json",
    "interval": 600,
    "tooltip": false,
    "on-click": "bash -c \"$HOME/.local/bin/widget-toggle claude-usage\""
  },
  "custom/display": {
    "exec": "display-status",
    "return-type": "json",
    "interval": "once",
    "tooltip": false,
    "on-click": "bash -c \"$HOME/.local/bin/widget-toggle display\""
  },
  "custom/stale-kernel": {
    "exec": "~/.local/bin/stale-kernel",
    "return-type": "json",
    "interval": 60,
    "tooltip": true
  },
  "tray": {
    "spacing": 8
  },
  "custom/calendar": {
    "exec": "calendar-status",
    "return-type": "json",
    "interval": 60,
    "tooltip": false,
    "on-click": "bash -c \"$HOME/.local/bin/widget-toggle calendar\""
  },
  "custom/usb": {
    "exec": "usb-status",
    "return-type": "json",
    "interval": 3,
    "signal": 12,
    "on-click": "widget-toggle usb"
  },
  "custom/power": {
    "exec": "power-status",
    "return-type": "json",
    "interval": "once",
    "tooltip": false,
    "on-click": "bash -c \"$HOME/.local/bin/widget-toggle power\""
  }
}
