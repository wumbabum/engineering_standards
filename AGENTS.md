# AGENTS.md

This repo is the plain-language source of truth for how we write code at Euna Payments
(CityBase). It holds coding standards organized by language or domain, each rule distilled from
real pull request review comments by our reviewers. Consult it whenever you are reading or writing
code it covers, so your work matches the conventions it will be reviewed against.

## Layout

Standards are grouped into collections under `standards/`, each with the same shape:

```
standards/<domain>/
  README.md     generated index: every rule name by topic and section, no bodies
  topics/*.md   the standards themselves, one file per topic
```

The available collections are the subfolders of `standards/` (currently just `elixir`).

## How to use it

For the domain you are working in:

1. Open that collection's index, `standards/<domain>/README.md`. It is the source of truth for
   which topics and rules exist: every rule name grouped by topic and section, no rule text, so it
   is cheap to read. Do not rely on a list kept anywhere else, which can drift out of date.
2. This collection is built for progressive disclosure: from the index, identify the topics your
   task touches and open ONLY those topic docs under `standards/<domain>/topics/`, rather than
   reading everything.

A collection may include a `principles` topic (the reasoning behind the concrete rules) and an
`anti-patterns` topic (what to avoid); consult them when a rule is unclear or a change feels risky.

## Working on the standards themselves

- To add or change a rule, follow the `agents/skills/add-rule.md` skill: the strict doc format, the
  references store, the 1:1 doc-to-store contract, and the `make lint` / `make index` /
  `make dashboard` workflow.
- To review a pull request against these standards, use the `agents/skills/review-pr.md` skill.
