# Engineering Standards

Language and engineering standards for Euna Payments engineering.

These pages are the plain-language source of truth for how we write code. Per-repo tooling
(formatters, linters, CI) is configured to match what lives here, not the other way around.
Individual repos may declare their own exceptions.

## Standards

- [Elixir](standards/elixir/) - style, structure, and testing conventions for our Elixir code.

## How this repo is organized

- Each collection is a folder under `standards/`.
- Every collection folder has its own README describing what it covers.
- A convention is a single Markdown file. When a convention grows large, it becomes its own
  folder with child pages and an examples folder.
- Example code lives in a `references/` folder next to the convention it supports.

More languages and non-language practices will be added as sibling collections over time.
