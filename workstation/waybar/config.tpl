{
  "layer": "top",
  "position": "top",
  "height": 32,
  "spacing": 8,
  "modules-left": [
    "sway/workspaces",
    "sway/mode"
  ],
  "modules-center": [
    "clock"
  ],
  "modules-right": [
    "group/connectivity",
    "group/system",
    "custom/scaling",
    "tray"
  ],
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
  "group/system": {
    "orientation": "horizontal",
    "modules": [
      "cpu",
      "memory",
      "disk"
    ]
  },
  "group/connectivity": {
    "orientation": "horizontal",
    "modules": [
      "sway/language",
      "pulseaudio",
      "network"
    ]
  },
  "sway/mode": {
    "format": "{}"
  },
  "cpu": {
    "format": "  {usage}%",
    "interval": 5,
    "tooltip-format": "CPU: {usage}% ({avg_frequency} GHz)",
    "on-click": "bash -c \"$HOME/.local/bin/btop-toggle\""
  },
  "memory": {
    "format": "  {}%",
    "interval": 5,
    "tooltip-format": "RAM: {used:0.1f} / {total:0.1f} GiB",
    "on-click": "bash -c \"$HOME/.local/bin/btop-toggle\""
  },
  "disk": {
    "format": "  {percentage_used}%",
    "interval": 30,
    "path": "/",
    "tooltip-format": "Disk: {used} / {total} ({percentage_used}%)",
    "on-click": "bash -c \"$HOME/.local/bin/btop-toggle\""
  },
  "network": {
    "format-wifi": "  {signalStrength}%",
    "format-ethernet": "  {bandwidthTotalBytes}",
    "format-disconnected": "  off",
    "tooltip-format": "{ifname}: {ipaddr}/{cidr}\n↑ {bandwidthUpBytes}  ↓ {bandwidthDownBytes}",
    "interval": 5,
    "on-click": "bash -c \"$HOME/.local/bin/nmgui-toggle\""
  },
  "pulseaudio": {
    "format": "  {volume}%",
    "format-muted": "  mute",
    "on-click": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
    "tooltip-format": "{desc}: {volume}%",
    "on-click-right": "bash -c \"$HOME/.local/bin/pavucontrol-toggle\"",
    "on-scroll-up": "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+",
    "on-scroll-down": "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
  },
  "sway/language": {
    "format": " {short}",
    "tooltip-format": "{long}"
  },
  "custom/scaling": {
    "format": "󰍉",
    "tooltip": false,
    "on-click": "bash -c \"$HOME/.local/bin/scaling-toggle\""
  },
  "tray": {
    "spacing": 8
  },
  "clock": {
    "format": "  {:%a %b %d  %H:%M}",
    "tooltip-format": "{:%A, %B %d %Y}",
    "on-click": "bash -c \"$HOME/.local/bin/calendar-toggle\"",
    "tooltip": false
  }
}
