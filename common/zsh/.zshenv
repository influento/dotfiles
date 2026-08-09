# .zshenv — sourced by EVERY zsh invocation, including non-interactive ones
# such as `ssh host <command>` and scripts. Keep this file minimal: PATH only.
# Anything interactive (plugins, aliases, prompt) belongs in .zshrc.
#
# ~/.local/bin has to be added here and not only in .zshrc, because .zshrc is
# read for interactive shells only. Without this, `ssh <host> headless on`
# fails with "command not found", which would break remote control of headless
# mode — the exact path relied on to recover a machine with no monitor.
#
# The guard mirrors the one in .zshrc so the entry is never added twice.

if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  export PATH="$HOME/.local/bin:$PATH"
fi
