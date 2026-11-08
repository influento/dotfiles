# lazygit — Terminal UI for git

gui:
  nerdFontsVersion: "3"
  showIcons: true
  border: rounded
  showBottomLine: false
  showCommandLog: false
  # Stack unstaged above staged so each diff gets the full width.
  mainPanelSplitMode: vertical
  theme:
    activeBorderColor:
      - "@@LAVENDER@@"  # Lavender
      - bold
    inactiveBorderColor:
      - "@@SURFACE1@@"  # Surface1
    searchingActiveBorderColor:
      - "@@YELLOW@@"  # Yellow
      - bold
    optionsTextColor:
      - "@@BLUE@@"  # Blue
    selectedLineBgColor:
      - "@@SURFACE0@@"  # Surface0
    cherryPickedCommitBgColor:
      - "@@SURFACE1@@"  # Surface1
    cherryPickedCommitFgColor:
      - "@@LAVENDER@@"  # Lavender
    markedBaseCommitBgColor:
      - "@@YELLOW@@"  # Yellow
    markedBaseCommitFgColor:
      - "@@BLUE@@"  # Blue
    unstagedChangesColor:
      - "@@RED@@"  # Red
    defaultFgColor:
      - "@@TEXT@@"  # Text

git:
  # delta's look comes from the [delta] section of ~/.gitconfig
  # (common/delta/). The link format makes file names and line numbers
  # clickable: lazygit opens them in nvim at that line.
  diffRenderers:
    - command: 'delta --dark --paging=never --hyperlinks-file-link-format="lazygit-edit://{path}:{line}"'
  autoFetch: true
  autoRefresh: true

os:
  editPreset: nvim
