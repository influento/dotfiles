# delta — the diff viewer behind lazygit and git's pager.
# Rendered from the active palette by lib/theme.sh, included by ~/.gitconfig.
# Only settings that differ from delta's defaults are listed.

[core]
    # delta where it is installed (workstation), less where it is not (servers).
    # --navigate (n / N jump between files) only here: in lazygit it would add
    # a marker to every hunk header and lazygit has its own scrolling.
    pager = "if command -v delta >/dev/null 2>&1; then delta --navigate; else less; fi"

[delta]
    dark = true
    syntax-theme = @@SYNTAX_THEME@@
    hyperlinks = true
    tabs = 4

    # Changed lines: the palette's green and red blended into the background
    plus-style = "syntax @@MIX_GREEN_16@@"
    plus-emph-style = "syntax @@MIX_GREEN_34@@"
    minus-style = "normal @@MIX_RED_16@@"
    minus-emph-style = "normal @@MIX_RED_34@@"
    plus-empty-line-marker-style = "normal @@MIX_GREEN_16@@"
    minus-empty-line-marker-style = "normal @@MIX_RED_16@@"
    whitespace-error-style = "reverse @@PINK@@"

    # Gutter: the line number in the new file only
    line-numbers = true
    line-numbers-left-format = ""
    line-numbers-right-format = "{np:>4} │ "
    line-numbers-plus-style = "@@GREEN@@"
    line-numbers-minus-style = "@@RED@@"
    line-numbers-zero-style = "@@OVERLAY0@@"
    line-numbers-right-style = "@@SURFACE2@@"

    # Headers
    file-style = "@@LAVENDER@@ bold"
    file-decoration-style = "@@SURFACE2@@ ol ul"
    hunk-header-style = "line-number syntax italic"
    hunk-header-decoration-style = none
    hunk-header-line-number-style = "@@OVERLAY1@@"
    merge-conflict-ours-diff-header-decoration-style = "@@SURFACE2@@ ul"
    merge-conflict-theirs-diff-header-decoration-style = "@@SURFACE2@@ ul"

    # git blame
    blame-palette = "@@MANTLE@@ @@SURFACE0@@"
    blame-format = "{commit:<8} {author:<10.9} {timestamp:<14}"
    blame-timestamp-output-format = "%Y-%m-%d"
