# Common scripts

Deployed to `~/.local/bin/` on every profile; `*.md` is skipped, so this file
stays here. The rows in the root CLAUDE.md name each script. What follows is
what a reader cannot get from the code quickly enough.

tmux-attention and claude-tmux moved to `influento/tmux-plugins` as tmux-agent
and tmux-revive, with their docs and tests; install.sh pins the release.

## tmux-overlay

`tmux-overlay -c <client> [-s session|repo] <name> <command...>`: a popup
showing a hidden session that runs the command. The popup is a nested client
(`TMUX=` unset for the attach). `run-shell` sets neither `$TMUX_PANE` nor a
client, and without them tmux answers with the last active client, so the
bindings pass `#{pane_id}` and `#{client_name}`.

| Key        | Program | Scope   | Hidden session                       |
| ---------- | ------- | ------- | ------------------------------------ |
| `prefix g` | lazygit | repo    | `ov-lazygit-<root>`                  |
| `prefix v` | nvim    | repo    | `ov-nvim-<root>`                     |
| `prefix t` | `$SHELL`| session | `ov-shell-<session>`                 |

Scope `repo`: one program per git repository, shared by every window of
every session, started in the repository's top folder. `<root>` is that
folder relative to `$HOME`, every character but letters, digits, `-` and `_`
turned into `_` (`dev_infra_dotfiles`),
so the name is the same on any machine with the same layout; that is what a
later sync of tmux between workstations needs. Window and pane IDs are
reassigned by every new server, so no scope uses them. Outside a repository
the pane's folder stands in for the root. Two folders with one name
(`a/b_c`, `a_b/c`) are told apart by the session option `@ov_root`: the
second gets a `-<cksum>` suffix. The name keeps to that set because tmux
expands `#` in a session name (`#S` becomes the session), turns `.` and `:`
into `_`, and the `ov-*` glob in `@skip_sessions` does not match across `/`.
For the same reason the start folder goes to `new-session -c` with `#`
doubled, messages go through `display-message -l`, and the popup gets the
socket and session from `-e` variables, not inside its command: a `'` in a
path ended the quoting there. Scope `session`
(the default): one per outer session, started in the pane's folder on the
first press; a shell drifts with `cd`, so a repo name would not describe it.

Refused with a message on the client, no popup:

- A pane that runs ssh (`pane_current_command` is `ssh`, or `@ssh_host` set
  by the zsh hook): tmux only knows the local folder the ssh started in, so
  the program would open on this machine while the pane shows another.
- A pane whose folder does not exist here.

Each press also kills hidden sessions with no client, idle (`session_activity`)
for `TMUX_OVERLAY_IDLE` seconds (default 43200, 12 hours), whose pane runs
only its own program. A shell with a job in the foreground, or a lazygit
that started an editor or a push, stays. A hidden session without
`@ov_root` (restored by tmux-revive, or from before the scopes) goes when
idle whatever it runs: its start command is empty, so the check above would
keep it forever. An nvim killed this way gets a
SIGHUP and leaves a swap file for unsaved buffers.

A popup never opens a second popup. The script gives each hidden session no
prefix and the key table `ov-root` (bound in `common/tmux/tmux.conf.tpl`):
inside the popup, prefix + `g`, `v` or `t` detaches the nested client, which
closes the popup while the program lives on, the prefix twice reaches the
program, and every other prefix key does nothing. Before this, a session
switch inside the popup (`prefix o`, `X`, `S`, `( )`, `w`) moved the nested
client to an outer session, and the next `prefix v` opened a popup inside the
popup. A new overlay key needs its own `detach-client` line in `ov-prefix`.

`:q` ends the hidden session; the next press starts fresh. tmux-revive up
to v0.3.0 saves hidden sessions like any other and restores one by typing
its program into a shell, so after `:q` the popup would sit at that shell.
So a session whose pane's start command is not the program is killed and
recreated on the next press. Later tmux-revive releases leave
`@skip_sessions` out of the save; the check stays for snapshots written
before.

The `ov-` prefix is also the `@skip_sessions` pattern in
`common/tmux/tmux.conf.tpl`, which tmux-agent's lists and tmux-revive's
attach skip: a change to one is a change to the other.
