# Naming

Scope: Judgment and practice for what we call things, modules, functions, variables,
fields, files, tests, and terms. This is the cousin of [modules.md](modules.md), which
owns how modules are structured, aliased, and organized. Some of this overlaps with
**Credo**'s readability naming checks (`Credo.Check.Readability.FunctionNames`,
`ModuleNames`, `VariableNames`, and `PredicateFunctionNames` for the `?` convention),
which we enable per repo. Several rules below are candidates for custom **Credo** checks that
tooling does not ship: acronym capitalization in module names, the `Plug`/`API` suffix
conventions, and file-mirrors-module. The rest is reviewer judgment.

## Casing and spelling

#### Snake Case For Identifiers

Use `snake_case` for all Elixir identifiers. Elixir does not use kebab-case, and
`camelCase` belongs only at an external boundary such as the GraphQL layer, where you
convert on the way out and back.

#### Capitalize Acronyms As Units

Capitalize acronyms in module names as a unit. Write `CBAudit`, `API`, and `HTTP`, not
`CbAudit`, `Api`, or `Http`.

#### Use Behaviour Spelling

Use Elixir's official spelling, `behaviour`, in code and documentation.

## Function names

#### Name Functions For Behavior

Name a function for exactly what it does, with a precise verb. Reflect the current
behavior (`with_deleted`, not `active`), keep the name specific rather than overly broad,
and rename the function when its behavior changes (`enqueue_workers`, not `backfill`).

#### Avoid Vague Function Names

Avoid vague or misleading function names. Do not lean on suffixes like `handler` or
`error_handler`, do not prefix internal functions with `do_` (a `do_`-prefixed name states
the mechanism, not the action, so prefer `create_payment_instrument` over `do_call`), and
do not use a name that implies behavior the code lacks, such as `filter` for something that
does not filter. Give the function a name that describes its action.

#### Share Names Only When Semantics Match

Do not give differently-behaving functions the same name. Share a name across functions
only when their semantics match.

#### Question Mark For Booleans

Suffix a function with `?` only when it returns a boolean. Rename it if it returns an
ok/error tuple, so prefer `authorize` over `authorized?` when the return is `:ok |
{:error, reason}`. When one predicate name has to cover two meanings, split it into two
clearly-named predicate functions instead.

#### Keep Related Naming Consistent

Keep naming consistent across related functions. Use imperative verbs for callbacks and
functions, keep parameter names and types aligned between related functions, and keep
singular/plural forms consistent across a related set.

#### Follow Ecto Query Naming

