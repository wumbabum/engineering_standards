# Idioms

Scope: The preferred, concrete way to write common things in our Elixir. Some of this
overlaps with **Credo**'s refactoring and readability checks (`Credo.Check.Refactor.MapInto`,
`FilterCount`, `Nesting`, and the readability checks we enable per repo), and several rules
below are candidates for custom Credo checks tooling does not ship: bracket access on a
keyword list, `Decimal.from_float/1`, legacy route helpers over `~p`, and `Enum.into(_, %{})`
where `Map.new/1` fits. The rest is reviewer judgment. This is the do-this collection; its
siblings hold the hazards (`anti-patterns.md`), the reasoning (`principles.md`), and
control flow (`control-structures.md`).

## Enum, Stream, and building collections

#### Find The First Match
Use `Enum.find/2` to get the first matching element instead of filtering then taking the
head.

#### Filter With Captures
Prefer `Enum.filter/2` or `Enum.any?/2` with the capture operator over a manual
multi-step pipeline that reconstructs the same result.

#### Build Collections In One Pass
Build a collection in a single pass with a mapper rather than enumerating and then
converting. Reach for `Map.new/1` instead of `Enum.into(enum, %{})`, and `MapSet.new/2`
with a mapping function instead of mapping and then building the set.

#### Each When Discarding Results
Use `Enum.each/2` rather than `Enum.map/2` when you do not need the results, so you do not
accumulate a throwaway list.

#### Join Delimited Output
Use `Enum.join/2` to assemble delimited output instead of special-casing an empty accumulator.

#### MapSet For Membership Checks
Use a `MapSet` for set-membership checks instead of sorting or subtracting lists, which
avoids forgotten-sort bugs.

#### Reduce Over Manual Recursion
Prefer `Enum.reduce/3` over hand-written recursion when folding a set of conditions or values
into a result.

Prefer:
```elixir
Enum.reduce(params, query, fn param, query -> apply_param(query, param) end)
```

Over:
```elixir
defp build(query, []), do: query
defp build(query, [param | rest]), do: query |> apply_param(param) |> build(rest)
```

#### Avoid List Subtraction When Lists May Contain Duplicates
`Kernel.--/2` removes only the first matching occurrence of each element, so `list -- to_remove`
silently leaves duplicates behind when the left list repeats a value. Reach for a membership
check with `Enum.reject/2` when the left side may contain duplicates.

```elixir
Enum.reject(locations, fn location -> location.zone in zones_to_remove end)
```

## Maps and keyword lists

#### Single Line For Small Literals

Keep a small literal on one line. When a sigil, list, or map holds fewer than three elements,
write it inline, and break it across multiple lines only once it reaches three or more elements
or grows too long to read on one line. This keeps trivially short collections from eating
vertical space.

#### Update Or Default In Place
Use `Map.update/4` to update-or-default a key in place instead of extracting the value,
transforming it, and recombining variables.

#### Seed Defaults With Put New
Use `Map.put_new/3` to seed a default in a params map, and merge params over a defaults map
so downstream code can use dot access rather than `Map.get` everywhere.

#### Deep Merge Nested Maps
Remember `Map.merge/2` replaces top-level values only. Use an explicit deep merge for
nested maps.

#### Read Options Through Keyword
Read options through the `Keyword` module, never bracket access or an order-sensitive
pattern match. Use `Keyword.get/2` and `Keyword.has_key?/2` rather than matching a keyword
list, whose key order is significant.

#### Fetch Required Options
Fetch required options with `Keyword.fetch!/2` so they fail fast at the source, and give
optional ones defaults with `Keyword.get/3`.

```elixir
def send(payload, opts \\ []) do
  message = Keyword.fetch!(opts, :message)
  type = Keyword.get(opts, :type, "default")
  # ...
end
```

#### Opts As Trailing Keyword List
Accept `opts` as a trailing keyword list, not a map and not a fixed keyword pattern.

#### Uniform Keyword Key Types
Keep keyword-list keys uniformly atoms or strings, never mixed.

#### One Place Per Value
Do not accept the same value as both a positional argument and an `opts` key; expect it in
exactly one place.

#### Forward Options With Take
Forward only the relevant options to a downstream call with `Keyword.take/2`.

