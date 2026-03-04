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
    "custom/claude-usage",
    "clock"
  ],
  "modules-right": [
    "group/connectivity",
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
  "group/connectivity": {
    "orientation": "horizontal",
    "modules": [
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
    "exec": "~/.local/bin/bluetooth-widget",
    "return-type": "json",
    "interval": 5,
    "signal": 10,
    "tooltip": false,
    "on-click": "bash -c \"$HOME/.local/bin/widget-toggle bluetooth-popup\"",
    "on-click-right": "bash -c \"bluetoothctl show | grep -q 'Powered: yes' && bluetoothctl power off || bluetoothctl power on; pkill -RTMIN+10 waybar\""
  },
  "sway/language": {
    "format": " {short}",
    "tooltip": false
  },
  "custom/claude-usage": {
    "exec": "~/.local/bin/claude-usage",
    "return-type": "json",
    "interval": 600,
    "tooltip": false,
    "on-click": "bash -c \"$HOME/.local/bin/widget-toggle claude-usage-popup\""
  },
  "custom/scaling": {
    "exec": "echo '{\"text\": \"󰹑 '$(swaymsg -t get_outputs | python3 -c \"import json,sys; o=next(x for x in json.load(sys.stdin) if x.get('active')); print(str(int(o['scale']*100))+'%')\" 2>/dev/null || echo '?')'\", \"class\": \"scaling\"}'",
    "return-type": "json",
    "interval": "once",
    "signal": 11,
    "tooltip": false,
    "on-click": "bash -c \"$HOME/.local/bin/widget-toggle scaling-popup\""
  },
  "tray": {
    "spacing": 8
  },
  "clock": {
    "format": "  {:%a %b %d  %H:%M}",
    "tooltip": false,
    "on-click": "bash -c \"$HOME/.local/bin/widget-toggle calendar-popup\""
  }
}
