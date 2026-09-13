# workshop/ backlog

What is still to do on the tools themselves, one line each. Not project items:
workbench tracks projects, this tracks workbench, stack and ts-gate.

## workbench

- turn caps: set `maxTurns:` on `wb-reviewer` at twice the p95 turn count the first ten transcripts show; the worker already parks a partial return
- round-two rule yield: at twenty archived items, `grep '^rounds: r1 0/0'` over the archive; if round 2 rarely raises after an empty round 1, drop the second round. So far: 2026-09-13, nine `wb-worker` runs on seeded items, round 2 raised a finding that was fixed in 6/9, once after an empty round 1
- external resources ledger (port, container, temp dir a session starts outside the tree; `status` lists, `archive` reaps): design who writes it, hook or session, when the first leaked port or container is found after an archive

## stack

- effect pin: `REF`, `DEP` and `DEV_DEP` in `packages/effect` and the `@effect/*` lines in the `drizzle-*` packages and atom-react are `4.0.0-rc.115` (2026-09-12); one bump commit per RC worth taking, and the move to `4.0.0` when stable ships (Effect targets Q3/Q4 2026). `stack update effect` in each project after
- drizzle-orm pin, the same in all four `drizzle-*` packages, is a hash build (`1.0.0-rc.5-5935859`, the tagged rc.4 dies at import on Effect rc.115); move to the next tagged drizzle-orm release whose `devDependencies.effect` is at or past the stack's pin, and `drizzle-kit` with it
- the six files in `tanstack-start/rule.md` are described, not shipped (no templates, `stack/CLAUDE.md`); if the first real fullstack project retypes them wrong from the description, ship them under `packages/tanstack-start/files/` (the copy-once mechanism exists since `money`, 2026-09-13)

## ts-gate

- package boundaries: at the second top-level folder under `src/` in a real project, add four dependency-cruiser rules (about 30 lines, from mattpocock/skills `setup-ts-deep-modules`): a package's root files are its public surface, anything in a subfolder is private to it, tests reach a package only through its root files, `tests/` is reachable only from tests. Decided 2026-09-06: packages root is `src/` itself (every top-level folder is a package, no `src/packages/` move); entry files named after the folder (`src/wallet/wallet.ts`), never `index.ts`, so no clash with `no-barrel-chain`; Effect shape is Tag and Layer in the root file, implementation in `lib/`; `warn` first, `error` once clean; rule change in its own commit; no packages README, the config comment is the record. Why: makes interface hygiene countable where today it is reviewer judgment (ts-lean-code's one-consumer and pass-through rows), which is the gate's thesis and worth most to unattended workers

## delivery

- decided 2026-09-13, by hand and no forge: a private repo is a bare repo on the home server (`git private`), the premerge gate is the only CI, `npm run test:live` runs from the workstation with a gitignored `.env` and its output is pasted into the item, a release is `npm version <bump>` and `git push --follow-tags`, a deploy is a project-level `scripts/deploy` (ssh, checkout the tag under `~/srv/<name>`, `docker compose up --build`, base image from `engines.node`). Forgejo (v15 LTS was the pick) and a runner were dropped: one operator, no PRs, nothing a hook and a script do not do. Each automation below waits for its trigger, and each is one `ci` script on the server (`enable`, `run`, `live`, `deploy`, `status`, forwarded over ssh from the workstation) plus a `deploy` stack package extracted from the first project that wrote the files by hand:
  - CI on push (`post-receive` → `systemd-run --user ci run`, `gate:full` in a `node:<engines>` container): the day a merge lands green locally and breaks on the server, or a second machine pushes
  - live timer (daily, `flock`, `~/ci/<name>/live.env`): the day a live regression is found late because nobody ran the tier
  - `workbench release` (bump from the archive's item classes since the last tag: a feature is a minor, fixes a patch, major by hand): the day the bump is picked wrong twice, or two projects release in one week
  - `ci status` at sway start raising mako for red or stale: only once a timer exists to be stale

## later

Each waits for its trigger, named in the line.

- long-running projects: https://claude.com/blog/ai-ci-cd-on-call — the ladder incident → item → recurring pattern → investigation playbook → deterministic check, and the promotion loop that climbs it. Not before a project has an archive: the playbook earns itself at three items in one bug class, the watch tuning line at a check that fires on noise, the digest at a second reader, the rollout agent at feature flags. Build the promotion loop first, the rest hang off it
- gate deliver, deferred until a review reports a stray document from a session (never seen as of 2026-09-11): a `PreToolUse` hook — a deny JSON at exit 0 is honoured there — refusing the first `Write|Edit` to a `*.md` path inside the repo that does not exist and is outside `workbench/`, once per session (noclobber marker under `<git-common-dir>/workbench/gates/<session_id>/<agent_id>/`), with docs.md's decision order as the reason, read from between `<!-- gate:new-file -->` markers in the rendered skill. Markdown only: agent-kit's version (`~/dev/forks/agent-kit`, `gates.mjs`) fires on every new source file, which taxes every item that adds a module with a refusal about documentation. No `git` rule: `start` cuts the worktree, so a session's hand-run git has nothing to land on
- second reviewer from another model: once a second model CLI exists on the machine (`codex exec --full-auto` or equivalent), run it at the review dialog with the exact brief `wb-reviewer` gets, merge its findings into the reviewer's first message marked by source; one call per item, measure its cost over ten items before keeping it. The one signal the loop cannot produce today: worker and reviewer share a model family
