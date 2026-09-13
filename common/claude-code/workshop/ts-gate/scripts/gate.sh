#!/usr/bin/env bash
# TS gate.
#   gate.sh [base-ref]   CI: files changed vs base-ref (default: the default branch)
#   gate.sh --local      branch work since the default branch plus the working tree, untracked included
#   gate.sh --list       the files --local would check, one per line, nothing else
set -uo pipefail
FAIL=0
# --local and --list: one line per problem, no colour, for the Stop hook and
# the worker. CI keeps the readable formats.
TSC_OPTS=(); ESLINT_OPTS=(); BIOME_OPTS=()
case "${1:-}" in --local|--list) TSC_OPTS=(--pretty false); ESLINT_OPTS=(--format ./ts-gate/eslint-line.mjs); BIOME_OPTS=(--reporter=summary) ;; esac
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "not a git repo, gate skipped"; exit 0; }

default_branch() {
  git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null && return
  local b; for b in main master; do git show-ref -q --verify "refs/heads/$b" && { echo "$b"; return; }; done
  echo HEAD
}

case "${1:-}" in
  --local|--list)
    # Merge base, not HEAD: a worker that commits as it goes has a clean tree at stop.
    RANGE=$(git merge-base HEAD "$(default_branch)" 2>/dev/null || echo HEAD)
    list_added() { { git diff --name-only --diff-filter=A "$RANGE"; git ls-files --others --exclude-standard; } | sort -u; }
    mapfile -t CHANGED < <({ git diff --name-only --diff-filter=ACMR "$RANGE"; git ls-files --others --exclude-standard; } | sort -u)
    mapfile -t FILES < <(printf '%s\n' "${CHANGED[@]}" | grep -E '\.tsx?$' | grep -vE '\.d\.ts$' || true) ;;
  *)
    RANGE="${1:-$(default_branch)}...HEAD"
    list_added() { git diff --name-only --diff-filter=A "$RANGE"; }
    mapfile -t FILES < <(git diff --name-only --diff-filter=ACMR "$RANGE" -- '*.ts' '*.tsx' | grep -vE '\.d\.ts$') ;;
esac

if [ "${1:-}" = "--list" ]; then [ ${#FILES[@]} -eq 0 ] || printf '%s\n' "${FILES[@]}"; exit 0; fi
# CI always runs the repo-wide tools: a branch that only edited tsconfig once
# merged green and broke tsc on main. --local, at every stop, skips only when
# nothing but code-irrelevant files changed.
if [ ${#FILES[@]} -eq 0 ]; then
  case "${1:-}" in
    --local)
      printf '%s\n' "${CHANGED[@]}" \
        | grep -qE '^(package(-lock)?\.json|tsconfig[^/]*\.json|biome\.jsonc?|eslint\.config\.[a-z]+|vitest?\.[a-z.]+|ts-gate/.*|\.dependency-cruiser\.cjs)$' \
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

# 2b. Layout, changed files only. Biome as formatter alone (its linter is off:
#     eslint above is the linter); `--reporter=summary` for the Stop hook, the diff
#     for CI. `gate:fix` rewrites.
[ ${#FILES[@]} -eq 0 ] || npx biome format --no-errors-on-unmatched "${BIOME_OPTS[@]}" "${FILES[@]}" || FAIL=1

# 3. Dead code / abandoned attempts. Repo-wide: an export dies when its last
#    *caller* is deleted, which need not be in the changed set.
npx knip --config ts-gate/knip.json || FAIL=1

# 4. Structure: cycles, barrel chains, layers. Repo-wide, zero tolerance.
npx depcruise --config ts-gate/.dependency-cruiser.cjs src || FAIL=1

# 5. Tests. Local: the tests the diff reaches (vitest --changed since the
#    merge base, working tree included). CI: the whole suite. Only vitest;
#    jest projects get the eslint plugin alone. Never the live tier.
if grep -q '"vitest"' package.json; then
  VITEST=(--passWithNoTests --exclude 'repos/**' --exclude '.worktrees/**' --exclude '**/*.live.test.*')
  case "${1:-}" in
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
