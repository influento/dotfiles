---
name: show-me
description: Help the user understand the current topic visually with concise diagrams, code-shape sketches, and focused HTML pages. TRIGGER when the user says "show me", "draw", "diagram", "visualize", "what does X look like", or invokes /show-me. SKIP when the answer is a single fact, a one-line lookup, or a code fix. For charts of numeric data use dataviz instead; for a UI mockup the user will refine by hand, use design instead.
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

- For a visual UI, layout, state comparison, or a concept too dense for plain text, write one focused HTML file — a diagram, an infographic, or a short slide deck, whichever fits the point. Use real labels and data, and support desktop and mobile. If the topic is a product with an established look, match its colors, type, spacing, and components; otherwise use a restrained neutral palette that reads in both light and dark.

  Put graph-shaped relationships — sequences, state machines, dependency graphs — in a mermaid block *inside* that page rather than in a bare chat fence, which most surfaces show as source text:

```html
<pre class="mermaid">
sequenceDiagram
    participant User
    participant UI
    participant Daemon
    User->>UI: choose command
    UI->>Daemon: send expanded prompt
    Daemon-->>UI: stream result
</pre>
```

  Load mermaid from `https://cdnjs.cloudflare.com` at a pinned version; published artifacts render these blocks natively with no library.

### rendering the page

Write it to `/tmp/show-me-<slug>.html` so it does not persist or clutter the project, then:

| Condition | Do this |
| --- | --- |
| `$WAYLAND_DISPLAY` or `$DISPLAY` is set | Open it locally: run `xdg-open /tmp/show-me-<slug>.html` (use `open` instead on macOS) |
| Neither is set — a server or plain SSH session | Publish it with the Artifact tool and give the user the URL |
| The user asks for a link, or wants to keep or share it | Publish it with the Artifact tool |

### guidance

Place each visual next to the short text it supports. Keep only the calls, files, props, states, and boundaries needed to answer the user's current question or the options to resolve the current discussion point.

You may use one of these, you may use several, it is unlikely you will use all of them. Use your judgement and don't overwhelm the user.
