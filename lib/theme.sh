#!/usr/bin/env bash
# lib/theme.sh — Theme rendering engine
# Renders .tpl template files by replacing @@TOKEN@@ and @@TOKEN_RAW@@
# placeholders with colors from the active theme palette.

# Load a theme palette by name.
# Sources themes/<name>.sh and validates THEME_COLORS is populated.
# Usage: load_theme "catppuccin-mocha"
load_theme() {
  local theme_name="$1"
  local theme_file="${DOTFILES_DIR}/themes/${theme_name}.sh"

  if [[ ! -f "$theme_file" ]]; then
    die "Theme file not found: $theme_file"
  fi

  # shellcheck source=/dev/null
  source "$theme_file"

  if [[ ${#THEME_COLORS[@]} -eq 0 ]]; then
    die "Theme '${theme_name}' defines no colors (THEME_COLORS is empty)."
  fi

  log_info "Loaded theme: ${THEME_META[DISPLAY_NAME]:-$theme_name} (${#THEME_COLORS[@]} colors)"
}

# Build a sed script that replaces all @@TOKEN_RAW@@ and @@TOKEN@@ placeholders.
# _RAW variants (bare hex) are placed first to prevent partial matches.
# Result is stored in the global variable SED_SCRIPT.
# Usage: build_sed_script
build_sed_script() {
  SED_SCRIPT=""

  # _RAW replacements first (bare hex, no hash prefix)
  local key
  for key in "${!THEME_COLORS[@]}"; do
    SED_SCRIPT+="s|@@${key}_RAW@@|${THEME_COLORS[$key]}|g;"
  done
  for key in "${!THEME_META[@]}"; do
    SED_SCRIPT+="s|@@${key}_RAW@@|${THEME_META[$key]}|g;"
  done

  # Hash-prefixed replacements second
  for key in "${!THEME_COLORS[@]}"; do
    SED_SCRIPT+="s|@@${key}@@|#${THEME_COLORS[$key]}|g;"
  done

  # Meta values (no hash prefix — these are names, not colors)
  for key in "${!THEME_META[@]}"; do
    SED_SCRIPT+="s|@@${key}@@|${THEME_META[$key]}|g;"
  done
}

# Render all .tpl template files under the given directory.
# Each template is processed with sed using the current SED_SCRIPT,
# and the output is written to the same path minus the .tpl extension.
# Usage: render_templates "/path/to/common" "common"
render_templates() {
  local search_dir="$1"
  local label="$2"
  local count=0

  if [[ ! -d "$search_dir" ]]; then
    return 0
  fi

  while IFS= read -r -d '' tpl; do
    local output="${tpl%.tpl}"
    sed "$SED_SCRIPT" "$tpl" > "$output"
    count=$((count + 1))
  done < <(find "$search_dir" -name '*.tpl' -print0)

  if [[ $count -gt 0 ]]; then
    log_info "Rendered ${count} ${label} template(s)"
  fi
}

# Check generated files for leftover @@...@@ tokens that were not replaced.
# Warns for each file containing unreplaced tokens.
# Usage: validate_rendered "/path/to/common"
validate_rendered() {
  local search_dir="$1"

  if [[ ! -d "$search_dir" ]]; then
    return 0
  fi

  while IFS= read -r -d '' tpl; do
    local output="${tpl%.tpl}"
    if [[ -f "$output" ]] && grep -qE '@@[A-Z_]+@@' "$output"; then
      local tokens
      tokens="$(grep -oE '@@[A-Z_]+@@' "$output" | sort -u | tr '\n' ' ')"
      log_warn "Unreplaced tokens in ${output}: ${tokens}"
    fi
  done < <(find "$search_dir" -name '*.tpl' -print0)

  return 0
}
