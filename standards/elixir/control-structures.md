# Control structures

Scope: Judgment for choosing and shaping `with`, `case`, `cond`, `if`/`unless`,
function clauses, guards, and pipelines. Some of this overlaps with **Credo**'s readability
and refactoring checks (nesting depth, negated conditions, boolean-operator misuse, `with`
anti-patterns), and several rules below are candidates for custom or enabled **Credo** checks:
no-op `with` else clauses, single-step pipelines, `not in` guards, and `&&`/`||` used for
boolean logic. The rest is reviewer judgment that tooling cannot enforce.

## `with` chains and their `else`

#### Sequence Fallible Steps Using With

Use `with` to sequence fallible steps and to replace nested `case` expressions. Extract a
private function per step so the happy path reads straight down the `with` and each step
translates its own errors. This collapses the duplicated `{:error, _}` passing that nested
`case` expressions force on you.

```elixir
with {:ok, merchant} <- fetch_merchant(params),
     {:ok, payment} <- submit(merchant, params) do
  render(payment)
end
```

#### Reserve With For Result Tuples

Reserve `with/1` for chains of `:ok`/`:error` tuples, where you are operating under
uncertainty. Reserve pipelines for transforming a state struct through steps that do not
fail. Forcing a pipeline to thread uncertainty is tricky and grows complicated over time.

#### Skip With Without Pattern Matching

Do not reach for `with` when no pattern matching or failure branching happens. If nothing
is being matched, use `=`. For a single condition, use a plain `if`; for a one-clause
`with`, a simpler construct communicates the flow better.

#### Keep With Else Minimal

Keep the `else` minimal. Drop a no-op `else` that only returns what it received: a `with`
without `else` already returns a non-matching value unchanged, so the clause is redundant,
and a pass-through `else` can convert a returned error into a `WithClauseError` crash.
When error handling is real, extract it into local functions that return their own
`:error` tuples rather than growing a complex `else`.

#### Keep With Bodies Flat

Keep `with` bodies flat. Do not nest a `case` inside a `with` body, and do not call
**Logger** in `<-` clauses. Push that work into named helper functions; a **Logger** call in a
match clause is a smell.

#### Future Proof With Expected Matches

Keep a `with` that matches the expected returns even when the call currently always
succeeds. It future-proofs the code by forcing a revisit here if that contract ever
changes.

#### Assert Types Inside With Clauses

Put type-asserting pattern matches inside `with` clauses rather than on bare variables or
in over-deconstructed function heads.

```elixir
with %AutopayAgency{} = agency <- socket.assigns.selected_autopay_agency do
```

## Choosing between `case`, `cond`, `if`, and `unless`

#### Prefer Single Case Over Ifs

Use a single `case` over a value instead of repeating multiple `if` checks against that
same value.

```elixir
case config_env() do
  :prod -> ...
  :dev -> ...
  :test -> nil
end
```

#### Use Cond For Boolean Branches

Use `cond` for multi-branch boolean logic rather than a large nested `if`/`else` block.

#### Use If Else For Assignment

Use a multi-line `if do:/else:` expression for simple conditional value assignment instead
of imperative reassignment. Treat it as the Elixir stand-in for a ternary.

```elixir
status =
  if invoice.paid_at,
    do: :paid,
    else: :pending
```

#### Prefer Case Over Then

Prefer a `case` over `Kernel.then/1` for branching on a result. `case` is the more common
and more readable form for this.

## Pattern matching over conditionals

#### Dispatch Via Pattern Matched Clauses

Handle distinct cases with separate pattern-matched function clauses rather than branching
inside one clause, and match in the function head instead of a `case` when the branch keys
off a single parameter. Replace Rails-style conditional dispatch with a private function
that pattern-matches its input, and prefer function-head clauses over a module-attribute
map for a simple keyed lookup.

#### Match Structs In Function Heads

Pattern-match structs in function heads for compile-time safety on field access, and skip
redundant field lookups the matched struct already guarantees.

```elixir
def call(%Topic{} = topic, message, context) do
  # topic.client_slug is confirmed safe at compile time
end
```

#### Extract First Element By Pattern

Extract a list's first element with a function-head pattern and a shape guard rather than
`List.first` plus `Map.get`.

```elixir
defp get_account_status_code([%{} = item | _]), do: ...
```

#### Single Clause For Simple Booleans

Prefer a single function clause with a boolean expression over multiple pattern-matched
clauses when the logic is simple boolean logic and one line says it clearly.

#### Keep Head Matches Minimal

