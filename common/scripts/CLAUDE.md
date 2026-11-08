# Common scripts

Deployed to `~/.local/bin/` on every profile; `*.md` is skipped, so this file
stays here. The rows in the root CLAUDE.md name each script. What follows is
what a reader cannot get from the code quickly enough.

tmux-attention and claude-tmux moved to `influento/tmux-plugins` as tmux-agent
and tmux-revive, with their docs and tests; install.sh pins the release.

## tmux-overlay

`tmux-overlay -c <client> <name> <command...>`, bound as `prefix v` for nvim:
a popup showing a hidden session `ov-<name>-<session>` that runs the command,
one per outer session, created in the pane's directory on first use. The
popup is a nested client (`TMUX=` unset for the attach). `run-shell` sets
neither `$TMUX_PANE` nor a client, and without them tmux answers with the
last active client, so the binding passes `#{pane_id}` and `#{client_name}`.

A popup never opens a second popup. The script gives each hidden session no
prefix and the key table `ov-root` (bound in `common/tmux/tmux.conf.tpl`):
inside the popup, prefix + `v` detaches the nested client, which closes the
popup while the program lives on, the prefix twice reaches the program, and
every other prefix key does nothing. Before this, a session switch inside the
popup (`prefix o`, `X`, `S`, `( )`, `w`) moved the nested client to an outer
session, and the next `prefix v` opened a popup inside the popup. A second
overlay needs its key bound to `detach-client` in `ov-prefix` too.

`:q` ends the hidden session; the next press starts fresh. tmux-revive saves
hidden sessions like any other and restores one by typing its program into a
shell, so after `:q` the popup would sit at that shell. So a session whose
pane's start command is not the program is killed and recreated on the next
press.

The `ov-` prefix is also the `@skip_sessions` pattern in
`common/tmux/tmux.conf.tpl`, which tmux-agent's lists and tmux-revive's
attach skip: a change to one is a change to the other.
