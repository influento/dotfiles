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

Bound workspaces (`headless bind`) are host workspaces on another tool's
HEADLESS-* output, which that tool creates to keep its windows rendering
while nobody looks at them. Each bound one gets its own wayvnc on port
5900 + N and a viewer on workspace N of the viewing machine, running only
while N is visible there (a hidden viewer still decodes the whole stream).
The output itself is never resized, rescaled or unplugged: its owner chose
its size and scale. Bind by workspace number, never by output name: the
owner recreates outputs and their names change. Never move such a workspace
onto headless's own output: its scale differs, and the windows would be
rescaled.

A bound workspace can be made view-only by another tool: while
`$XDG_RUNTIME_DIR/view-only/<n>` exists (the tool writes it while it drives
workspace n), its wayvnc runs with `--disable-input` and `show` leaves the
host's focus off it (focusing a window there can disturb the tool driving
it). The tool that writes the markers runs `headless restream` when they
change, which serves the bound workspaces again with the matching input.
