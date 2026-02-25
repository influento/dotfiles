# lazygit — Terminal UI for git

gui:
  nerdFontsVersion: "3"
  showIcons: true
  border: rounded
  showBottomLine: false
  showCommandLog: false
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
  paging:
    pager: delta --dark --paging=never
  autoFetch: true
  autoRefresh: true

os:
  editPreset: nvim
