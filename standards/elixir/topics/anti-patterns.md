# Anti-patterns

Scope: Concrete hazards we reject in review, drawn from real PR comments. Some overlap
with tooling: [**Credo**](https://hexdocs.pm/credo/Credo.html)'s warning and refactoring checks already flag several of these
(`Credo.Check.Warning.UnsafeToAtom` for dynamic atoms, `Credo.Check.Refactor.WithClauses`
for `with`/`else`, `Credo.Check.Warning.MixEnv` for `Mix.env/0` at runtime), and the
official Elixir anti-patterns docs cover atoms-from-input, complex `else` in `with`, and
application config for libraries. Strong custom **Credo** check candidates are the ones tools
miss today: catch-all `Utils`/`Helpers` module names, string reasons in `:error` tuples,
`inspect/1` of structs in logs, `Logger` wrapper modules, and dispatching on a non-first
argument. The rest is reviewer judgment. This doc is the avoid-this collection; do-this
patterns live in `idioms.md` and the reasoning behind them in `principles.md`.

## Atoms and external input

#### Atoms From External Input

Never create atoms from external input. `String.to_atom/1` and its relatives build atoms
that are never garbage collected, so unbounded creation from user data can exhaust the
atom table and take the node down. Use `String.to_existing_atom/1` or an explicit
allowlist, or keep the data as strings.

## Control flow

#### Avoid `try`/`rescue` and `throw`/`catch`

Avoid `try`/`rescue` and `throw`/`catch`. They are extremely rare in idiomatic Elixir.
Let it crash instead, and let expected raises such as `String.to_existing_atom/1`
propagate. For optional callbacks, define the function everywhere or check with
`Module.defines?/2` rather than rescuing. When a failure is expected rather than
exceptional, do not raise: return a tagged error tuple like `{:error, reason}` the caller can handle.

#### Special Casing Error Handling

Do not special-case error handling without cause. Handle non-success cases uniformly
unless one case genuinely needs distinct logic.

## Defensive and non-assertive code

#### Defensive Code And Assertions

Do not write defensive code for conditions your own system guarantees: nil-guards on
access chains that must succeed, catch-all error clauses for cases you have not proven, or
checks a plug already performs. Let it crash. Surface the violation while writing tests,
fix it, and trust the invariant thereafter.

## Error handling and results

#### Bare String Error Reasons

Do not return bare string reasons in `:error` tuples. Callers cannot pattern match on a
string, and the failure detail is lost. Return structured, matchable data such as
`{:error, :failed_s3_upload, response: response}`. A human-readable string is acceptable
only at the very last step, when rendering the failure into a response for the client.

#### Result Tuples As Arguments

Do not pass `:ok`/`:error` result tuples into helper functions as arguments; inline the
call and branch with `case`.

#### Returning Ok On Failure

Do not return `:ok` while only logging a warning about a failure. That masks an error the
caller should handle. Return an error the caller can act on.

## Logging

#### Wrapping Logger In Helper

Do not wrap `Logger` in a helper module. The wrapper becomes the reported source file and
line, and `Logger` already captures the real call site. Call `Logger` directly and
configure **Airbrake.LoggerBackend** for error reporting. For the same reason, do not
extract side-effectful "logging functions"; inline the log call where it happens.

#### Logging Full External Responses

Do not log full external response bodies or raw external text. They may carry PCI or PII,
or newline-based log-injection payloads. Log only specific keys or redacted, sanitized
(newline-stripped, truncated) fields.

#### Inspecting Structs Into Logs

Do not `inspect/1` a struct or changeset into a log or **Airbrake** message; they are
unreadable even pretty-printed. Extract the meaningful fields first, for example
`errors_on/1` for a changeset.

#### Logging Already Logged Errors

Do not log an error again when the function you called already logged it.

#### Logger Metadata As Data

Do not use `Logger.metadata/0` to pass functional data between functions. Metadata is for
incidental context like a request id; pass values your logic depends on explicitly as
arguments. Incidental request context such as `request_id` and `client_slug` is fine as
metadata; the ban is only on functional data your logic depends on.

#### Do Not Log Expected Outcomes At Warning Or Error

Reserve `Logger.warning/1` and `Logger.error/1` for genuinely unexpected, recoverable
conditions. An expected outcome, such as a not-found result or an operation that
essentially cannot fail, does not belong at those levels and often does not need a log at
all. Log it at `:info` or `:debug`, or drop it. Match the level to how surprising the event
is, not to the shape of the code path.

#### Give Error And Airbrake Notices Actionable Context

An error log or **Airbrake** notice that is too vague gives no way to triage it. A bare
`"Failed to lookup obligation association"` needs the identifying context: the relevant id,
the failure `reason`, and the params that produced it. Pass specific fields rather than a
whole struct (see `Inspecting Structs Into Logs`).

## Modules and organization

#### Catch All Utils Modules

Do not create catch-all `Utils` or `Helpers` modules; they become dumping grounds. Give
each function a home module named for its responsibility, and prefer an existing library.

#### Feature Envy Across Structs

Watch for feature envy: a function that mostly digs into another struct's data belongs in
that struct's own module.

#### Over Engineering And Abstraction

Do not over-engineer. Avoid unnecessary abstraction layers, excess helper functions, and
module attributes that add indirection without benefit. Prefer the simplest code that
keeps everything in one place.

#### Test Only Modules In Production

Do not reference test-only modules like `DataCase` from production code; they are not
compiled into a release. Copy the needed helper into a production module.

#### Prefer Alias Over Import

Prefer `alias` over `import`. `import` brings another module's names into scope ambiguously
and couples the two modules, while `alias` keeps each call site explicit about where a
function comes from. In the extreme, modules that import each other can even deadlock
compilation, so break such a cycle with `alias`.

## Macros and metaprogramming

#### Macros To Vary Behavior

Do not reach for macros or metaprogramming to vary behavior. A macro is copy-paste that
bloats every caller, and an overridable hook is premature until something actually
overrides it. Use plain functions, first-class functions, or optional keyword arguments
unless you genuinely need `unquote`, the `opts` parameter, or context like `__MODULE__`.
The [official Elixir macro guide](https://hexdocs.pm/elixir/macros.html) puts it plainly:
"Macros should only be used as a last resort." More broadly, do not implement OOP in Elixir:
macros and inheritance-style base modules that emulate objects fight the language. See
`Inheritance Style Base Modules`.

Prefer:

```elixir
defmodule Core.Vendor.Datacap do
  def emv_sale(payment, opts \\ []) do
    details = Keyword.get(opts, :additional_details, %{})
    ...
  end
end
```

Over:

```elixir
defmodule Core.Vendor.Datacap do
  defmacro __using__(_opts) do
    quote do
      def emv_sale(payment), do: ...
      def additional_details(_payment), do: %{}
    end
  end
end
```

#### Long Using Macros

Keep macros minimal, and do not disable lint rules to allow a long one. A `__using__/1`
macro should emit a one-line delegation to a normal function that holds the logic. Long
macros are hard to write, test, and debug.

#### Inheritance Style Base Modules

Do not model shared behavior with inheritance-style base modules or Ruby-style module
inclusion. When only a function is needed, use a plain module or pass functions as values,
and reach for a protocol when you need polymorphism.

## Data types and matching

#### Matching On Keyword Lists

Do not pattern-match on keyword lists; their order is significant, so a match almost never
holds. Fetch by key with `Keyword.fetch!/2` instead.

#### Depending On Map Ordering

Do not depend on map key ordering, for example in `inspect/1` output. Erlang can order
keys differently across versions.

#### Dispatching On Later Arguments

Order function arguments so you pattern-match and dispatch on the first argument.
Dispatching on a later argument is an anti-pattern.

## Configuration

#### Library Config Via Application

Do not configure library code through application config (`config/*.exs`); pass
configuration as plug or function options (`opts`) instead.

#### Calling Mix Env At Runtime

Never call `Mix.env()` in runtime or business logic. `Mix` is a build tool and is absent
from releases. Drive runtime behavior through configuration values.

## Comments and dead code

#### Concise and Necessary Comments Only

Do not add comments that restate what the code already says or narrate the change you just
made. Omit needless words in comments and documentation alike: say only what a competent
reader needs, and do not restate what `@spec`, `@callback`, enum values, or the schema
already document, or explain a pattern a competent developer already infers. If a
descriptively named function already conveys what it does and why, a comment may not be needed
at all; prefer a clear name over a comment that restates it. Keep the one comment that captures
a non-obvious, load-bearing invariant. Rationale belongs in the PR, commit, or ADR.

#### Avoid Time-Relative Words In Comments

Do not write comments that lean on "today", "now", or "currently". They go stale the moment
the code changes, and they usually signal a rationalization for the change rather than an
explanation of what the code does. Describe the behavior itself: "we filter sensitive data
out of objects" outlasts "today we filter sensitive data out of objects".

#### Leaving TODO Comments

Do not leave TODO comments. If work is deferred, leave a plain comment that references the
ticket that will do it.

#### Committed Dead Code

Delete dead code rather than committing it: commented-out code, unused or unreachable
code, and no-op calls such as a `tap/1` that produces no side effect.

#### Committed Generated Artifacts

Do not commit generated artifacts such as OpenAPI specs to version control; they drift out
of date. Generate them as needed.

## Duplication

#### Duplicating Values With Homes

Do not duplicate a value or accessor that already has a home. Do not copy data into a
module attribute when it already lives in the operation definition, and do not
re-implement another module's config accessor. Depend on the owning module or its
behaviour so a rename changes one place.

## Parsing

#### Regex For Nested Grammars

Do not parse recursive or nested grammars with regular expressions; a regex cannot track
recursion depth. Use a real parser or the AST.

## Mix tasks

#### Logic In Mix Tasks

Keep logic out of Mix tasks. They are hard to test, and a large body of untested task code
is a smell. Move the logic into tested modules the task calls.

## Tests

#### Overusing Mox Stub

Do not overuse `Mox.stub/3`, especially for a function whose return only steers control
flow. A stub never proves the call happened. Use `Mox.expect` when the call itself must be
verified.

#### Synchronous Test Designs

Do not write code whose design forces its tests to run synchronously; structure it so
tests can run async.

#### Application Env In Tests

Do not manipulate `Application` env inside tests to steer behavior. It is an anti-pattern
rooted in configuring code through application config instead of passing `opts`.
