# Workstation scripts

Deployed to `~/.local/bin/` by `deploy_scripts`. Every script here is
desktop-specific (Sway/Wayland); the shared ones live in `common/scripts/`.

The rows in the root CLAUDE.md name each script and where it deploys. What
follows is what a reader cannot get from the code quickly enough.

## auto-update

Background system update on sway start: `yay -Syu` (repos + AUR) + npm updates,
12h cooldown (`--force` to bypass), mako notifications.

## startup-reminders

Nags about post-install steps that cannot be automated, until they are done.
`exec`'d from `sway/config.tpl`, it sleeps 10s (so the notification daemon is
up), then fires each pending line as a `notify-send -u critical`.

The data lives in `reminders/*.txt` at the repo root, one reminder per line:

| Line form      | Behaviour                                                        |
| -------------- | ---------------------------------------------------------------- |
| `key:message`  | Shown until `key` appears in `~/.local/state/dotfiles/completed`  |
| `message`      | Shown every time — no way to dismiss it                           |

A script silences its own reminder by appending its key to that state file; see
`setup-wireguard`, whose reminder exists because the WireGuard configs do not
exist until Dropbox has synced.

Two things to know before editing it. The parse loop is duplicated in
`install.sh`, which renders the same files as `log_warn` lines at the end of a
deploy — change the format in one place and you must change it in both. And the
key split is on the *first* colon in the line, so a keyless reminder containing
a colon loses everything before it; give such a line a key, even a dummy one.

## tg

Creates isolated Telegram Desktop instances — each with its own `--workdir` and
`.desktop` launcher, so they appear separately in wofi. `create`/`list`/`remove`,
and it auto-runs `update-desktop-database`.

## nosleep

Toggles auto-suspend inhibition (`on`/`off`/`status`/`toggle`) via a transient
systemd `--user` unit holding a logind block inhibitor. Lock (15m) and
display-off (30m) still apply — only the 60m suspend is blocked. State clears on
reboot.

The waybar indicator shows both states (visible when off too, since that is the
case worth noticing) and toggles on click; state changes signal waybar (RTMIN+8)
for instant feedback.

## headless

`headless on` turns the workstation into a remotely-served box with the monitor
off — a backup profile for power outages, where the 38" ultrawide is the largest
consumer in the setup. `headless off` restores the normal desktop. State is
transient (systemd `--user` unit + `$XDG_RUNTIME_DIR`), so a reboot always comes
back as a normal desktop.

Subcommands are `on`/`off`/`status`/`toggle` (bound to `$mod+Shift+o`, with a
waybar indicator), plus two that run from the other machine: `connect <host>`
opens the session from the laptop over an SSH tunnel, and `app <host> <cmd>`
forwards a single app over waypipe — that one works even with no session
running. The script resolves `SWAYSOCK` itself so it can be driven over SSH.

Four constraints drove the design. Do not "simplify" past them:

1. **Never capture a physical output.** A disabled or DPMS-off output stops
   being composited, so `wlr-screencopy` has no frames and the VNC stream
   freezes with no way to wake it remotely. wayvnc is always pointed at a
   virtual output, which is composited regardless of monitor state.
2. **Never assume `HEADLESS-1`.** Sway increments the suffix on every
   `create_output` for the compositor's lifetime, so the second toggle yields
   `HEADLESS-2`. Resolve the name via the `HEADLESS-` prefix at call time.
3. **Always set the virtual output's scale explicitly.** `sway/scale.conf` sets
   `output * scale 1.3` for the ultrawide; inherited, it misrenders the remote
   view. Mode and scale are both required on a HiDPI client: mode sets the
   framebuffer wayvnc streams, scale sets the logical layout inside it. Wrong
   scale gives half-size UI or a blurry upscale.
4. **Idle handling must skip virtual outputs.** `swayidle/config` calls
   `headless dpms off` rather than `output * power off` for exactly this reason,
   and `headless on` invokes `nosleep on`, since the 60-minute
   `systemctl suspend` would otherwise drop every remote session (WiFi-only, so
   no Wake-on-LAN). It claims that inhibitor only when it is not already held
   and releases it only when it claimed it — tracked by
   `$XDG_RUNTIME_DIR/headless.nosleep-owned` — so ending headless mode never
   silently undoes a nosleep the user set by hand.

Remote viewers hold a Wayland keyboard-shortcuts inhibitor, which Sway honours,
so while the viewer is focused `$mod+1` drives the *remote* session and the
local compositor never sees it. That is the desired behaviour, but it needs an
escape: `sway/config.tpl` binds `$mod+Ctrl+1`–`9` and `$mod+Ctrl+q` with
`--inhibited`, which fires regardless of any inhibitor. `Shift+F11` (passed to
remote-viewer via `--hotkeys`) leaves fullscreen.

The viewer matters as much as the geometry. tigervnc's `vncviewer` is X11-only,
so under Sway it runs through XWayland and a scaled output renders it at 1x then
upscales — halving the effective resolution of a HiDPI stream. `connect` prefers
`wlvncc` (AUR, purpose-built for wayvnc), then `remote-viewer` (virt-viewer,
GTK/Wayland-native), and only falls back to `vncviewer` with a warning and
`RemoteResize=0` (which otherwise logs `SetDesktopSize failed`, since wayvnc
cannot resize a Sway output on request). Override with `HEADLESS_VIEWER`.

Geometry resolution order is environment > `~/.config/headless.conf` (untracked,
per-machine) > built-in default. `headless connect` overrides all of them by
detecting the connecting machine's own output and passing it to the far side,
which works because both machines run this same Sway config.

`output <name> disable` is used rather than `power off` because it both drops
the monitor to standby and makes Sway migrate the workspaces to the virtual
output automatically. The workspace-to-output layout is recorded on the way in
and restored on the way out.

Requires `wayvnc`, `waypipe` and a VNC client (`virt-viewer`, or `wlvncc` from
the AUR), plus tty1 autologin. All system-level, so they live in arch-install.


### swayidle

`swayidle/config` calls `headless dpms off` rather than `output * power off` so
that idle handling never powers off the virtual output — constraint 4 above,
enforced from outside this directory.
