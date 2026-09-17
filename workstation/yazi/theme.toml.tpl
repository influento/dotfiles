# vim:fileencoding=utf-8:foldmethod=marker
# Yazi theme, rendered from the active palette by lib/theme.sh.
# The layout is the upstream yazi-rs/flavors catppuccin-mocha flavor.toml, used
# directly as the theme with every palette color a token, so it follows
# theme.conf. No [flavor] section: yazi 26 did not pick up a flavor from
# flavors/<name>.yazi/ in testing, while theme.toml itself always applies.

# : Manager {{{

[mgr]
cwd = { fg = "@@TEAL@@" }

# Find
find_keyword  = { fg = "@@YELLOW@@", bold = true, italic = true, underline = true }
find_position = { fg = "@@PINK@@", bg = "reset", bold = true, italic = true }

# Marker
marker_copied   = { fg = "@@GREEN@@", bg = "@@GREEN@@" }
marker_cut      = { fg = "@@RED@@", bg = "@@RED@@" }
marker_marked   = { fg = "@@TEAL@@", bg = "@@TEAL@@" }
marker_selected = { fg = "@@YELLOW@@", bg = "@@YELLOW@@" }

# Count
count_copied   = { fg = "@@BASE@@", bg = "@@GREEN@@" }
count_cut      = { fg = "@@BASE@@", bg = "@@RED@@" }
count_selected = { fg = "@@BASE@@", bg = "@@YELLOW@@" }

# Border
border_symbol = "│"
border_style  = { fg = "@@OVERLAY1@@" }

# : }}}


# : Tabs {{{

[tabs]
active   = { fg = "@@BASE@@", bg = "@@BLUE@@", bold = true }
inactive = { fg = "@@BLUE@@", bg = "@@SURFACE0@@" }

# : }}}


# : Mode {{{

[mode]

normal_main = { fg = "@@BASE@@", bg = "@@BLUE@@", bold = true }
normal_alt  = { fg = "@@BLUE@@", bg = "@@SURFACE0@@" }

# Select mode
select_main = { fg = "@@BASE@@", bg = "@@TEAL@@", bold = true }
select_alt  = { fg = "@@TEAL@@", bg = "@@SURFACE0@@" }

# Unset mode
unset_main = { fg = "@@BASE@@", bg = "@@FLAMINGO@@", bold = true }
unset_alt  = { fg = "@@FLAMINGO@@", bg = "@@SURFACE0@@" }

# : }}}


# : Status bar {{{

[status]
# Permissions
perm_sep   = { fg = "@@OVERLAY1@@" }
perm_type  = { fg = "@@BLUE@@" }
perm_read  = { fg = "@@YELLOW@@" }
perm_write = { fg = "@@RED@@" }
perm_exec  = { fg = "@@GREEN@@" }

# Progress
progress_label  = { fg = "#ffffff", bold = true }
progress_normal = { fg = "@@GREEN@@", bg = "@@SURFACE1@@" }
progress_error  = { fg = "@@YELLOW@@", bg = "@@RED@@" }

# : }}}


# : Pick {{{

[pick]
border   = { fg = "@@BLUE@@" }
active   = { fg = "@@PINK@@", bold = true }
inactive = {}

# : }}}


# : Input {{{

[input]
border   = { fg = "@@BLUE@@" }
title    = {}
value    = {}
selected = { reversed = true }

# : }}}


# : Completion {{{

[cmp]
border = { fg = "@@BLUE@@" }

# : }}}


# : Tasks {{{

[tasks]
border  = { fg = "@@BLUE@@" }
title   = {}
hovered = { fg = "@@PINK@@", bold = true }

# : }}}


# : Which {{{

[which]
border          = { fg = "@@BLUE@@" }
cand            = { fg = "@@TEAL@@" }
rest            = { fg = "@@OVERLAY2@@" }
desc            = { fg = "@@PINK@@" }
separator       = "  "
separator_style = { fg = "@@SURFACE2@@" }

# : }}}


# : Help {{{

[help]
on      = { fg = "@@TEAL@@" }
run     = { fg = "@@PINK@@" }
hovered = { reversed = true, bold = true }
footer  = { fg = "@@SURFACE0@@", bg = "@@TEXT@@" }

# : }}}


# : Spotter {{{

[spot]
border   = { fg = "@@BLUE@@" }
title    = { fg = "@@BLUE@@" }
tbl_col  = { fg = "@@TEAL@@" }
tbl_cell = { fg = "@@PINK@@", bg = "@@SURFACE1@@" }

# : }}}


# : Notification {{{

[notify]
title_info  = { fg = "@@GREEN@@" }
title_warn  = { fg = "@@YELLOW@@" }
title_error = { fg = "@@RED@@" }

# : }}}


# : File-specific styles {{{

[filetype]

rules = [
	# Image
	{ mime = "**/image/*", fg = "@@TEAL@@" },
	# Media
	{ mime = "**/{audio,video}/*", fg = "@@YELLOW@@" },
	# Archive
	{ mime = "**/application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}", fg = "@@PINK@@" },
	# Document
	{ mime = "**/application/{pdf,doc,rtf}", fg = "@@GREEN@@" },
	# Virtual file system
	{ mime = "vfs/{absent,stale}", fg = "@@OVERLAY2@@" },
	# Fallback
	{ url = "*", fg = "@@TEXT@@" },
	{ url = "*/", fg = "@@BLUE@@" },
]

# : }}}

[icon]

dirs = [
	{ name = ".config", text = "", fg = "@@PINK@@" },
	{ name = ".git", text = "", fg = "@@TEAL@@" },
	{ name = ".github", text = "", fg = "@@BLUE@@" },
	{ name = ".npm", text = "", fg = "@@BLUE@@" },
	{ name = "Desktop", text = "", fg = "@@TEAL@@" },
	{ name = "Development", text = "", fg = "@@TEAL@@" },
	{ name = "Documents", text = "", fg = "@@TEAL@@" },
	{ name = "Downloads", text = "", fg = "@@TEAL@@" },
	{ name = "Library", text = "", fg = "@@TEAL@@" },
	{ name = "Movies", text = "", fg = "@@TEAL@@" },
	{ name = "Music", text = "", fg = "@@TEAL@@" },
	{ name = "Pictures", text = "", fg = "@@TEAL@@" },
	{ name = "Public", text = "", fg = "@@TEAL@@" },
	{ name = "Videos", text = "", fg = "@@TEAL@@" },
]
conds = [
	# Special files
	{ if = "orphan", text = "", fg = "@@TEXT@@" },
	{ if = "link", text = "", fg = "@@OVERLAY1@@" },
	{ if = "block", text = "", fg = "@@FLAMINGO@@" },
	{ if = "char", text = "", fg = "@@FLAMINGO@@" },
	{ if = "fifo", text = "", fg = "@@FLAMINGO@@" },
	{ if = "sock", text = "", fg = "@@FLAMINGO@@" },
	{ if = "sticky", text = "", fg = "@@FLAMINGO@@" },
	{ if = "dummy", text = "", fg = "@@RED@@" },

	# Fallback
	{ if = "dir & hovered", text = "", fg = "@@BLUE@@" },
	{ if = "dir", text = "", fg = "@@BLUE@@" },
	{ if = "exec", text = "", fg = "@@GREEN@@" },
	{ if = "!dir", text = "", fg = "@@TEXT@@" },
]
