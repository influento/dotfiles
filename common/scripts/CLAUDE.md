# Common scripts

Deployed to `~/.local/bin/` on every profile; `*.md` is skipped, so this file
stays here. The rows in the root CLAUDE.md name each script. What follows is
what a reader cannot get from the code quickly enough.

tmux-attention and claude-tmux moved to `influento/tmux-plugins` as tmux-agent
and tmux-revive, with their docs and tests; install.sh pins the release.

## tmux-overlay

`tmux-overlay -c <client> [-s session|repo] <name> <command...>`: a popup
showing a hidden session that runs the command. `tmux-overlay --reap` only
cleans up (below). The popup is a nested client
(`TMUX=` unset for the attach). `run-shell` sets neither `$TMUX_PANE` nor a
client, and without them tmux answers with the last active client, so the
bindings pass `#{pane_id}` and `#{client_name}`.

| Key        | Program | Scope   | Hidden session                       |
| ---------- | ------- | ------- | ------------------------------------ |
| `prefix g` | lazygit | repo    | `ov-lazygit-<root>`                  |
| `prefix v` | nvim    | repo    | `ov-nvim-<root>`                     |
| `prefix t` | `$SHELL`| session | `ov-shell-<session>`, `@ov_owner` its id |

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
It is found by `@ov_owner`, the outer session's id, so a rename keeps it;
the name is only the session's name at the first press. A new session with
the name of a gone one whose shell is still at work gets `-<id>` added.

The pane's folder at the moment of the press picks the repository: open
lazygit, hide it, `cd` to another repository, press again, and that one's
lazygit opens. The first one stays while a pane is in its repository.

One terminal shows a hidden session at a time. The popup attaches with
`attach -d`, which detaches the session's other clients, so with two
terminals on one server (two workstations on a shared one) the press from
the second takes it over and the first one's popup closes; the program and
its state do not notice. Before, both popups attached, keys from both
reached it and `window-size latest` resized it to whichever typed last.
The attach sets `@ov_viewer` (the outer client) in the same command list,
so even two presses at once leave it naming the client that attached last.
A popup whose attach ends with another client in `@ov_viewer` was taken
over and says `<name> for <where> moved to another terminal`; one hidden or
quit says nothing. Taking over and not refusing: a popup left open on an
unattended machine would block every other one.

Refused with a message on the client, no popup:

- A pane that runs ssh (`pane_current_command` is `ssh`, or `@ssh_host` set
  by the zsh hook): tmux only knows the local folder the ssh started in, so
  the program would open on this machine while the pane shows another.
- A pane whose folder does not exist here.

A hidden session lives while something owns it, not for a time. Each
press, and `--reap` from the `session-closed[0]` hook in
`common/tmux/tmux.conf.tpl`, kills the ones that are:

- not owned: a repo one when no pane outside the `ov-*` sessions has its
  `pane_current_path` at `@ov_root` or below; a session one when the session
  `@ov_owner` names is gone. The folder match is by name, so a pane in a
  worktree or submodule inside a repository also keeps the outer one;
  that only errs toward keeping. A `cd` away is seen at the next press or
  closed session, nothing hooks it.
- not on screen (`session_attached` 0);
- not at work: the pane's foreground command is its own program and it has
  no child process (a shell's background job, lazygit's git or editor),
  and for nvim, asked over its socket, no unsaved buffer and no running
  `:terminal` job. nvim 0.12 listens on `nvim.<pid>.0` of its server
  process, a child of the one the pane started, under `$XDG_RUNTIME_DIR`;
  no socket, or no answer within 2 seconds (a `:!` command blocks it),
  counts as work. A changed buffer is the `changed` field of `getbufinfo()`:
  its `bufmodified` filter also counted a fresh scratch buffer.

One kept for its work goes at the first press or closed session after the
work ends. One without `@ov_root` (restored by tmux-revive, or from before
the scopes) goes whatever it runs: its program was typed into a shell.
Nothing depends on time, so sleep, hibernate and a clock jump change
nothing; a power-off ends them all, and tmux-revive after v0.3.0 does not save
them.
The options that say what a session is (`@ov_root`, `@ov_scope`, `@ov_name`,
`@ov_owner`) are set in the `new-session` command list, so a `--reap` never
sees one without them; two presses at once make one session.

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
