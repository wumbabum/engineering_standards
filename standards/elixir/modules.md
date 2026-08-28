# Modules

Scope: Judgment and practice for how we shape, name, organize, and document modules.
Some of this overlaps with **Credo**'s readability checks (notably
[**Credo.Check.Readability.StrictModuleLayout**](https://hexdocs.pm/credo/Credo.Check.Readability.StrictModuleLayout.html), which we enable per repo), and several
rules below are candidates for custom or enabled **Credo** checks: strict directive layout,
unused aliases and requires, redundant self-aliases, and `@doc` on private functions.
The rest is reviewer judgment that tooling cannot enforce.

## Namespacing and aliasing

#### Alias At Parent Namespace
Alias at the parent namespace and refer to modules by qualified names. Do not use
`alias ..., as: ...`, and do not abbreviate names; both make the code harder to reason
through.

```elixir
alias CBRelay.Metrics
Metrics.Counter.increment()
```

#### Group Aliases Into Clusters
Use aliases consistently within a module. Group them into logical clusters, for example
base modules separate from their `.Multi` submodules, or infrastructure separate from
domain, rather than collapsing everything into one long combined alias.

Prefer:
```elixir
alias Core.{Change, Entry, Repo}
alias Core.{AdminMulti, ObjectMulti, UserMulti}
```

Over:
```elixir
alias Core.{AdminMulti, Change, Entry, ObjectMulti, Repo, UserMulti}
```

#### Remove Unused And Redundant Aliases
Remove aliases that are unused, and remove redundant aliases that only rename a module to
its own name.

#### Fully Qualify Colliding Names
Use the fully-qualified module name wherever an unqualified name could collide with a
same-named module from another library.

#### Module Name Matches File Path
A module's name must match its file path per the conventional naming pattern.

#### Namespace Task Specific Modules
Namespace task-specific modules, such as argument parsers and error handlers, under the
task that owns them. Scope a genuinely reusable module by its own responsibility instead,
rather than nesting it under a single task.

#### Follow Framework Directory Conventions
Follow framework directory conventions. Co-locate [**Phoenix**](https://hexdocs.pm/phoenix/Phoenix.html) view and JSON modules with
their controllers, and keep plug modules in the plugs directory.

## Module organization and single responsibility

#### Keep Logic In Context Layer
Keep business logic and data access in the API/context layer. Do not put it in [**Ecto**](https://hexdocs.pm/ecto/Ecto.html)
schema modules or in workers, and route database writes through the context rather than
calling **Repo** directly. Workers coordinate; the context owns persistence.

#### Keep Pure Functions Free Of Database
Keep parsing and other pure functions free of database access. Resolve data needs at the
domain boundary and pass plain data into the pure function.

Prefer:
```elixir
def select_sale_transaction(buffer, user_trace, competing_attempts) do
  # ...match against competing_attempts...
end
```

Over:
```elixir
def select_sale_transaction(buffer, user_trace) do
  competing = Repo.all(from a in Attempt, where: a.user_trace == ^user_trace)
  # ...match against competing...
end
```

#### Confine Framework Dependencies To Component Apps
Confine framework-specific dependencies such as [**Oban**](https://oban.hexdocs.pm/Oban.html) and **Phoenix** to their own component
app, and keep `core` free of them.

#### Keep Shared Modules Generic
Keep shared and generic modules generic. Vendor-, stage-, or data-specific logic belongs
in the specific module (the vendor implementation, the data-owning module), not in the
shared or infrastructure module. A filesystem module handles file operations; it does not
transform the data it moves.

#### Give Every Function A Home
Give every function a home that matches its responsibility. Avoid catch-all `utils` or
`helpers` dumping grounds, do not place a function in a module whose name misrepresents
it, and expose reusable library-level helpers from the top-level module via `defdelegate`.

#### Keep Config Reading Separate
Keep environment and configuration reading out of modules dedicated to another concern,
such as authentication and authorization.

#### Keep Task Data Models Independent
Let task-specific data models stay independent when their assumptions differ. Share only
stable formats rather than coupling the tasks to one model.

#### Isolate Temporary And Migration Tooling
Place temporary or migration tooling in a dedicated task application, not in long-lived
core modules.

#### Define Shared Value Lists Once
Define a shared value list once, as a module attribute exposed through a public accessor,
and drive all callers, generators, and tests from that single source.

#### Extract Duplicated Type Definitions
Extract duplicated `@type` definitions into a shared module. If duplication is genuinely
necessary, comment why, since `defdelegate` does not carry types across module boundaries.

#### Share Cross App Boilerplate
Share cross-app boilerplate through a `use` macro with `defoverridable`, or through an
importable module, rather than copying it into each app.

#### Split Files That Grow Large
Split a file, or extract a nested module into its own file, once it grows large enough to
hold distinct concerns or becomes too large to review comfortably.

#### Keep Macros Minimal
Keep macros minimal. Have `__using__` emit a one-line delegation to a regular function
that holds the logic.

Prefer:
```elixir
defmacro __using__(_opts) do
  quote do
    def handle_errors(conn, error), do: SanitizedAirbrake.handle_errors(conn, error)
  end
end
```

Over:
```elixir
defmacro __using__(_opts) do
  quote do
    def handle_errors(conn, error) do
      # ...35 lines of logic copied into each caller...
    end
  end
end
```

#### Separate Behaviour From Implementation
Keep a behaviour definition separate from its implementations. Do not place an
implementation in the **Behaviour** module, and do not mix a behaviour with metaprogramming
that injects an implementation.

## Function visibility and ordering

#### Prefer Private Functions
Make a function private with `defp` unless it is genuinely part of the module's public
API. Prefer a private function over a public one marked `@doc false`, and cover public
functions with tests. A public function invites future callers, so publish only what you
intend to support.

#### Order Private Functions Below Public
Place all private functions below the public functions. Put environment-fetching helpers
at the very bottom. When a private-function blob grows large, extract it into a focused
module.

## Module layout, directives, and attributes

#### Strict Module Directive Layout
Follow a strict, consistent module layout. Put all directives at the top of the module in
the conventional order (`use`, `import`, `alias`, `require`), separated by blank lines.
Enforce this with [**Credo.Check.Readability.StrictModuleLayout**](https://hexdocs.pm/credo/Credo.Check.Readability.StrictModuleLayout.html).

```elixir
use ExUnit.Case, async: true

import Mox

alias Core.ObligationAssociation
alias Web.Audit

require Logger
```

#### Alias Before Importing Same Module
When both an alias and an import reference the same module, declare the alias first and
then import the aliased name.

#### Separate Special Attributes With Blank Lines
Separate the `@moduledoc`, and special-purpose attributes like `@moduletag`, from
surrounding attributes with a blank line so they are not misread as applying to the next
attribute.

#### Separate Plug From Alias Directives
Separate `plug` declarations from alias directives with a blank line as well.

#### Define Struct Type Via MODULE
Define a struct or schema's type using `__MODULE__`, as in
`@type t :: %__MODULE__{name: String.t()}`.

#### Name Type Aliases For Intent
Introduce named `@type`/`@typep` aliases to document intent, even when the underlying type
is `any()`.

## Behaviours and callbacks

#### Separate Callback Per Arity
Define a separate `@callback` for each arity, since callbacks cannot have optional or
default arguments.

Prefer:
```elixir
@callback check_captcha(response :: String.t()) :: :ok | :error
@callback check_captcha(response :: String.t(), provider :: String.t()) :: :ok | :error
```

Over:
```elixir
@callback check_captcha(response :: String.t(), provider :: String.t() \\ "default") ::
            :ok | :error
```

#### Name Callback Spec Parameters
Name the parameters in `@callback` specs. They are valuable documentation even though a
`@spec` sitting next to its function can omit them.

#### Omit Parameter Names In `@spec`
Omit parameter names in a `@spec` that sits next to its `def`. The argument names are on
the very next line, so repeating them in the spec is noise. Name parameters in a
`@callback`, where no `def` is alongside (see "Name Callback Spec Parameters"), and leave
them out of the `@spec`.

#### Do Not Repeat Callback Specs
Do not repeat a `@spec` on a callback implementation. Rely on the behaviour's callback
spec through `@impl`.

#### Write Full Behaviour Module Name
In `@behaviour` and `@impl`, write the full behaviour module name rather than `@impl true`
or an alias. It documents intent, and the compiler checks it.

## Documentation

#### Document Only Public Functions
Put `@doc` only on public functions. A `@doc` on a private function raises a compiler
warning, and internal-only functions should carry minimal or no `@doc`.

#### Document Functions With Doc Attribute
Document public functions with `@doc`, not inline comments, including their important
parameters and usage.

#### Begin Docs With Summary Paragraph
Begin a `@moduledoc` or `@doc` with a short summary paragraph that describes what the
module or function does, not a directive or a discussion of alternatives, and separate it
from the body with a blank line. **ExDoc** uses that first paragraph as the summary in module
and function listings.

#### Use Moduledoc For Distinctive Facts
Use the moduledoc to document what makes the module distinct: how it differs from its
siblings, examples, and important runtime facts, such as that a cache exists, where it is
stored, and that each pod holds its own copy.

#### Document Ecto Types With Typedoc
Document **Ecto** schema types with a `@typedoc` next to the type definition so the docs sit
beside the code.

#### Keep Docs About Usage
Keep code docs about how to use the code. Omit general concept-teaching and change
rationalizations; those belong in the PR description, the commit message, or an ADR.

#### Format Docs As Markdown
Format docs as Markdown. Use code fences rather than indentation for examples, and
backticked `Module.function/arity` references so **ExDoc** renders and links them.

#### No Blank Line Before Function
Do not leave a blank line between `@doc` and the function it documents.

#### Hide Internal Modules From Docs
Use `@moduledoc false` to hide internal-only modules from the generated documentation.

#### Centralize Usage Documentation
Put usage documentation in the relevant moduledoc and reference it from guides rather than
duplicating it.

#### Deprecate On First Clause
Mark a whole function deprecated with `@deprecated` on its first clause, not with `@doc` on
an individual clause.

#### Document Configuration In `@moduledoc`, Not Config-File Comments
Document configuration in the relevant plug or module `@moduledoc`, not as comments in
`config/*.exs`. A comment in a config file only reaches someone reading the source; it
never appears in **ExDoc**, where readers look, and a reader can mistake documentation-only
config for a live setting. Describe the options where the module that consumes them is
documented.

## Specs and cleanup

#### Format Long Specs Readably
Manually format long `@spec` definitions to place the return type on its own line:

```elixir
@spec determine_lookup_normalizer_args(map(), map(), binary(), binary(), list()) ::
        [LookupResponse.t()]
```

#### Prefer `map()` Over `%{}` In Typespecs
Use `map()` in a spec, not `%{}`. In a typespec `%{}` means the empty map, not "a map";
write `map()` unless you are actually enumerating the keys and their value types. A struct
is a `map()` to Dialyzer, so a `map()` spec already accepts struct arguments.

#### Reference A Type, Not A Struct Literal, In Specs
In `@spec` and `@type`, reference a type such as `Module.t()`, not a struct literal like
`%Module{}`. A struct literal is a value, not a type, and specs need the `t()` type the
struct module defines.

#### Model Constrained Values With `@type`, Not Literal-Union Specs
Model a constrained value with a named `@type`, not a bare `atom()` or `String.t()` and
not a string-literal union. A string-literal union such as `"hcaptcha" | "turnstile"` is
not a valid Dialyzer type: type the field as `String.t()` and enforce the allowed set in
the changeset. For a fixed set of atoms, declare an `@type` naming the members and
reference it from the `@spec` instead of `atom()`, so the allowed values are documented in
one place.

```elixir
@type scope :: :revenue_management | :cb_pos | :cashiering
@spec okta_role(Plug.Conn.t(), scope()) :: atom()
```

#### Keep Specs Accurate And Complete
Keep a `@spec` accurate and complete. It must cover the real return, including every error
tuple the function can now return and the actual key and value types it produces.
`Map.keys/1`, for example, returns whatever key types the map holds, not always
`[atom()]`, so type it `[atom() | String.t()]` or normalize the keys explicitly. When a
new return path is added, update the spec to match.

#### Type Keyword Options As A Tuple Union, Not A Custom Struct-Like Type
Do not model an options parameter with a custom struct-like `@type`. A keyword-list type
written as `[a: ..., b: ...]` forces every key to be present and always in that order, so
real `opts` values will not match it. Type `opts` as a union of `{:key, type}` option
tuples so each entry is optional and order-free, or alias `keyword()` and lay out the
options in a `@typedoc`. Keep the type named `opts` or `options` so it reads as optional
parameters.

```elixir
@type change_request_params_option ::
        {:field, StreamData.t(String.t())}
        | {:old_value, StreamData.t(String.t())}
        | {:new_value, StreamData.t(String.t())}
@type change_request_params_opts :: [change_request_params_option]
```

#### Remove Unused Require Statements
Remove unused `require` statements.

#### Remove Generated Boilerplate Docs
Remove inapplicable boilerplate docs generated by `mix new` that do not apply to the app.