#### Convert External Keys With String.to_existing_atom
When you must turn incoming string keys into atoms, use `String.to_existing_atom/1` so untrusted
input cannot exhaust the atom table. This is the safe companion to the anti-pattern against
creating atoms from external input: convert only to atoms that already exist.

## Structs, strings, and sigils

#### Preserve Struct Type On Update
Preserve a struct's type when updating it with `%Struct{existing | field: value}`.

#### Nil-Safe Bracket Access
Rely on Elixir's bracket access returning `nil` on `nil` so nested access does not raise.

#### To String Via Protocol
Convert basic data to strings with `Kernel.to_string/1` through the `String.Chars`
protocol, including atom-to-string, where protocol dispatch is fast.

#### Sigil For Quoted Strings
Use the `~s` sigil to avoid escaping quotes in strings such as test descriptions.

#### Word List Sigils
Use `~w()a` for atom word lists and `~w()` for string word lists.

#### Charlist Sigil For Erlang
Use `~c"..."` when an Erlang API needs a charlist and you want it distinct from a string.

#### Convert Only Nil Explicitly
Convert only `nil` explicitly rather than collapsing every falsey value to `nil`.

#### Membership Check For Sentinels
Test against several sentinel values with a membership check, for example `value not in [nil, ""]`.

#### Path And URI Modules
Build and manipulate paths and URLs with the `Path` and `URI` modules, not manual string
handling or concatenation, so redundant slashes and encoding are handled for you.

Prefer:
```elixir
Path.join(["/", client_slug, sub_client_slug, path])
base |> URI.parse() |> URI.append_query(query) |> URI.to_string()
```

Over:
```elixir
"/" <> client_slug <> "/" <> sub_client_slug <> "/" <> path
base <> "?" <> query
```

#### Decimal From String
Prefer `Decimal.new/1` with a string over `Decimal.from_float/1` to avoid float inaccuracy.

#### Derive Jason.Encoder With An Explicit only:
For a struct you own, derive **Jason**'s encoder with an explicit `only:` field list rather than
encoding every field, so a field added later is not accidentally leaked into a response or log.
`Jason.Encoder` must be implemented explicitly for structs anyway; make the field set deliberate.

```elixir
@derive {Jason.Encoder, only: [:id, :status]}
defstruct [:id, :status, :internal_token]
```

## Functions: capture, delegation, and arguments

#### Capture To Parameterize Behavior
Pass named functions as values with the capture operator to parameterize behavior instead
of duplicating clauses.

#### Anonymous Capture For Type Checker
Use the `&fun(&1)` capture form where the type checker rejects `&Module.fun/n`.

#### Delegate With Defdelegate
Use `defdelegate/2` for thin, logic-free delegation to another module rather than a
pass-through function that adds a layer without business logic.

#### Default Argument Over Arities
Prefer a single function with a default last argument over multiple arities. Drop a default
value that only tests exercise or that every caller already supplies, keeping defaults only
where later growth is plausible.

#### At Most Three Positional Parameters
Keep functions to at most three positional parameters. Group related arguments into a tuple
or an `opts` keyword list.

#### Consistent Argument Ordering
Keep argument ordering consistent across related functions.

#### Then For Non-Leading Argument
Reach for `Kernel.then/1` only to thread a piped value into a non-leading argument
position, not for branching and not to replace function-head pattern matching.

#### Format Every Clause Of A Function The Same Way
Give every clause of a function the same `do` style. If one clause uses a `do ... end` block
(or spans multiple lines), write every clause of that function that way rather than mixing the
`do:` shorthand with the block form.

#### Do Not Extract Trivial Pass-Through Helpers
Do not extract a helper that hides meaning without saving much, such as a one-line wrapper or a
`do_*` function that only delegates to another. Inline it instead, or, when you want the clauses
named, make the function public with multiple clauses rather than a private delegator. A pipeline
is allowed on a single line.

#### Guard Optional Dependencies With Code.ensure_loaded?
Wrap a module that uses an optional dependency in `if Code.ensure_loaded?(Dep) do ... end`, so it
compiles only when that dependency is present in the host application.

## Return values and error tuples

