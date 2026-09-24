---
name: tmux-peers
description: Work out which Claude session the user means when they refer to it by its tmux window. TRIGGER when the user refers to another Claude session by a window name, window number or tmux session ("the network session", "window 3", "the one in osxhelper"), or asks to message, check on, or hand work to another session. SKIP when the user gives the session's Claude name (`dotfiles-ce`) exactly as ListAgents prints it.
---

# tmux peers

The user names their tmux windows. Claude names each session after its folder
plus part of its id, so several sessions in one folder look alike
(`dotfiles-ea`, `dotfiles-ce`). The pane id links the two.

1. Get both lists:
   - `ListAgents`: each row ends with its pane, e.g. `tmux infra:@7.%13`.
   - Window names:

     ```bash
     tmux list-panes -a -F '#{pane_id} #{session_name}:#{window_index} #{window_name}'
     ```

2. Match rows on the pane id (`%13`). Compare the user's words with the window
   name, the window number and the tmux session name. Window names are often
   the first words of a prompt, so accept a partial or loose match: "the
   waybar one" fits `fix waybar tip`.
3. Address the session by the name its ListAgents row prints. Add ` [ref]` if
   two rows share that name.

A message goes to exactly one session. Send to more than one only when the
user names each of them or says "all" or "every session". A plural or general
word ("peers", "the others", "everyone") does not mean every session. Treat it
as a window name, and if no window has that name, ask. When in doubt, send
nothing: a missed message costs less than one that lands in every session.

Ask instead of guessing when:

- several sessions match (two claude panes in one window, or the words fit two
  windows). List each as `window → session`.
- nothing matches. Show the whole mapping.

This session is not in ListAgents. If the user's words match the window that
`$TMUX_PANE` is in, they mean this session: send no message and say so.
