# Workstation scripts

Deployed to `~/.local/bin/` by the `scripts` case of `deploy_configs` in
`lib/helpers.sh`, which skips `*.md` -- this file stays here. Every script here
is desktop-specific (Sway/Wayland); the shared ones live in `common/scripts/`.

The rows in the root CLAUDE.md name each script and where it deploys. What
follows is what a reader cannot get from the code quickly enough.

## auto-update

Background system update on sway start: `yay -Syu` (repos + AUR) + npm updates,
12h cooldown (`--force` to bypass), mako notifications. Orphaned packages
(`pacman -Qtdq`) are reported when the list changes, never removed: a package
installed as a dependency can still be used directly.

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

Two things to know before editing it. The parse loop is `pending_reminders` in
`lib/reminders.sh`, shared with `install.sh`, which shows the same pending lines
as `log_warn` at the end of a deploy — a format change there reaches both. And
the key split is on the *first* colon in the line, so a keyless reminder
containing a colon loses everything before it; give such a line a key, even a
dummy one.

## tmux-attach

What `ghostty/config` runs instead of `tmux new-session -A -s main`. It restores
the saved tmux state and only then attaches, because tmux-continuum's own
auto-restore fails in two independent ways:

| Failure | Mechanism |
| ------- | --------- |
| Restore silently skipped | `another_tmux_server_running_on_startup` counts `ps -u \| grep "^tmux"` and bails above 1. A second terminal opening in the same moment is a second `tmux` process, so the restore never runs and the sessions have to be recovered by hand with `prefix + Ctrl-r` |
| Layouts corrupted | The restore runs in the background while the shell is already live. Panes created in those seconds beat tmux-resurrect's `pane_exists` check, so it splits a pane that already exists; the pane count then no longer matches the saved layout, `select-layout` refuses it (the error is discarded by `restore_window_properties >/dev/null 2>&1`), and the window is left as horizontal strips with 1-row-tall panes. The broken layout is then what gets saved, so it ratchets on every boot |

These things in the script are load-bearing and look removable:

- **`tmux run-shell "$restore_script"`, not a direct call.** `restore.sh` derives
  the server socket from `$TMUX` (`echo $TMUX | cut -d, -f1`). Run outside a tmux
  context that is empty, so `new_session` builds `tmux -S "" new-session` and
  creates nothing — the restore then only refills sessions that already exist and
  drops every other one, with no error.
- **`9>&-` on every tmux command.** The tmux server inherits the fds of whichever
  client forks it and outlives the script, so a server holding the flock fd holds
  the lock forever and every later terminal blocks on `flock`.
- **The `@dotfiles-restored` server option.** Restore must happen once per server,
  not once per terminal, and the server may be started by something other than
  ghostty.
- **`server_is_bare` behind the flag.** A restore ran onto a live server once
  with the flag somehow unset (2026-09-10; the trigger was never found), and
  resurrect renames windows by index, so after windows had closed and the rest
  renumbered, a dead Claude session's title landed on an ssh window for good.
  So the flag is not trusted alone: a server holding anything beyond the
  bootstrap session or a one-window `main` is never restored onto, and gets the
  flag set instead.
- **The `tmux-attach-bootstrap` session, not `main`.** The restore needs a
  server to `run-shell` in, so the script starts one with a session no saved
  state can be named. Afterwards it is killed if anything was restored, or
  renamed to `main` if nothing was. A terminal then attaches to the most
  recently used session that is not `ov-*`, and only falls back to creating
  `main` when there is none. Starting the server with `main` itself left an
  empty `main` after every reboot. Two traps here:
  `session_last_attached` is empty for every just-restored session, so the
  format substitutes 0 to keep the fields from shifting; and a rename onto a
  `main` that saved state already restored fails, which under `set -e` exits
  before the attach, leaving every terminal unable to open.

After the resurrect restore it runs `claude-tmux restore`, which types
`claude --resume` into the panes that ran Claude Code and re-flags what they
were waiting on: `common/scripts/CLAUDE.md`.

## tg

Creates isolated Telegram Desktop instances — each with its own `--workdir` and
`.desktop` launcher, so they appear separately in the app launcher. `create`/`list`/`remove`,
and it auto-runs `update-desktop-database`. The launcher calls `tg-run <slug>`,
which starts the instance with private `XDG_CONFIG_HOME`/`XDG_DATA_HOME` under
`<workdir>/xdg/`: symlinks to every real entry, except `mimeapps.list` (a
private copy) and `applications/` (a private dir). Telegram re-registers itself
as the `tg://` handler on the first launch after every update, with its
`-workdir` command line; without the shadow that rewrites the real
`mimeapps.list` (the dotfiles symlink, so the repo goes dirty) and litters
`userapp-*.desktop` files. The env var the script once set for this
(`TDESKTOP_DISABLE_REGISTER_CUSTOM_SCHEME`) no longer exists in Telegram; the
only in-app switch is an experimental toggle stored in the workdir's encrypted
settings, which cannot be pre-set. Instances made before this need `tg "<name>"`
run again to rewrite their launcher.

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