#### Standard Ok Error Tuples
Return standard `{:ok, result}`/`{:error, reason}` tuples and let a higher layer handle
failures.

#### Descriptive Error Reason Atoms
Use atoms for internal error reasons and reserve strings for front-end-facing values.
Include a descriptive reason atom, and context, to aid debugging, as in
`{:error, :failed_s3_upload, response: response}`.

#### Consistent Not Found Result
Use `{:error, :not_found}` consistently across the codebase for not-found results.

#### Consistent Return Types
Keep return types consistent within a function and across similar functions: either always
plain values or always tagged tuples, and if any path returns a tuple, every path does.

#### Wrap Third-Party Errors
Convert third-party errors such as `HTTPoison.Error` into your own declared return types
rather than passing them through unchanged.

```elixir
def report_payment(payment) do
  case HTTPoison.post(url, encode(payment)) do
    {:ok, response} -> {:ok, response}
    {:error, %HTTPoison.Error{reason: reason}} -> {:error, {:http_error, reason}}
  end
end
```

#### Accessors Return Value Or Nil
Make accessor and `get_by`-style functions return the raw value or `nil`, like
`Ecto.Repo.get_by/3`, not an ok/error tuple.

#### Bang Insert Over Elem
Prefer `Repo.insert!`, which returns the struct, over pulling a value out with `Kernel.elem/2`.

#### Return Tagged Reasons Not Parsed Strings
Branch on tagged tuples or atoms, never on the prefix of a human-readable, operator-facing string.
Return something like `{:cancel, {:transition_failed, next_state}}` and match the tag, stringifying
only at the boundary where an operator reads it. Parsing a display string for logic couples the two,
breaks silently when the wording changes, and misfires when another reason shares the prefix.

## Ecto: changesets

#### Changeset Data Through Params
Pass all changeset data, including associations, through the `params` argument rather than
as separate arguments.

#### Cast Over Put Change
Prefer `cast/3` or `put_assoc/3` over `put_change/3` for setting fields and associations.

#### Default Changeset Struct Parameter
Give a changeset function a first parameter defaulting to the module struct for the current
data, as in `def changeset(data \\ %__MODULE__{}, params)`.

#### Insert Through Validated Changeset
Insert records through a validated changeset, not a raw struct.

