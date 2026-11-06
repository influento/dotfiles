# Common scripts

Deployed to `~/.local/bin/` on every profile; `*.md` is skipped, so this file
stays here. The rows in the root CLAUDE.md name each script. What follows is
what a reader cannot get from the code quickly enough.

tmux-attention and claude-tmux moved to `influento/tmux-plugins` as tmux-agent
and tmux-revive, with their docs and tests; install.sh pins the release.

## tmux-overlay

`tmux-overlay <name> <command...>`, bound as `prefix v` for nvim: a popup
showing a hidden session `ov-<name>-<session>` that runs the command, one per
outer session, created in the pane's directory on first use. The popup is a
nested client (`TMUX=` unset for the attach), which is what lets the same
prefix key inside it reach the script and detach that client, closing the
popup while the program lives on. `:q` ends the hidden session; the next
press starts fresh. tmux-revive saves hidden sessions like any other and
restores one by typing its program into a shell, so a restored session
lacks the options the script sets and sits at that shell after `:q`. So a
session whose pane's start command is not the program is killed and
recreated on the next press. The `ov-` prefix is also the `@skip_sessions`
pattern in `common/tmux/tmux.conf.tpl`, which tmux-agent's lists and
tmux-revive's attach skip: a change to one is a change to the other.
