---
name: private-remote
description: Host a repository on the user's private git server instead of GitHub. TRIGGER when the user asks to push and no remote exists, asks to add or change a remote, or says "private git", "private remote", "my server", "self-hosted", or "not on GitHub". SKIP when the repo already has the remote the user is pushing to.
---

# Private remote

The user keeps some repositories on a personal git server rather than GitHub.
Its location is per machine and never written into a repo or a prompt: it is
the git config key `private.root`, in the form `<ssh-host>:<dir>`.

## Procedure

1. Check for the server:

   ```bash
   git config --get private.root
   ```

   Empty output means this machine has no private server. Say so and ask where
   the repo should live (GitHub, or set the key via `setup-github`). Do not
   guess a host.

2. When it is set, run the helper from the repo root. It creates the bare repo
   on the server over SSH, adds the remote, and pushes all branches and tags:

   ```bash
   git private            # remote = origin, name = directory name
   git private -n NAME    # different name on the server
   git private --no-push  # create repo and remote only
   ```

   If `origin` already points elsewhere (GitHub), the helper adds the server as
   `mirror` instead. Pass `-r NAME` to choose the remote name.

3. Report the remote URL it printed. Never print or persist the value of
   `private.root` anywhere that gets committed.

## When the user asks for GitHub

Nothing here applies. Use `gh repo create` as usual.
