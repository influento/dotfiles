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
    "custom/headless",
    "custom/nosleep",
    "pulseaudio",
    "group/connectivity",
    "group/readouts",
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
      "custom/settings",
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
      "2": "<span color=\"@@PEACH@@\"></span>",
      "3": "<span color=\"@@GREEN@@\"></span>",
      "4": "<span color=\"@@MAUVE@@\"></span>",
      "5": "<span color=\"@@YELLOW@@\">󰓔</span>",
      "default": "<span color=\"@@OVERLAY1@@\"></span>"
    }
  },
  "group/readouts": {
    "orientation": "horizontal",
    "modules": [
      "custom/stale-kernel",
      "sway/language",
      "battery"
    ]
  },
  "group/connectivity": {
    "orientation": "horizontal",
    "modules": [
      "custom/usb",
      "custom/network"
    ]
  },
  "sway/mode": {
    "format": "{}"
  },
  "custom/network": {
    "exec": "network-status",
    "return-type": "json",
    "restart-interval": 5,
    "tooltip": false,
    "on-click": "~/.local/bin/widget-toggle network"
  },
  "pulseaudio": {
    "format": "  {volume}%",
    "format-muted": "  mute",
    "on-click": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
    "tooltip": false,
    "on-click-right": "~/.local/bin/widget-toggle audio",
    "on-scroll-up": "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+",
    "on-scroll-down": "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
  },
  "sway/language": {
    "format": " {short}",
    "tooltip": false
  },
  "battery": {
    "states": {
      "warning": 30,
      "critical": 15
    },
    "format": "{icon} {capacity}%",
    "format-charging": "󰂄 {capacity}%",
    "format-plugged": "󰚥 {capacity}%",
    "format-icons": ["󰂎", "󰁺", "󰁾", "󰂁", "󰁹"],
    "tooltip": false
  },
  "custom/claude-usage": {
    "exec": "~/.local/bin/claude-usage-status",
    "return-type": "json",
    "interval": 600,
    "tooltip": false,
    "on-click": "~/.local/bin/widget-toggle claude-usage"
  },
  "custom/settings": {
    "exec": "~/.local/bin/settings-status",
    "return-type": "json",
    "interval": "once",
    "tooltip": false,
    "on-click": "~/.local/bin/widget-toggle settings"
  },
  "custom/stale-kernel": {
    "exec": "~/.local/bin/stale-kernel",
    "return-type": "json",
    "interval": 60,
    "tooltip": true
  },
  "custom/headless": {
    "exec": "~/.local/bin/headless-status",
    "return-type": "json",
    "interval": 5,
    "tooltip": true,
    "on-click": "~/.local/bin/headless off"
  },
  "custom/nosleep": {
    "exec": "~/.local/bin/nosleep-status",
    "return-type": "json",
    "interval": 30,
    "signal": 8,
    "tooltip": false,
    "on-click": "~/.local/bin/nosleep cycle"
  },
  "tray": {
    "spacing": 8,
    "ignore-list": ["dropbox"]
  },
  "custom/calendar": {
    "exec": "~/.local/bin/calendar-status",
    "return-type": "json",
    "interval": 60,
    "tooltip": false,
    "on-click": "~/.local/bin/widget-toggle calendar"
  },
  "custom/usb": {
    "exec": "~/.local/bin/usb-status",
    "return-type": "json",
    "interval": 3,
    "signal": 12,
    "on-click": "~/.local/bin/widget-toggle usb"
  },
  "custom/power": {
    "exec": "~/.local/bin/power-status",
    "return-type": "json",
    "interval": "once",
    "tooltip": false,
    "on-click": "~/.local/bin/widget-toggle power"
  }
}
