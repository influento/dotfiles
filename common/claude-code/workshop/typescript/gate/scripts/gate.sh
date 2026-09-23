#!/usr/bin/env bash
# TS gate.
#   gate.sh              CI: files changed since the default branch
#   gate.sh --local      branch work since the default branch plus the working tree, untracked included
#   gate.sh --list       the files --local would check, one per line, nothing else
set -uo pipefail
FAIL=0
# --local and --list: one line per problem, no colour, for the Stop hook and
# the worker. CI keeps the readable formats.
MODE="${1:-}"; LOCAL=""
case "$MODE" in --local|--list) LOCAL=1 ;; esac
TSC_OPTS=(); ESLINT_OPTS=(); BIOME_OPTS=()
[ -z "$LOCAL" ] || { TSC_OPTS=(--pretty false); ESLINT_OPTS=(--format ./ts-gate/eslint-line.mjs); BIOME_OPTS=(--reporter=summary); }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "not a git repo, gate skipped"; exit 0; }

default_branch() {
  git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null && return
  local b; for b in main master; do git show-ref -q --verify "refs/heads/$b" && { echo "$b"; return; }; done
  echo HEAD
}

# Declarations, and workbench/: a spike's prototypes live in its folder there
# and are never the project's code.
NOT_CODE='\.d\.ts$|^workbench/'
untracked() { [ -z "$LOCAL" ] || git ls-files --others --exclude-standard; }
if [ -n "$LOCAL" ]; then
  # Merge base, not HEAD: a worker that commits as it goes has a clean tree at stop.
  RANGE=$(git merge-base HEAD "$(default_branch)" 2>/dev/null || echo HEAD)
  mapfile -t CHANGED < <({ git diff --name-only --diff-filter=ACMR "$RANGE"; untracked; } | sort -u)
  mapfile -t FILES < <(printf '%s\n' "${CHANGED[@]}" | grep -E '\.tsx?$' | grep -vE "$NOT_CODE" || true)
else
  RANGE="$(default_branch)...HEAD"
  mapfile -t FILES < <(git diff --name-only --diff-filter=ACMR "$RANGE" -- '*.ts' '*.tsx' | grep -vE "$NOT_CODE")
fi
list_added() { { git diff --name-only --diff-filter=A "$RANGE"; untracked; } | sort -u; }

if [ "$MODE" = "--list" ]; then [ ${#FILES[@]} -eq 0 ] || printf '%s\n' "${FILES[@]}"; exit 0; fi
# CI always runs the repo-wide tools: a tsconfig-only change can break tsc.
# --local, at every stop, skips only when nothing but code-irrelevant files
# changed.
if [ ${#FILES[@]} -eq 0 ]; then
  case "$MODE" in
    --local)
      printf '%s\n' "${CHANGED[@]}" \
        | grep -qE '^(package(-lock)?\.json|tsconfig[^/]*\.json|biome\.jsonc?|eslint\.config\.[a-z]+|\.claude/eslint/.*|vitest?\.[a-z.]+|ts-gate/.*|\.dependency-cruiser\.cjs)$' \
        || { echo "no TS or config changes"; exit 0; } ;;
  esac
  echo "== no changed TS files; repo-wide checks only =="
fi
[ -d node_modules ] || { echo "node_modules missing (fresh checkout or worktree): run npm ci, then retry"; exit 1; }
[ ${#FILES[@]} -eq 0 ] || echo "== ${#FILES[@]} changed TS files =="

# 1. Compile. Repo-wide: a wrong API name in a changed file fails here, not at build.
npx tsc --noEmit "${TSC_OPTS[@]}" || FAIL=1

# 2. Volume lint, changed files only. Type-aware rules are per-file with full
#    type info, so scoping to the diff is exact, not an approximation.
[ ${#FILES[@]} -eq 0 ] || npx eslint "${ESLINT_OPTS[@]}" "${FILES[@]}" || FAIL=1

# 2b. Layout, changed files only.
[ ${#FILES[@]} -eq 0 ] || npx biome format --no-errors-on-unmatched "${BIOME_OPTS[@]}" "${FILES[@]}" || FAIL=1

# 3. Dead code / abandoned attempts. Repo-wide: an export dies when its last
#    *caller* is deleted, which need not be in the changed set.
npx knip --config ts-gate/knip.json || FAIL=1

# 4. Structure: cycles, barrel chains, layers. Repo-wide, zero tolerance.
npx depcruise --config ts-gate/.dependency-cruiser.cjs src || FAIL=1

# 5. Tests: vitest only; jest projects get the eslint plugin alone.
if grep -q '"vitest"' package.json; then
  VITEST=(--passWithNoTests --exclude 'repos/**' --exclude '.worktrees/**' --exclude 'workbench/**' --exclude '**/*.live.test.*')
  case "$MODE" in
    --local) npx vitest run --changed "$RANGE" --reporter=dot --no-color "${VITEST[@]}" || FAIL=1 ;;
    *)       npx vitest run "${VITEST[@]}" || FAIL=1 ;;
  esac
fi

# 6. Diff size and new files. REPORT ONLY — the reader decides.
echo "== diff size =="
git diff --shortstat "$RANGE"
echo "== files added =="
list_added

exit $FAIL
