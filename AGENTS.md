# AGENTS.md

Agent entry point for `engineering_standards` (Euna Payments). Human readers start at
[README.md](README.md); this file is the terse operational map for agents.

## What this repo is

- The plain-language **source of truth** for how we write code. Per-repo tooling (formatters,
  linters, CI) is configured to match these docs, not the reverse.
- Every rule is derived from **real PR review comments** by our senior reviewers. Do not
  invent rules; ground them in that evidence.

## Layout

- `standards/<lang>/*.md` - the standards and the SOURCE OF TRUTH. One file per topic; each
  rule is a `#### ` heading (its name) under a `## ` section. No frontmatter.
- `references/<lang>/<slug>.json` - per-doc references store: a list of per-rule metadata
  `{ name, tags: [], references: [...] }` (link-only PR provenance, no rule text). Join to the
  doc by `name`; the doc and its store must be 1:1.
- `examples/` - native code examples next to a convention (planned; none yet).
- `index.html` - generated, self-contained dashboard. NOT committed (git-ignored); build it.
- `scripts/` - Elixir tooling: `lib/standards.ex` (parser), `build_dashboard.exs`, `lint.exs`.
- `Makefile` - `make lint`, `make dashboard`, `make dashboard-build`.

## House rules (must follow)

- **No em dashes** in any prose.
- Standards are human-language and imperative; state settled team standard, not suggestions.
- Rules live in the `.md` docs; references live in the store. Never put PR URLs in the docs,
  and never hand-write rule text into a store.
- To add or change a rule, follow the `agents/skills/add-rule.md` skill: `#### ` rule under a
  `## ` section, references under its slug in the store, then `make lint` and `make dashboard`.
- The doc rule slugs and the store slugs must stay 1:1; `make lint`/`make dashboard` fail otherwise.
- Commit one topic/theme per commit. Default branch is `master`; work on a branch.

## Current state

- 10 authored docs, one `#### ` heading per rule, 428 rules total: modules, naming,
  control-structures, idioms, anti-patterns, principles, application-configuration,
  unit-testing, property-testing, tooling.
- Each doc has a references store of per-rule metadata; the dashboard is generated from docs + stores by
  `scripts/build_dashboard.exs`. `make lint` enforces format + the 1:1 contract. CI runs both.
- Planning docs and one-off migration helpers live in gitignored `temp/`.

## Future plans

- **Tags:** render each rule's `##` section as a filterable tag; then allow arbitrary per-rule
  tags. See `temp/planning/sidecar-removal.md`.
- **Re-home MISC:** ~227 fragments ejected during synthesis are tracked in
  `temp/data/synthesis/misc_tracker.json`; review for keepers.
- **Hosting:** private, org-only GitHub Pages for the dashboard (deferred, pending devops).
- **`skills/`:** more skills that operate on the standards themselves.
- **Umbrella apps:** a planned standard, not yet authored.
