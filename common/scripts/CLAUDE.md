# Common scripts

Deployed to `~/.local/bin/` on every profile; `*.md` is skipped, so this file
stays here. Each script's header comment says what it does and why; this file
holds only what spans files or repos, and decisions not to undo.

## tmux-overlay

How it works is in the comments of `tmux-overlay` and of its bindings in
`common/tmux/tmux.conf.tpl`. The user chose these behaviours. Keep them:

- **Names from the folder, not from tmux IDs.** A repo session is named after
  its repository's folder relative to `$HOME`, so the name is the same on any
  machine with the same layout; a later sync of tmux between workstations needs
  that. Window and pane IDs change with every new server, so no scope uses them.
- **The shell popup is a scratch space.** It ends with its popup, together with
  whatever runs in it; a long job belongs in a window.
- **The pane behind the popup picks the repository.** A `cd` inside the popup
  picks nothing: the popup is not a place to work from.
- **One terminal per hidden session, and a press takes it over.** With two
  clients attached, keys from both would reach the program and
  `window-size latest` would resize it to whichever typed last. A press takes
  over and does not refuse, because a popup left open on an unattended machine
  would block every other one.
- **A repo session lives while something owns it, not for a time.** Sleep,
  hibernate and a clock jump change nothing; a power-off ends them all.
  Accepted limits: a pane in a worktree or submodule also keeps the outer
  repository's session; a `cd` away is seen only at the next press or closed
  session, because nothing hooks it.
- **Only a typed `ssh` is refused.** mosh, et or ssh under a wrapper script are
  not detected; none is in use.

Contracts with other files:

- The `ov-` prefix is also the `@skip_sessions` pattern in
  `common/tmux/tmux.conf.tpl`, which tmux-agent's lists and tmux-revive's
  attach skip. A change to one is a change to the other.
- tmux-revive from v0.3.1 does not save `@skip_sessions`. The check that
  recreates a session whose pane's start command is not the program stays for
  snapshots that older versions wrote.
- A new overlay needs, in `common/tmux/tmux.conf.tpl`, a `%hidden` command
  variable, a root binding and an `ov-prefix` binding.
