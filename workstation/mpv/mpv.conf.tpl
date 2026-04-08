# mpv — Media player

# Window
keep-open=yes
autofit=80%
cursor-autohide=1000
force-window=immediate

# Playback
hwdec=auto
volume=80
volume-max=150

# Screenshots
screenshot-directory=~/pictures
screenshot-format=png
screenshot-template=mpv-%F-%n

# Subtitles
slang=en,en-US
sub-auto=fuzzy
sub-font-size=42
sub-color="@@TEXT@@"
sub-border-color="@@CRUST@@"
sub-border-size=2
sub-shadow-offset=1
sub-shadow-color="@@MANTLE@@"

# OSD
osd-level=1
osd-duration=2000
osd-font=JetBrainsMono Nerd Font
osd-font-size=28
osd-color="@@TEXT@@"
osd-border-color="@@CRUST@@"
osd-border-size=2
osd-shadow-offset=1
osd-shadow-color="@@MANTLE@@"

# yt-dlp integration
ytdl=yes
ytdl-format=bestvideo[height<=1080]+bestaudio/best
ytdl-raw-options=ignore-config=
