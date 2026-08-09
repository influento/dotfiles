# Staged changes for arch-install

System-level changes that this repo depends on but must not own. Apply these in
the `arch-install` repo, not here.

## Packages required by headless mode

`workstation/scripts/headless` fails cleanly when these are missing, so the
dotfiles deploy is safe without them, but the feature does nothing until they
are installed.

| Package       | Repo    | Needed for                                                        |
| ------------- | ------- | ----------------------------------------------------------------- |
| `wayvnc`      | `extra` | Serving the Sway session over VNC (`headless on`)                 |
| `waypipe`     | `extra` | Forwarding single remote apps (`headless app`)                    |
| `virt-viewer` | `extra` | `remote-viewer`, the Wayland-native client `headless connect` uses |
| `tigervnc`    | `extra` | `vncviewer`, the X11 fallback client only                         |
| `wlvncc-git`  | AUR     | Optional. Best-quality client, written for wayvnc                 |

Both machines carry the same package set, so install all of these on each:
`headless connect` runs on the machine you connect *from*, `headless on` on the
machine being served, and either box can play either role.

The client choice matters. `tigervnc`'s `vncviewer` links only X11, so under
Sway it goes through XWayland and a scaled output is rendered at 1x then
upscaled — a HiDPI stream loses half its resolution. `virt-viewer` is GTK and
Wayland-native, which is why `headless connect` prefers it; `wlvncc` is better
still but only in the AUR. Keep `tigervnc` as the fallback unless you are sure
one of the others is always present.

## Autologin on tty1

Sway is started from `.zshrc-workstation` on tty1, which only runs after an
interactive login. There is no display manager and no autologin, so a machine
that reboots sits at a login prompt with no graphical session. `sshd` still
comes up, but nothing is being served and no remote desktop is reachable.

This matters specifically for the case headless mode exists to cover: a power
cut reboots the machine, and there is no monitor attached to log in on.

**Status: applied on the desktop (2026-08-09). Still needs mirroring into
arch-install so a rebuild reproduces it.**

Create `/etc/systemd/system/getty@tty1.service.d/autologin.conf`:

```ini
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --noreset --noclear --autologin <user> - ${TERM}
```

Then `systemctl daemon-reload`. On next boot tty1 logs in automatically, the
`.zshrc-workstation` block runs, and Sway starts unattended — after which
`headless on` can be triggered over SSH.

The flags mirror the stock `getty@.service` on Arch, which passes the tty as
`-` (taken from stdin) rather than `%I`. Generic examples online use `%I` and
also work, but matching the shipped unit avoids surprises across upgrades. The
empty `ExecStart=` is required: the directive is list-type, so without clearing
it systemd appends and refuses to start a unit with two commands.

Verify without rebooting — and do **not** test with
`systemctl restart getty@tty1`, since the running Sway session is a descendant
of that unit and would be killed:

```bash
systemctl show getty@tty1.service -p ExecStart --value   # exactly one entry
systemctl show getty@tty2.service -p ExecStart --value   # unchanged, no autologin
sudo systemd-analyze verify getty@tty1.service           # silent = clean
```

### Trade-off, and the lock-on-start requirement

Autologin means anyone with physical access to the machine gets a logged-in
session without a password.

**This machine has no full-disk encryption** — `/` and `/home` are both plain
ext4, and there are no LUKS volumes. So there is no passphrase gating boot, and
plain autologin would hand an unlocked desktop to anyone who powers the box on.
Physical data access is already possible by pulling the drive, but leaving a
live session open is a strictly worse exposure than that.

So autologin must be paired with locking the session immediately at start.
This is already in `workstation/sway/config.tpl` alongside the other `exec`
lines, and is deployed:

```
exec ~/.local/bin/lock
```

`exec` runs only at Sway startup, not on `swaymsg reload` (that would be
`exec_always`), so adding it never locks a session that is already running —
it takes effect at the next Sway start.

This costs nothing remotely: `swaymsg` IPC keeps working while locked, so
`headless on` can still be triggered over SSH, and wayvnc then serves the lock
screen, which you unlock by typing the password through the VNC session.

Recovery flow after a power cut reboots the machine:

1. Machine boots, tty1 autologins, Sway starts and locks itself
2. SSH in from the laptop
3. `headless on` — physical output off, wayvnc serving the locked session
4. `headless connect <host>` — unlock over VNC, session is yours

Only add the `exec` line together with the autologin drop-in. On its own it
would just lock the screen every time you start Sway normally.