Keep matches in `case` and function heads minimal, and destructure further in the body.
Use `_` for values when matching only on keys, since the keys already give the context.

## Function clauses: ordering, combining, and fallbacks

#### Order Clauses Deliberately And Consistently

Order function clauses in a deliberate, consistent sequence, and keep that order the same
everywhere the function appears. The order is not always alphabetical; choose the order in
which the cases should be considered.

#### Combine Identical Clauses With Guards

Combine clauses that share identical logic into one, using a guard such as `in` a list
where the shared cases differ only by value.

```elixir
defp authorized_agencies_for_role(role, _conn) when role in [:cb_admin, :client_admin] do
  :all
end
```

#### Add Fallback Clause For Fallthrough

Add a fallback clause to return a default rather than special-casing inside another
clause, and always handle the fallthrough so a request returns an error (for example a
422) instead of crashing into a 500. Handle a `nil` from `Repo.one` explicitly.

#### Return Directly Not Through Case

Do not wrap a value in a `case` whose clauses each return themselves; return the result
directly.

#### Omit Clauses For Impossible Values

Do not add clauses for return values that cannot occur. Handle only the cases the typespec
or the callback contract documents, and collapse to a single clause when the value's type
is already constrained.

## Guards

#### Reject Invalid Input With Guards

Use guard clauses to validate and reject invalid input early.

#### Extract Preconditions Into Defguard

Extract reusable boolean preconditions into guards with `defguard` so heads stay readable.

#### Prefer Positive Over Negated Logic

Prefer positive logic over negated conditions, since negated logic is harder to reason
through. Use positive guards (`in`) over `not in`, and reorder the clauses so the positive
form comes first. Prefer `length/1` and positive checks over their negations.

#### Constrain Broad Tuple Patterns

Constrain broad tuple patterns with guards so a clause matches only the intended shapes.
A head like `walk({type, content}, ...)` matches every 2-tuple; narrow it so a stray
`{1, 2}` cannot slip through.

## Boolean logic

#### Use And Or For Booleans

Use `and`/`or` for boolean computations, and reserve `&&`/`||` for returning non-boolean
values. This is the opposite of most other languages.

```elixir
if assigns[:internal_device_identifier] != nil and assigns[:dps_status] == "Enrolled" do
```

#### Order Conditions For Short Circuiting

Order boolean conditions so the cheaper or more likely check runs first and benefits from
short-circuiting.

## Pipelines and `|>`

#### Chain Transformations Through Pipes

Chain sequential transformations through the pipe operator instead of naming intermediate
variables.

#### Avoid Single Step Pipelines

Do not use a pipeline for a single step. Call the function directly; a one-step pipe is
harder to read, not easier.

#### Keep Side Effects Visible

Do not hide an important side-effecting call at the end of a pipeline. Keep such calls
visible so a reader does not miss them.

#### Chain Case Into The Pipeline

Chain a `case` into the pipeline with `|> case do` rather than breaking the pipe to hold a
variable. Keep the whole flow in one pipeline, with each branch returning its value.

```elixir
result
|> Repo.update()
|> case do
  {:ok, record} -> ...
  {:error, changeset} -> ...
end
```

## Control flow shape: flatten and extract

#### Flatten Nested Control Flow

Flatten nested `case`/`if` control flow into separate function clauses or extracted
helper functions. A body that nests `case` inside `if` inside `case` is hard to test and
hard to read; small named functions and pipes make the flow visible.

#### Separate Normal Flow From Errors

Separate normal flow from error handling. Delegate the branches to small named helper
functions so an `if/do/else` reduces to simple calls and can use the keyword `do:`/`else:`
notation.

```elixir
def call(conn, opts) do
  if static_token?(conn, opts),
    do: process_static_token(conn, opts),
    else: process_jwt(conn, opts)
end
```

## Recursion and fail-fast

#### Base Cases As Separate Clauses

Implement recursive base cases as separate function clauses instead of branching inside
the recursive body.

#### Validate Up Front Not Recursively

Validate inputs up front and return `{:ok, _}`/`{:error, _}` or fail fast. Do not recurse
to backfill missing params; a recursive call that depends on a match that never becomes
true loops forever.

## Exceptions and the error contract

#### Match Raising Behavior To Contract

Match a function's raising behavior to the contract its callers rely on. If callers treat
it as returning `{:ok, _}`/`{:error, _}`, use non-bang calls (or a targeted `rescue`) so
it never raises past that contract, and rescue only the specific exception you expect
rather than a bare `rescue` that swallows everything.
