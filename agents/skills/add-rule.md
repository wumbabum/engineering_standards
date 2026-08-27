---
name: add-rule
description: How to add or revise a rule in the Euna Payments engineering standards. The theme .md docs are the source of truth; references live in a per-doc store keyed by rule slug; the dashboard is generated. Covers the strict format, the code-formatting conventions, and the lint/build steps.
---

# Add a rule

The theme docs under `standards/elixir/*.md` are the source of truth. Each rule is one `####`
heading. Its PR references live in a companion store `references/elixir/<doc>.json`, keyed by
the rule's slug. The dashboard (`index.html`) is generated from both and is not committed.
Do not invent rules; ground each one in real PR review comments.

## Doc format (strict)

```
# <Collection title>              one H1
Scope: <one line>                 not a rule

## <Section / sub-group>          groups rules
#### <Rule name>                  one per rule; the heading text is the rule name
<rule body>

#### <Rule name>
<rule body>
```

- `##` is a section (a sub-group). Every rule lives under one.
- `####` is a rule. The heading is a SHORT, UNIQUE (within the doc) name, 3 to 6 words,
  Title-case, no trailing punctuation and no code/backticks/links in the heading itself.
- `###` is reserved (do not use it for rules).
- The **slug** (join key) is the name lowercased with non-alphanumerics collapsed to `-`.
- The body is the prose beneath the heading, formatted per the conventions below. It may
  include sub-bullets and one `elixir` code fence.
- Do not put PR/reference URLs in the doc.

## Formatting a rule body

- **Backticks for code:** atoms (`` `:ok` ``), function/macro references
  (`` `Enum.filter/2` ``, `` `with/1` ``, `` `&Module.fun/2` ``, `` `defp` ``), special forms
  and attribute/struct-field atoms (`` `__MODULE__` ``, `` `@impl` ``), sigils, and
  prose-looking code fragments near `[] {} / \` (`` `value not in [nil, ""]` ``).
- **Bold for module/library NAMES** (no function/arity): `**HTTPoison.Error**`, `**Ecto.Multi**`.
- **Links** wrap the bold name as a bold link `[**Name**](url)`:
  - internal repo -> `https://github.com/CityBaseInc/<repo>` (a module like `CBRelay` and the
    repo `cb_relay` both normalize to `cbrelay`);
  - external lib -> its hexdocs page (for example `Ecto.Multi` ->
    `https://ecto.hexdocs.pm/Ecto.Multi.html`). Link only libraries you are confident about.
- **Sub-bullets** for detail when a rule has exceptions or a short list.
- No em dashes.

## Steps to add a rule

1. **Add the `####` rule** under the correct `##` section in `standards/elixir/<doc>.md`,
   with a short unique name and a formatted body.
2. **Add its store entry** to `references/elixir/<doc>.json` (a list of per-rule objects):
   ```json
   {
     "schema_version": 3,
     "doc": "standards/elixir/<doc>.md",
     "rules": [
       {
         "name": "Exact Rule Heading",
         "tags": [],
         "references": [
           { "comment_url": "https://github.com/CityBaseInc/<repo>/pull/<n>#discussion_r<id>",
             "repo": "<repo>", "pr_number": 123, "author": "<handle>",
             "path": "lib/...", "line": 42, "created_at": "2026-01-01T00:00:00Z" }
         ]
       }
     ]
   }
   ```
   `name` must exactly match the rule's `####` heading (the join key is its slug). `tags`
   defaults to `[]`. References are link-only; copy the whole `comment_url` from the real
   review comment. A rule may have several references; cluster near-duplicate comments under
   one rule.
3. **Run `make lint`** (checks the format and that every rule slug has a references entry and
   vice versa), then **`make dashboard`** to regenerate `index.html`.
4. **Commit** the doc and the store together. `index.html` is generated and not committed.

## Adding a new doc

1. Create `standards/elixir/<slug>.md` with an H1, a `Scope:` line, `##` sections, and
   `####` rules.
2. Create `references/elixir/<slug>.json` (schema_version 3, `doc`, and a `rules` list of
   `{ name, tags: [], references: [...] }`).
3. Link the new doc from `standards/elixir/README.md`.
4. `make lint` and `make dashboard`.

## The 1:1 contract

`make lint` and `make dashboard` both fail unless, for every doc, the set of rule slugs in the
`.md` equals the set of slugs in its references store. A rename that changes a slug will fail
the build until the store key is updated. That is the check working as intended.

## Checklist

- [ ] Rule is a `#### ` heading (short unique name) under a `## ` section.
- [ ] Body formatted (backticks for code, bold for module names, links, sub-bullets); no em dashes; no URLs in prose.
- [ ] Store entry `{ name, tags: [], references }` added to `references/elixir/<doc>.json`, `name` matching the heading.
- [ ] `make lint` passes (format + 1:1).
- [ ] `make dashboard` regenerates `index.html`.
- [ ] Committed the doc and store; `index.html` left out.
