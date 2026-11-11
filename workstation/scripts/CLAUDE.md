# Workstation scripts

Deployed to `~/.local/bin/` by `deploy_configs`, which skips `*.md`, so this
file stays here. Each script's header comment says what it does and why; this
file holds only what spans files or repos.

## headless

The rule the whole design rests on: wayvnc serves a virtual output, never a
physical one. A disabled or DPMS-off output is not composited, so the stream
would freeze with no way to wake it remotely. For the same reason
`swayidle/config` calls `headless dpms off`, not `output * power off`. Do not
"simplify" past the comments in `headless` that follow from it.

It needs `wayvnc`, `waypipe`, a VNC client (`virt-viewer`, or `wlvncc` from the
AUR) and tty1 autologin. All are system-level, so they live in arch-install.
