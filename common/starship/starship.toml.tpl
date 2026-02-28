# Starship prompt configuration
# Managed by dotfiles repo.
# Docs: https://starship.rs/config/

add_newline = true

# Two-line: info on top, prompt on bottom
format = """
$username$hostname$directory$git_branch$git_status$fill$docker_context$python$nodejs$rust$golang$lua$terraform$cmd_duration
$character"""

[fill]
symbol = " "

# Only shown in SSH sessions
[username]
show_always = false
format = "[$user]($style)@"
style_user = "bold @@SKY@@"

[hostname]
ssh_only = true
format = "[$hostname]($style) "
style = "bold @@SKY@@"

[directory]
style = "bold @@BLUE@@"
truncation_length = 4
truncate_to_repo = true
read_only = " 󰌾"
read_only_style = "@@RED@@"
home_symbol = "~"

[git_branch]
format = "[$symbol$branch(:$remote_branch)]($style) "
style = "@@MAUVE@@"
symbol = " "

[git_status]
format = '([$all_status$ahead_behind]($style) )'
style = "@@PEACH@@"
stashed = "󰏗 "
ahead = "⇡${count}"
behind = "⇣${count}"
diverged = "⇕⇡${ahead_count}⇣${behind_count}"
conflicted = " "
deleted = "✘ "
renamed = "󰑕 "
modified = " "
staged = "✓ "
untracked = " "

[docker_context]
format = "[$symbol$context]($style) "
symbol = "󰡨 "
style = "@@SKY@@"
only_with_files = true

[python]
format = "[$symbol$version( \\($virtualenv\\))]($style) "
symbol = " "
style = "@@GREEN@@"

[nodejs]
format = "[$symbol$version]($style) "
symbol = " "
style = "@@GREEN@@"

[rust]
format = "[$symbol$version]($style) "
symbol = " "
style = "@@GREEN@@"

[golang]
format = "[$symbol$version]($style) "
symbol = " "
style = "@@GREEN@@"

[lua]
format = "[$symbol$version]($style) "
symbol = " "
style = "@@GREEN@@"

[terraform]
format = "[$symbol$version]($style) "
symbol = "󱁢 "
style = "@@LAVENDER@@"

[cmd_duration]
format = "[$duration]($style) "
style = "@@YELLOW@@"
min_time = 2_000
show_notifications = false

[character]
success_symbol = "[❯](bold @@GREEN@@)"
error_symbol = "[❯](bold @@RED@@)"
