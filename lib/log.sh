#!/usr/bin/env bash
# lib/log.sh — Lightweight logging for dotfiles installer

readonly _CLR_RESET='\033[0m'
readonly _CLR_RED='\033[1;31m'
readonly _CLR_GREEN='\033[1;32m'
readonly _CLR_YELLOW='\033[1;33m'
readonly _CLR_CYAN='\033[1;36m'
readonly _CLR_BOLD='\033[1m'
readonly _CLR_DIM='\033[2m'

log_info() {
  printf '%b[INFO]%b  %s\n' "$_CLR_GREEN" "$_CLR_RESET" "$*" >&2
}

log_warn() {
  printf '%b[WARN]%b  %s\n' "$_CLR_YELLOW" "$_CLR_RESET" "$*" >&2
}

log_error() {
  printf '%b[ERROR]%b %s\n' "$_CLR_RED" "$_CLR_RESET" "$*" >&2
}

log_section() {
  local title="$1"
  printf '\n%b%b%s%b\n' "$_CLR_CYAN" "$_CLR_BOLD" "=== $title ===" "$_CLR_RESET" >&2
}

die() {
  log_error "$@"
  exit 1
}
