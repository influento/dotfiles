# Common scripts

Deployed to `~/.local/bin/` on every profile; `*.md` is skipped, so this file
stays here. The rows in the root CLAUDE.md name each script. What follows is
what a reader cannot get from the code quickly enough.

## tmux-attention and claude-tmux

Two layers with one contract between them. `tmux-attention` is a tmux
extension: a pane can flag what it needs, and tmux renders, counts, finds and
announces it. `claude-tmux` is the Claude Code integration: hooks in, flags
out, plus the records that resume a conversation after a reboot. Neither knows
the other's internals; the seam is `tmux-attention set`.

### The attention model

| State | Meaning | Glyph |
| --- | --- | --- |
| `needs-you` | waiting on a decision: a permission, a question | `?` red |
| `done` | finished, nobody has looked yet | `✓` green |
| `working` | busy | `●` blue |
| unset | idle: seen, nothing pending | none |

State lives in tmux options and dies with the server: `@attention`,
`@attention_reason`, `@attention_at`, `@attention_owner` on the pane;
`@attention_win` on the
window, the highest-ranked pane's state, because a window-status format sees
only the active pane's options and a flagged pane may not be the active one;
`@attention_status` globally, the rendered counts that `status-right` reads
through `#{E:...}` so a change shows on the next `refresh-client -S`, not on
the next status-interval. Colours are read from `@attention_fg_*` options set
in `tmux.conf.tpl`, so the theme never leaves the template.

`set` prints the previous state only when the state changed, and nothing
otherwise; callers use that to write records on transitions alone.
`set --owner <cmd>` ties the flag to a process: `sweep` drops it once the
pane's foreground command is something else, which is what a crash, an OOM
kill or a closed terminal look like when no hook ran to clear it, and leaves
`@attention_gone` ("working · claude exited") for the picker to show. The
sweep runs inside `status`, `list` and `seen`, so any event anywhere, a
focus change included, clears a dead flag; there is no timer, because an
agent is legitimately silent for a long time. A flag set without an owner is
never swept. claude-tmux sets every flag with `--owner claude`.

`list`
joins fields with the unit separator, not tab: tab is IFS whitespace, so
`read` collapses an idle pane's empty fields and shifts every later column.

What the config wires (`common/tmux/tmux.conf.tpl`, "Attention"):

| Key or hook | Does |
| --- | --- |
| `prefix f` | fzf popup over every pane, flagged first; supersedes the old session-only switcher on the same key |
| `prefix o` | jump to the next pane that needs you, else the next unread done; a second press walks on |
| `pane-focus-in`, `after-select-window`, `after-select-pane` | `seen`: a focused `done` pane goes idle; sweeps dead flags first |
| `client-focus-in` | `status`: sweep and recount when the terminal regains focus |
| `after-split-window`, `after-kill-pane`, `pane-exited` | `borders`: `pane-border-status top` only while the window is split |

In `wb-*` sessions the window-list glyph is suppressed by the format itself
(`#{m:wb-*,#{session_name}}`) because workbench titles those windows, and
`claude-tmux` sets flags there `--quiet` because workbench already notifies.
The picker, jump and counts still include them.

Notifications go through `notify-send` when present, for `needs-you` and
`done` only, after a one-second settle that re-reads the state, and never for
the pane that is on screen in a focused client. Clicking one runs `jump
--pane`, which also focuses ghostty through swaymsg when there is a sway
socket. No sound, by decision.

### claude-tmux

`signal <event>` is what the hooks in `common/claude-code/settings.json` run;
the event table is in the script header. Only events whose state depends on
the payload parse the JSON (one python3 start, about 60 ms); `working` does
not, and costs a few milliseconds. Every subcommand is a silent no-op outside
tmux, so the same global settings are safe on a machine without it.

Records under `~/.local/state/claude-tmux/`, one per pane keyed
`session:window.pane`, hold the session id, transcript path, cwd and last
state. They are dropped on `SessionEnd` unless the reason is `other`. A kill
reports `other`, which is what a reboot looks like; so does a finished
`claude -p`, which is why a record alone never triggers a resume.

Outside `wb-*` sessions the Stop hook also names the window from the first
prompt — its first four words after any opener ("can you", "please"), at
most 28 characters — but only while the window still has tmux's automatic
name: a rename turns `automatic-rename` off, and that option is the whole
check, so a name the user set is never touched and a window named once is
never renamed again. The name is kept in the record, across a restore too,
and SessionEnd sets `automatic-rename` back on when the window still
carries it, so a window whose claude ended names itself again. Workbench
windows are titled by workbench.

`restore`, run by `tmux-attach` after tmux-resurrect has rebuilt the layout,
types `claude --resume <id>` into every recorded target that resurrect's
last save shows running `claude` (column 10 of its `pane` lines), that is
back as a plain shell in the recorded directory, and whose transcript is
still on disk; it moves the record to the pane id the target has on the new
server, marks it `restore=1`, and the `SessionStart` hook that follows
re-applies the flag.
What comes back is information, not a live prompt: a pending permission or
question is gone with the process, so the pane returns as `needs-you`
"before restart: …"; a turn cut mid-work returns as `needs-you` "interrupted
mid-turn"; an unread `done` stays `done`. Panes in `wb-*` sessions are left
to `workbench open`, which resumes with the worker's own flags. `claude` is
deliberately not in `@resurrect-processes`: resurrect would relaunch it bare
and lose the conversation.

## tmux-overlay

`tmux-overlay <name> <command...>`, bound as `prefix v` for nvim: a popup
showing a hidden session `ov-<name>-<session>` that runs the command, one per
outer session, created in the pane's directory on first use. The popup is a
nested client (`TMUX=` unset for the attach), which is what lets the same
prefix key inside it reach the script and detach that client, closing the
popup while the program lives on. `:q` ends the hidden session; the next
press starts fresh. tmux-resurrect restores hidden sessions as shells, so
one found running a shell is killed and recreated. `tmux-attention list`
skips `ov-*` sessions.

## claude-tmux platform facts

Platform facts this rests on, checked against the hooks reference:

- A hook inherits the process environment, so `$TMUX_PANE` names the pane.
- `PermissionRequest` with no output lets the prompt show; `signal` prints
  nothing on stdout.
- `SessionEnd` hooks share a 1.5 s budget.
- `SessionStart` fires on compaction too (`source: compact`); ignored.
