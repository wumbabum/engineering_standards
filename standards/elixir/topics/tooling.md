# Tooling

Scope: How we configure the project's build and developer tooling. These rules set up
`mix.exs`, the formatter, [**Credo**](https://hexdocs.pm/credo/Credo.html), [**Dialyzer**](https://hexdocs.pm/dialyxir/readme.html), and CI so the tools themselves enforce the rest
of these standards. They are about build and developer workflow, not runtime application
behavior.

## Dependencies and mix.exs

#### Pin Dependencies At Minor Level

Pin dependencies at the minor level (`~> 2.6`), not the patch level (`~> 2.6.0`). Minor
constraints make patch and minor upgrades easy and keep `mix.exs` from churning on every
update.

#### Alphabetize The Dependency List

Alphabetize the dependency list. **Mix** does not sort it for us, so keep it ordered by hand.

#### Keep Deps In One Function

Keep dependencies in a single `deps/0` function, grouped with comments rather than split
across several category functions. Separating dev and test entries with comments is fine;
splitting `citybase_deps` or umbrella apps into their own functions is not worth it.

#### Justify Dependency Version Overrides

Do not add a dependency version override without a concrete, stated reason, given as a comment
naming the conflict it resolves. Skip overrides entirely when the existing constraints already
resolve to the same version.

#### Preserve Load Order Dependencies

When load order matters, order those dependencies as the library's docs require and leave a
comment explaining why, so no one re-alphabetizes them by reflex.

#### Prune Unused Dependencies

Remove dependencies you no longer use, and prune the lockfile with `mix deps.unlock --unused`.

#### Include Test Support In Paths

Include `test/support` in `elixirc_paths` so support files always compile, even before the
directory has content.

#### Use Cli Function For Preferences

On Elixir 1.19 and later, use a top-level `cli/0` function with `preferred_envs` to set CLI
preferences such as preferred environments, rather than the older `preferred_cli_env` inside
`project/0`.

#### Prefer Standard Library Over Dependencies

Prefer the standard library over an unmaintained dependency. Reach for **Calendar** before
pulling in something like **timex**.

#### Use Jason As JSON Encoder

Configure [**Jason**](https://hexdocs.pm/jason/Jason.html) as the JSON encoder instead of adding a second JSON library. For example,
set `json_encoder: Jason` in the relevant config rather than adding `:poison` as a
dependency.

## Formatter

#### Set Consistent Line Length

Set a consistent `line_length` in every app's `.formatter.exs`. We use `120`.

#### Import DSL Libraries In Formatter

Add every library that provides a DSL or macros to `import_deps` in each `.formatter.exs`
(root and per app). This is what lets the formatter leave DSL calls parenthesis-free and
keep formatting stable. Without the DSL library in `import_deps`, the formatter forces
parentheses back on:

```elixir
# missing :ecto_sql in import_deps -> formatter rewrites to
add(:paid_at, :utc_datetime)

# with :ecto_sql in import_deps -> formatter leaves it as
add :paid_at, :utc_datetime
```

#### Format Non Elixir Languages

Provide a formatting script in the repo for non-Elixir languages that need consistent
formatting, such as OPA/Rego policy files, so those files are formatted the same way for
everyone.

## Credo

#### Run Credo In Strict Mode

Run [**Credo**](https://hexdocs.pm/credo/Credo.html) in strict mode (`strict: true`) in every
repository.

#### Enable Dbg Warning Check

Enable the checks that catch real mistakes. Turn on `Credo.Check.Warning.Dbg` to catch
leftover `dbg/1` calls.

#### Enable Spec Typespec Check

Move the `@spec` typespec check (`Credo.Check.Readability.Specs`) from the `disabled` list
into the `enabled` list as each repo adopts it.

#### Configure Credo To Team Style

Configure [**Credo**](https://hexdocs.pm/credo/Credo.html) to fit the team's style; do not contort code to satisfy a check. When a
check flags a pattern we intend to keep, find the specific check and adjust or disable it
rather than reshaping the code. Disable a check outright (set it to `false`) when it cannot
work with how we build, for example setting `Credo.Check.Warning.MissedMetadataKeyInLoggerConfig`
to `false` when a metadata check fails because keys are set dynamically in
`config/runtime.exs`.

## Dialyzer

#### Configure Dialyzer PLT Caching

Configure a dedicated PLT path so CI can cache it, add a `.dialyzer_ignore.exs` containing
an empty list `[]`, and gitignore the generated PLTs rather than committing them. Point the
`dialyzer` config at a dedicated, gitignored PLT directory so CI can cache it:

```elixir
defp dialyzer do
  [
    plt_add_apps: [:ex_unit],
    ignore_warnings: ".dialyzer_ignore.exs",
    plt_file: {:no_warn, "priv/plts/project.plt"}
  ]
end
```

#### Fix Dialyzer Discrepancies

Fix [**Dialyzer**](https://hexdocs.pm/dialyxir/readme.html) discrepancies rather than suppressing them. Resolving a discrepancy often
surfaces a real bug.

## CI and versions

#### Fail Build On Warnings

Fail the build on compiler warnings. Compile with `--warnings-as-errors` in CI so warnings
surface as failures instead of scrolling past.

#### Pin Toolchain Patch Versions

Pin the toolchain to exact patch versions in `.tool-versions`, and make CI run the same
Erlang and Elixir versions as the deployment base image so CI never passes on a runtime we
do not ship.

#### Sync Elixir Version Constraint

Keep the Elixir version constraint in `mix.exs` in sync with the CI test matrix. When you
bump one, bump the other.

#### Cache Build Artifacts Cautiously

Cache Elixir build artifacts cautiously, and treat a stale cache as a likely cause of a
mysteriously broken build. Use a single cache key that you bust wholesale, rebuilding from
scratch whenever the Elixir or Erlang version changes.

#### Avoid Unnecessary CI Matrix

Do not add a CI build matrix and a pass-through completion job when a service tests only one
runtime version. Hardcode the version where it is needed instead.

Prefer:

```yaml
jobs:
  test:
    steps:
      - uses: erlef/setup-beam@v1
        with:
          otp-version: '27.3.3'
          elixir-version: '1.18.3'
```

Over:

```yaml
jobs:
  test:
    strategy:
      matrix:
        otp: ['27.3.3']
        elixir: ['1.18.3']
    steps:
      - uses: erlef/setup-beam@v1
        with:
          otp-version: ${{ matrix.otp }}
          elixir-version: ${{ matrix.elixir }}
  tests-passed:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - run: echo "done"
```

## Mix tasks and aliases

#### Keep Mix Test Default

Do not re-alias `mix test` to also create and migrate the database. Deviating from the
default behavior surprises anyone who expects `mix test` to just run tests. Leave `mix test`
alone and put database setup in a separate alias such as `mix test.setup`.

#### Make Setup Tasks Reliable

Setup and bootstrap tasks must succeed reliably every time they run.

#### Use Release Tasks For Production

**Mix** tasks are not available in a release. For code that must run in production, write a
release task invoked through `bin/app eval` rather than a **Mix** task.

## Repo hygiene

#### End Files With Newline

End every file with a final newline. Turn on your editor's "Insert Final Newline" option so
this holds even for files Credo does not check, such as `.exs` scripts and `.tool-versions`.
