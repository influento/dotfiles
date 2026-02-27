# mako — Notification daemon for Wayland

# Positioning
anchor=top-right
layer=overlay
margin=10

# Appearance
font=JetBrainsMono Nerd Font 11
width=350
height=150
padding=12
border-size=2
border-radius=8
icon-path=/usr/share/icons/Papirus-Dark
max-icon-size=48
max-visible=5

# Colors
background-color=@@BASE@@dd
text-color=@@TEXT@@
border-color=@@LAVENDER@@

# Behavior
default-timeout=5000
ignore-timeout=0
sort=-time
group-by=app-name

# Urgency overrides
[urgency=low]
border-color=@@SURFACE2@@
default-timeout=3000

[urgency=critical]
border-color=@@RED@@
default-timeout=0
ignore-timeout=1
