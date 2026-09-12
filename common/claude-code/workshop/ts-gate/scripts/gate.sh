#!/usr/bin/env bash
# TS gate.
#   gate.sh [base-ref]   CI: files changed vs base-ref (default: the default branch)
#   gate.sh --local      branch work since the default branch plus the working tree, untracked included
#   gate.sh --list       the files --local would check, one per line, nothing else
set -uo pipefail
FAIL=0
# --local is what the Stop hook and the worker read back into context: one line
# per problem and no colour, so the same findings cost a fraction of the tokens.
# CI keeps the readable formats.
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
    mapfile -t FILES < <({ git diff --name-only --diff-filter=ACMR "$RANGE"; git ls-files --others --exclude-standard; } \
      | grep -E '\.tsx?$' | grep -vE '\.d\.ts$' | sort -u) ;;
  *)
    RANGE="${1:-$(default_branch)}...HEAD"
    list_added() { git diff --name-only --diff-filter=A "$RANGE"; }
    mapfile -t FILES < <(git diff --name-only --diff-filter=ACMR "$RANGE" -- '*.ts' '*.tsx' | grep -vE '\.d\.ts$') ;;
esac

if [ "${1:-}" = "--list" ]; then [ ${#FILES[@]} -eq 0 ] || printf '%s\n' "${FILES[@]}"; exit 0; fi
if [ ${#FILES[@]} -eq 0 ]; then echo "no TS changes"; exit 0; fi
[ -d node_modules ] || { echo "node_modules missing (fresh checkout or worktree): run npm ci, then retry"; exit 1; }
echo "== ${#FILES[@]} changed TS files =="

# 1. Compile. Repo-wide: a wrong API name in a changed file fails here, not at build.
npx tsc --noEmit "${TSC_OPTS[@]}" || FAIL=1

# 2. Volume lint, changed files only. Type-aware rules are per-file with full
#    type info, so scoping to the diff is exact, not an approximation.
npx eslint "${ESLINT_OPTS[@]}" "${FILES[@]}" || FAIL=1

# 2b. Layout, changed files only. Biome as formatter alone (its linter is off:
#     eslint above is the linter); `--reporter=summary` for the hook, the diff
#     for CI. `gate:fix` rewrites.
npx biome format --no-errors-on-unmatched "${BIOME_OPTS[@]}" "${FILES[@]}" || FAIL=1

# 3. Dead code / abandoned attempts. Repo-wide: an export dies when its last
#    *caller* is deleted, which need not be in the changed set.
npx knip --config ts-gate/knip.json || FAIL=1

# 4. Structure: cycles, barrel chains, layers. Repo-wide, zero tolerance.
npx depcruise --config ts-gate/.dependency-cruiser.cjs src || FAIL=1

# 5. Tests. Local: only the tests the diff reaches, by import graph
#    (vitest --changed since the merge base, working tree included), so the
#    Stop hook pays for what the change touched. CI: the whole suite. Only
#    for a runner the gate knows; jest projects get the eslint plugin alone.
#    Never the live tier (*.live.test.ts: real network, `npm run test:live`).
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