Follow [**Ecto**](https://ecto.hexdocs.pm/Ecto.html)'s query naming. Use `get/2` for id lookups and `get_by` for maps of queryable
fields, and reserve `get` for functions that actually fetch from storage; use a more
precise verb otherwise.

#### Name Composable Query Parameters Queryable

Name a composable query parameter `queryable`, following **Ecto**'s
terminology.

#### Name HTTP Requests By Method

Name a function that makes an HTTP request after the HTTP method it uses. Name a
request-builder after the external API endpoint with an imperative verb, for example
`build_emv_sale`, so it is easy to grep for.

#### Transform Versus Convert

Name a map-to-map field-rearranging function `transform`. Reserve `convert` for functions
that actually change a value's type.

#### Suffix Function Options With Fun

Suffix an option key that takes a function with `_fun`.

## Variable and field names

#### Name Variables For Their Data

Name variables and parameters for the actual data they hold, using its type, source, or
the most important concept it represents, not a generic or incidental label. Prefer `body`
over a generic `request`, `jwt` over `user` when the token is the point, and a name that
reflects the full URL when that is what the variable holds.

#### Suffix Changeset Variables

Name a changeset variable with a `_changeset` suffix rather than like a plain struct, and
name a changeset function's first parameter for the current data struct it receives, not
for the changes.

#### Do Not Abbreviate Names

Do not abbreviate. Use full descriptive words for variables, parameters, and typespecs,
so prefer `obligation_association` over `oa`, and prefer standard idiomatic Elixir names
without unnecessary words.

#### Name Numeric Values With Units

Name numeric fields and values with their unit, for example `amount_in_cents`, and request
and label values in their true units so callers cannot misread them.

#### Prefix Related Fields Together

Give related fields a shared prefix so they group and alphabetize together.

#### Omit Context Implied Words

Avoid words in type and field names that the surrounding context already implies.

#### Name The Options Parameter Opts

Name the trailing keyword options parameter `opts`, not `options`. This is a strong, established
Elixir and Erlang convention, so following it keeps our signatures consistent with the wider
ecosystem and with the rest of our code.

## Module and file names

#### Name Modules For Responsibility

Name a module or struct for its responsibility or its actual contents, not for a single
function's output. Call it `IngestError` if it holds an error. Avoid vague `Helper` and
`Helpers` suffixes; name the module for the specific thing it is responsible for.

#### Keep Module Names Unambiguous

Choose module names that are terse yet unambiguous. Qualify a bare name that could
collide, and stay clear of names that clash with widely-used modules from the language or
common libraries.

#### Suffix Context Modules With API

Name context and API modules with the entity as a prefix and an `API` suffix, so prefer
`Core.BankAccountAPI` over `Core.API.BankAccount`. Do not nest them under a shared `API`
namespace or folder that forces alias renaming.

#### Name Files After Modules

Name a file after the module it defines, not after the library it wraps. Mirror the module
name in the path, so `Payment.BankAccountAPI` lives in `bank_account_api.ex`, and name test
files to match the module under test.

#### Suffix Plug Modules With Plug

Follow [**Phoenix**](https://hexdocs.pm/phoenix/Phoenix.html) conventions for plug modules. Name a plug descriptively for what it does to
the request and suffix it with `Plug` (`Web.<Name>Plug`), matching the controller and view
pattern, while omitting the `Plugs` namespace segment and avoiding long runs of
capitalized acronyms, so prefer `Web.OktaJWTAuthenticationPlug` over
`Web.Plugs.OktaJWTAuthentication`.

#### Follow Phoenix Controller Conventions

Follow **Phoenix** conventions for controllers and views. Omit the `Controllers` segment from
controller module names, so prefer `Web.PersonController` over `Web.Controllers.PersonController`,
and suffix JSON view modules with `JSON`, so prefer `Web.PersonJSON` over `Web.SSO.PersonView`,
placing them in the controllers directory.

## Domain vocabulary and accurate names

#### Match Each Layers Vocabulary

Match each layer's domain vocabulary, shifting terms at layer boundaries. A controller's
`total` can become a database `count`. Avoid terms that clash with an established domain
connotation, such as `role` in an RBAC context.

#### Name Things Accurately

Name things for what they actually are, not an incidental or misleading label. Name a
token or identifier by its real source, such as `Okta`, not a role label like `admin`.
Name an authorization pipeline by what it protects, not by the client library used to
reach it. Call a plain `Plug.Conn` assign `data`, not `metadata`. Name a type for what the
data is, not how it was obtained. Name an error reason for what actually failed.

#### Name Request And Response Types

Name API request and response types by their role. Suffix a response value or schema so it
reads as one, for example a `_response` variable or a `*Response` schema, to keep it
distinct from a database record, and reserve `*Request` schema modules for request bodies.
Keep a canonical field name such as `inserted_at` in serialization rather than renaming it
on the way out.

## Tests

#### Prefix Mox Mocks With Mock

Name [**Mox**](https://hexdocs.pm/mox/Mox.html) mocks with the `Mock` prefix, after the concrete module they replace, for example
`MockGPG`. Scope the mock to its context, such as `Core.MockGPG`, and refer to it by its
real name rather than aliasing it.

#### Name Test Constants Searchably

Give test constants specific, searchable names so a project-wide search reveals where they
are set.

#### Name Denied Authorization Cases

Name authorization test cases with `denied` rather than `not_allowed`.

## CI

#### Name CI Jobs By Scope

Name CI jobs for their actual scope. Reserve version-matrix names for jobs that genuinely
test multiple versions.
