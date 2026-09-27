---
name: tmux-peers
description: Resolve which Claude session the user means before messaging one. TRIGGER on any request to send, message, tell, ask, ping, check on, or hand work to another session or agent ("send X to Y agent", "tell the dotfiles session ...", "window 3"), whatever name the user uses: a tmux window name wins over a Claude session name that looks like it. SKIP only when the user types a full Claude name with its suffix (`dotfiles-e8`).
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
3. Match in this order and stop at the first level that matches: window
   name (exact, then loose), window number, tmux session name, Claude name.
   A folder word such as "dotfiles" often fits both a window and several
   Claude names (`dotfiles-e8`, `dotfiles-d1`): the window wins, and the
   sessions outside it are not candidates. One match: send, don't ask.
4. Address the session by the name its ListAgents row prints. Add ` [ref]` if
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