#### Prefer Built-In Ecto Features
Use built-in [**Ecto**](https://ecto.hexdocs.pm/Ecto.html) features
such as `cast_embed/3` instead of reinventing them, and omit `with:` when the default
changeset function applies.

## Ecto: queries

#### Ecto Multi For Transactions
Use [**Ecto.Multi**](https://ecto.hexdocs.pm/Ecto.Multi.html) for multi-step database work that must run in one transaction.

#### Composable Query Functions
Design query functions to accept a composable queryable or scope and build them from
composable functions like `or_where/3`, so larger queries can be assembled from pieces.

#### Named Query Bindings
Use named bindings in queries; their order in `preload` and `where` is not significant.

#### Preload Instead Of Join
Use `:preload` to load associations rather than adding an explicit join when you are not
filtering on them.

#### Force Preload Stale Associations
After creating related records, force-preload (`preload ..., force: true`)
or reset stale associations so callers never read outdated data.

#### Last For Most Recent
Use `Ecto.Query.last/2` to fetch the most recent record instead of ordering manually.

#### Exists Over Fetching
Use `Repo.exists?/2` to check existence instead of fetching records when record data is not needed.

#### Join To Filter Associations
Filter to records that have an association with a join rather than post-filtering in Elixir.

#### Error Key On Unique Constraint
Use Ecto's `:error_key` option on `unique_constraint` to attribute a compound uniqueness
error to one key.

```elixir
changeset
|> unique_constraint(:email, name: :users_client_slug_email_index, error_key: :email)
```

#### UUID Column Types
Use UUID column types for UUID identifiers, via shared schema helpers, rather than integers.

#### Prevent Get-Then-Insert Races With Upserts
A get-then-insert pair races: two concurrent requests both read `nil`, both insert, and the second
fails the uniqueness constraint. Let PostgreSQL resolve it with an upsert, and add an index on the
conflict target to support it. With `on_conflict: :nothing` the returned struct has a `nil` id on
conflict, so re-fetch the record.

```elixir
with {:ok, _} <- Repo.insert(changeset, on_conflict: :nothing, conflict_target: :external_ref) do
  Repo.get_by(User, external_ref: external_ref)
end
```

## Ecto: streaming and bulk operations

#### Stream Large Result Sets
Use `Repo.stream` for large result sets, run it inside a transaction, and consume it with
`Stream.each`/`Stream.run` so you never load everything into memory. Note the streaming
behavior in the function's `@doc`.

#### Bulk Insert And Update Rules
With `Repo.insert_all` you must set `id`, `inserted_at`, and `updated_at` yourself.
`Repo.update_all` is a single, implicitly-transactional statement, so partial completion is
impossible. Batch large mutations, for example around 500 rows per transaction.

#### Handle Update Error Result
Handle `Repo.update/1`'s `{:error, changeset}` result rather than silently discarding it.

## Ecto: migrations

#### Irreversible Migration Up And Down
For an irreversible data migration, keep `up/0` and `down/0` rather than `def change`, and
let `down/0` be a no-op or raise `Ecto.MigrationError` so a rollback alerts developers.

#### Wrap Migration Mutations In Transaction
Wrap data-mutating operations such as `update_all` in a `Repo.transaction`.

#### Large Migration Timeout
Set a large or infinite timeout on long-running migration transactions, since the default
is 15 seconds.

#### Concurrent Index Migrations
For `CREATE INDEX CONCURRENTLY`, disable the migration's DDL transaction lock and
`drop_if_exists` first, so a failed invalid index can be recovered on rerun.

#### Raw Table Names In Migrations
Query by the raw string table name rather than schema modules that may drift.

#### Drop Constraint Before Recreating
Drop an existing foreign-key constraint before recreating it with changed reference options.

#### Separate Schema Changes From Data Backfills In Migrations
Do not both add a column and backfill it in one migration. Split adding the column and backfilling
its values into separate migrations, and create any supporting index concurrently in its own
transaction-less migration (see "Concurrent Index Migrations").

## Macros and DSLs

#### Omit Parentheses From DSL Macro Calls
Write DSL macro calls without parentheses: router `plug`, `pipe_through`, and `get`; **Ecto**
`field`; **Absinthe** `value`, `arg`, `resolve`, `serialize`, and `parse`; and **OpenApiSpex**
`operation`. Once the DSL's library is listed in `import_deps` in `.formatter.exs` (see tooling),
the formatter stops injecting the parentheses. Parentheses on these calls are a sign of an older
app written before the deps were imported.
Starting an **Ecto** query with `from x in scope,` likewise lets the formatter handle the rest
without wrapping parentheses.

## Phoenix and Plug

#### Verified Route Sigils
Use verified route sigils (`~p`) instead of legacy `Routes.*_path` helpers, and do not
interpolate into a static `~p` path.

#### Declare Component Attributes
Declare component attributes with `attr` so required assigns are validated at compile time.

#### Empty HEEx Template
Return `~H""` for an empty HEEx template rather than an empty `~H` heredoc.

#### Only Needed Response Formats
Configure controllers with only the response formats they actually use.

#### App-Wide Plugs In Endpoint
Register app-wide plugs in the Endpoint, not the Router.

#### Extensible View Render Clauses
Design view render clauses to be extensible through pattern-matched template and assigns.

#### Pipeline Of Small Plugs
Compose plugs as a pipeline of small plug functions so a halted conn skips later steps and
their side effects.

#### Framework-Managed Halted Conns
Let the framework manage halted conns: handle an already-halted conn in a dedicated `call/2`
clause, or run child plugs with `Plug.run/3`.

#### Halt After Sending Response
Call `Plug.Conn.halt/1` after a plug or fallback clause sends a response mid-pipeline when
the conn may be used later.

#### No Passthrough Conn Helpers
Do not accept or return `conn` in a helper that neither reads nor modifies it.

#### Action Fallback Controller
Use `action_fallback` with a `FallbackController` so actions can return error tuples instead
of rendering errors inline per action.

#### Standard HTTP Header Names
Use standard lowercase, hyphenated HTTP header names, and do not support underscore variants
or multiple casings.

#### Reuse Existing Library Functions
Prefer existing library functions and framework callbacks
(`Plug.Conn.get_req_header/2`, `HTTPoison.Base`) over reimplementing their behavior.

## GraphQL schemas

#### Non Null In Absinthe
In [**Absinthe**](https://hexdocs.pm/absinthe/Absinthe.html) schemas, mark fields and args `non_null` when they always carry a value, use
`non_null(list_of(non_null(...)))` for lists whose elements are always present, and pair
`non_null` args with `default_value` so an explicit `null` is rejected.

## Oban jobs

#### Args Schema For Workers
Define an `args_schema` for [**Oban Pro**](https://oban.pro/docs/pro/overview.html) workers. It casts args to a struct with atom keys, so
match the struct rather than string keys.

#### Avoid Extra Queues
Avoid creating extra queues unnecessarily, since each queue consumes PostgreSQL connections.

#### Return Values Control Retries
Use return values to control retries: return an error tuple to retry a temporary failure,
and `{:cancel, reason}` to stop without retrying.

#### Enqueue Follow-Ups On Success
Do not enqueue a follow-up job on `:error`; enqueue it only on success, or it re-runs on
every retry attempt.

#### Keep After Process Light
Keep `after_process` light. It receives hook states (`:snooze`, `:cancel`, `:complete`,
`:discard`, `:error`), and any substantial business logic or new network call belongs in a
dedicated retryable job instead.

#### Idempotent Retryable Writes
Make retryable writes idempotent by re-fetching and skipping when the target field is
already set.

#### Do Not Serialize Large Data Into Job Return Values
A worker's return value is persisted onto the Oban job row, so return `{:ok, data}` only for small,
interesting data. Do not serialize a large record set into the return value; log the per-record
outcome instead and return `:ok`. On sad paths, log an error and return `:ok` as well.

## Logging metadata

#### Individual Metadata Keys
Add searchable log values as individual `Logger.metadata` keys, grouped under a category
when narrowly scoped, rather than nesting them inside `params`.

#### Set Metadata At Entry Point
Set metadata with request identifiers at the highest entry point of a flow so every
downstream log carries them.

#### Reset Metadata In Spawned Processes
Re-set metadata inside spawned processes, since it is not inherited.

#### Maps Before JSON Encoding
Convert `Logger.metadata` keyword lists to maps before JSON encoding, since tuples have no
JSON encoder.

#### Emit Through Logger
Emit output through `Logger` so entries are structured JSON, not bare `IO`.

#### Reuse Provided Metadata
Reuse library-provided metadata such as request id rather than re-setting what an upstream
call already set; set only what is genuinely yours, for example a `client_slug`.

#### Airbrake Notice Fields
When reporting to **Airbrake**, use its notice fields per the API, putting freeform data in
`params` rather than `context`.

The reason is that the notice's `context` has specific reserved fields, most of which the
reporting client library sets for you; it is not a freeform bag. The freeform slots in the API
(`params`, `environment`, `session`) are biased toward HTTP requests, so for background-job and
error detail the least-bad fit is `params`. Putting error detail in `context` fights the API and
can collide with library-managed fields.

```elixir
Airbrake.report(exception, stacktrace, params: %{job: job_name, args: args})
```

## Comments and constants

#### Reference Jira In Comments
Mark deferred or temporary code with a plain comment that references the Jira ticket which
will address it, so a project-wide search finds it.

#### Extract Constants To Attributes
Extract repeated hardcoded values and magic numbers into named module attributes, and expose
a shared list through a public accessor so callers and tests never duplicate the literal.

#### Sort Literal Lists Alphabetically
Keep literal value lists and enum lists sorted alphabetically.

#### Inline Single-Use Values
Inline a local variable or module attribute that is read once and does not clarify intent. An
explanatory name earns its place only when it makes the code easier to read; a bare pass-through
does not. This is the counterpart to "Extract Constants To Attributes", which covers reused values.

#### Reference Functions As Module.fun/arity In Docs And CHANGELOG
Name functions as `Module.fun/arity`, with the slash-arity and no argument list, in `@doc`,
`@moduledoc`, and CHANGELOG entries, so ExDoc can link them into the generated documentation. Write
`CBRelay.Engine.patch/1`, not `Engine.patch(conn)`.
