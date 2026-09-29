---
name: show-me
description: Help the user understand the current topic visually with concise diagrams, code-shape sketches, and focused HTML pages. TRIGGER when the user says "show me", "draw", "diagram", "visualize", "what does X look like", or invokes /show-me. SKIP when the answer is a single fact, a one-line lookup, or a code fix. For charts of numeric data use dataviz instead; for a UI mockup the user will refine by hand, use design instead; for code that answers a design question by being run, use prototype instead.
---

Help the user understand the current topic of conversation visually. Skip the preamble and keep prose brief. Pick the smallest view that makes the key point clear.

Prefer the plain-text views below — they render in every surface. Reach for the HTML page only when text cannot carry the point.

- Show logic or an algorithm as pseudocode:

```text
on(save)
  if content is unchanged
    return cached result
  write new content
  return fresh result
```

- Show runtime control flow as a call tree:

```text
submitForm
  createSession
    persistPrompt
    launchAgent
  navigateToSession
```

- Show UI structure as a component tree, including state and module boundaries that matter:

```tsx
<SessionPage> (apps/example/src/routes/session.tsx)
  useSessionEvents()
  <SessionToolbar>
    <RunSkillButton> (packages/ui)
```

- Show file responsibility or a broad refactor as a shallow file tree:

```text
src/
├── commands/       # parses user actions
├── sessions/       # owns session state
└── transport/      # sends API requests
```

- Use `diff` when the point is what changes and the surrounding shape already exists. Match the diff shape to the topic.

For a component change:

```diff
 <SessionPage>
   useSessionEvents()
   <SessionToolbar>
+    <RunSkillButton />
   <SessionTimeline>
+    <SkillResultCard />
```

For a file-layout change:

```diff
 src/
 ├── commands/
+│   └── show-me.ts       # expands the slash command
 ├── sessions/
-└── transport.ts
+└── transport/
+    ├── client.ts
+    └── stream.ts
```

For a call-tree or call-stack change:

```diff
 submitForm
   createSession
     persistPrompt
+    expandSkillMention
     launchAgent
-  navigateToSession
+  navigateToSession
+    subscribeToEvents
```

For a state or control-flow change:

```diff
 on(save)
-  write content
+  if content is unchanged
+    return cached result
+  write new content
+  invalidate cache
```

- Show the whole block when most of it is new, when omitted context would hide ownership or order, or when the user needs a copyable target shape:

```ts
function expandSkill(command: string): string {
  const skillName = command.slice(1);
  return `use the ${skillName} skill`;
}
```

- For a visual UI, layout, state comparison, or a concept too dense for plain text, build one focused HTML page — a diagram, an infographic, a code review, or a short slide deck, whichever fits the point. Use real labels and data. If the topic is a product with an established look, match its colors, type, spacing, and components inside the `--html` fragment. Put graph-shaped relationships — sequences, state machines, dependency graphs — in a mermaid block in the page rather than a bare chat fence, which most surfaces show as source text.

### building the page

Build pages with `~/.claude/skills/show-me/page`. It wraps blocks in a shared template that already carries the themes (light and dark, switchable by the user), fonts, highlighting, diagrams, diff rendering, versions, live reload, and a feedback box, so write only content — never a `<head>`, page-level CSS, or library tags.

```sh
~/.claude/skills/show-me/page --title "Checkout pricing bug" \
  --h "Current flow" --md - --mermaid flow.mmd \
  --h "Tests" --log test.log \
  --h "Fix" --split --diff <(git diff) --code src/pricing.js:10-40 \
  --open <<'EOF'
Two lines of prose. ```mermaid fences inside markdown render as diagrams too.
EOF
```

| Flag | Block |
| --- | --- |
| `--h <heading>` | Starts a section; the following blocks go inside it. Its heading labels the user's notes on it, so make headings distinct. |
| `--md <src>` | Markdown; raw HTML allowed; ```` ```mermaid ```` fences become diagrams |
| `--mermaid <src>` | Mermaid source. Tag a flowchart node `:::accent` to highlight it — no `classDef` needed |
| `--diff <src>` | A unified or git patch; put `--split` before it for side-by-side |
| `--code <src>[:A-B]` | Source file, optionally lines A..B, with its real line numbers |
| `--log <src>` | Terminal output; ANSI colors kept |
| `--json <src>` | JSON, pretty-printed |
| `--html <src>` | An HTML fragment for interactive or custom visuals; it runs in its own frame, so its CSS, ids, and scripts can't affect the rest of the page |

- `<src>` is a path, `<(command)`, or `-` for stdin (once per page). Pass files, diffs, and command output **by path or pipe — never copy their contents into a block**; only prose, diagram source, and custom HTML should be written by you.
- For `--html` fragments, style with the page variables so every theme works: backgrounds `--bg` `--bg2` `--bg3`; text `--fg` `--fg2` `--fg3`; `--border`; semantic `--accent` `--danger` `--success` `--warning` (each with a `-bg` variant); `--radius`; `--font-sans` `--font-mono`. Bare `button`, `input`, `select`, and `textarea` are pre-styled.
- Every card has a note box, and the top bar's Copy button puts all notes on the clipboard as `[show-me: <title> v<N> · <path>]` followed by one `## <section>` block per note (`## General` for page-wide notes). A message starting with that tag is the user's feedback on version N of that page; each `##` names the section it is about.

### rendering the page

`page` writes `/tmp/show-me/<project>/<slug>/index.html` (the project is the git repo name; override with `--project`, or the whole path with `--out`) and prints the path and version. Then:

| Condition | Do this |
| --- | --- |
| `$WAYLAND_DISPLAY` or `$DISPLAY` is set | Pass `--open`; it opens the browser only for a new page |
| Neither is set — a server or plain SSH session | Publish the printed file with the Artifact tool and give the user the URL |
| The user asks for a link, or wants to keep or share it | Publish the printed file with the Artifact tool |

To revise a page, rebuild it with the same `--title`. That saves the next version (`v2.html`, ...), and a tab that already shows the page reloads itself within a couple of seconds, so don't open it again or ask the user to refresh. A rebuild with identical content adds no version.

### guidance

Place each visual next to the short text it supports. Keep only the calls, files, props, states, and boundaries needed to answer the user's current question or the options to resolve the current discussion point.

You may use one of these, you may use several, it is unlikely you will use all of them. Use your judgement and don't overwhelm the user.
