---
name: prototype
description: Build a throwaway prototype that answers one design question. TRIGGER when the user says "prototype", "does this state model feel right", "push this logic through some cases", "show me a few options for this page", or invokes /prototype. SKIP when the point can be explained rather than tried; use show-me for that.
---

# Prototype

A prototype is throwaway code that answers one question. The question decides
the shape; getting the shape wrong wastes the whole prototype. In a workbench
repo it is built inside a research item's worktree, and the item's concepts
carry the answer; archive discards or copies the code. Elsewhere, keep it on a
throwaway branch and record the verdict where the decision lands.

Two shapes:

- **"Does this logic or state model hold up?"** A one-file HTML demo, below.
- **"What should this page look like?"** Variants on the real route, below.

If the question is ambiguous and the user is not around, pick by the
surrounding code (a module: logic; a page or component: UI) and state the
assumption at the top of the prototype.

## Rules for both

1. Marked as throwaway: `prototype` in the file or route name, placed next to
   what it is prototyping, using the project's routing convention.
2. Starts with one command or a double-click. No thinking required to run it.
3. State lives in memory. Persistence is what a prototype checks, not what it
   depends on; if the question is about a database, use a scratch one named
   "PROTOTYPE, wipe me".
4. No tests, no error handling beyond what makes it run, no abstractions, no
   "what if we later want X".
5. The full relevant state is visible after every action or variant switch.

## Logic: one-file HTML demo

One plain HTML file, everything inline, no framework, no server. Two parts:

- **A pure module** in its own `<script>`: a reducer `(state, action) =>
  state`, an explicit state machine when "which actions are legal now" is
  part of the question, or a few pure functions over a plain type. No DOM,
  no handlers reaching inside. The page calls into it; nothing flows back.
  This is the part that lifts into the real code when the question is
  answered.
- **The page**, a thin shell, top to bottom: the question in one paragraph;
  the current state as labelled fields, re-rendered after every click, with
  what just changed called out; one free-play button per action, always
  available; guided walkthroughs as tabs, one scenario each, with a short
  description and the ordered buttons to press. Starting a walkthrough
  resets to a known initial state.

Scenarios cover the cases hard to reason about on paper: the happy path, a
tricky edge, an attempt at something that should be illegal. Labels use the
domain's words (the project glossary when there is one), not the reducer's.
Clean typography, one accent colour, no animation.

## UI: variants on the real route

Three variants by default, five at most. Render them on the existing route,
gated by `?variant=`, with the page's data fetching, params and auth left as
they are; only the rendered subtree swaps. A new throwaway route is the last
resort, for a surface with no page to live inside; an empty route hides the
design problems a populated one exposes.

Variants must be structurally different: layout, information hierarchy,
primary affordance. Same layout with new colours is a tweak, not a variant;
if two drafts come out alike, redo one with "not a card grid". A shared
header is fine, a shared layout defeats the point. Variants read data only;
a mutation points at a stub.

One shared switcher component: a fixed pill at the bottom centre with a
previous arrow, the variant key and name, a next arrow, wrapping around. It
writes the search param through the framework's router so a variant is
shareable and reload-stable; the arrow keys cycle too, except when an input,
textarea or contenteditable is focused. Visually distinct from the page, and
hidden in production builds.

When a variant wins, fold it into the real page rewritten to production
standard, and drop the losers and the switcher from main.
