---
name: review-pr
description: Reviews a pull request or diff against the Euna Payments (CityBase) engineering standards in this repo. First matches the change's language or domain to a top-level standards/ folder (currently only elixir) and stops if none matches; otherwise reviews the diff against that folder's rules and reports findings that cite the exact rule. Use this whenever the user wants a PR, diff, branch, or code change reviewed or checked against our engineering standards, conventions, or house rules, even if they do not say the word "standards".
---

# Review a PR against the engineering standards

This repo IS the standards. The code under review lives in another repo. Review a PR's diff
against the rules in the matching top-level `standards/<domain>/` folder, and cite the exact rule
behind every finding. The rules are the source of truth: do not invent standards, and do not flag
anything no rule covers.

## Workflow

Copy this checklist and track progress:

```
- [ ] 1. Match the PR to a standards folder (gate; stop if none matches)
- [ ] 2. Load the matching folder's rules
- [ ] 3. Review the diff against those rules
- [ ] 4. Report findings, each citing a rule
```

## Step 1: Match the PR to a standards folder (gate)

This is a hard gate. Be exact.

1. Determine the change's primary language or domain from the PR: the changed files' extensions
   and the repo's primary language. Elixir is `.ex`, `.exs`, `mix.exs`.
2. List the available folders with `ls standards/`. Each subfolder is one language or domain.
   Currently the only folder is `elixir`.
3. Map the language/domain to a folder name (for example elixir maps to `standards/elixir`).

STOP if nothing matches. Do NOT review. State the PR's language/domain, say this repo has no
standards folder for it yet, list the folders that do exist, and end. A review with no matching
standards would be ungrounded guesswork, which is worse than no review.

If the PR spans several languages, review only the parts that map to an existing folder and state
which parts you skipped and why.

## Step 2: Load only the relevant rules

Do NOT read every doc. Start with the index `standards/<domain>/README.md`, which lists every
rule name grouped by topic doc and section, with no bodies. From the PR diff, decide which topics
are actually in play (an Ecto query change points at the Ecto and idioms topics, a migration at
migrations, a controller at Phoenix/Plug and OpenAPI, and so on), and open ONLY those topic docs
under `standards/<domain>/topics/`. Each `#### ` heading is one rule; its body, including any
`Prefer:` / `Over:` example, is the standard, and these docs are the ONLY basis for findings. When
a rule name in the index looks relevant, open its topic doc to read the full rule. You do not need
`references/<domain>/`, but a rule's linked PR comments there can clarify intent on a borderline
finding.

## Step 3: Review the diff

Get the diff with `gh pr diff <number>`, or use the diff you were handed. This is judgment work,
not a fixed procedure: read each changed hunk and check it against the rules you loaded.

- Flag a finding ONLY when it maps to a specific rule. Name the rule by its exact `#### ` heading
  and its doc file.
- Base each suggested fix on that rule's own guidance and its `Prefer:` example.
- Do not flag what no rule addresses, and do not introduce new standards inside a review.
- Weigh severity by the rule itself: a security or correctness rule outranks a stylistic one.

## Focus areas

Every rule in the matched folder is in scope, but a few are missed often enough to check on every
review. Weight your attention toward judgment rules that tooling cannot catch (correctness,
design, security) over formatting a linter would flag anyway. Load each rule from its doc and
apply it as written; these are pointers, not replacements.

- **Concise and Necessary Comments Only** (`anti-patterns.md`) is the single most common thing to
  flag. Watch for comments that restate the code, narrate the change, or repeat what `@spec`,
  `@callback`, enum values, or the schema already document. When a descriptively named function
  already conveys what it does and why, a comment may add nothing at all: flag the redundant
  comment and suggest the name carry the meaning instead. Keep only a comment that captures a
  non-obvious, load-bearing invariant.
- **Let Unexpected States Crash** and **Fail Fast On Contracts** (`principles.md`): flag defensive
  catch-all clauses, swallowed errors, and happy-path code that ignores `nil` or absent input. On
  the BEAM, a loud crash under supervision beats a quiet wrong answer downstream.
- **Return Tagged Reasons Not Parsed Strings** and **Descriptive Error Reason Atoms**
  (`idioms.md`): flag logic that branches on a human-readable message; decisions should switch on
  tagged tuples or atoms, not string prefixes.
- **N Plus One Queries** (`database.md`): flag a query issued inside a loop or enumeration;
  preload or batch instead.
- Security and correctness findings (anything in `security.md`, and the rules above) outrank
  stylistic ones; raise their severity accordingly.

## Output format

Group findings by file. Use this template (drop the file section for files with no findings):

```
## PR review: <pr title or number>

Reviewed against standards/<domain>/

### <path/to/file.ex>
- **<Exact Rule Name>** (<doc>.md), <file>:<line>: <what breaks the rule>. <Fix, per the rule.>

### Summary
<Overall risk and the must-fix items in one or two sentences.>
```

If nothing in the diff violates a rule, say so plainly and stop.

## Gotchas

- The code under review is NOT in this repo. Get it from the PR (`gh pr diff`) or the diff you
  were given.
- Match folders dynamically with `ls standards/`. A new language (for example `ruby`) becomes
  reviewable the moment `standards/ruby/` exists, with no change to this skill.
- One idea can appear as differently-named rules across several docs. Search the whole folder,
  not a single file, before concluding a change is unaddressed.
- Cite each rule by its exact `#### ` heading so the author can find it in the docs or dashboard.
- Posting the review back to the PR (inline comments or `gh pr review`) is a separate action. Do
  it only when the user explicitly asks; by default, return the review as text.
- No em dashes in anything you write. This is a repo house rule.
