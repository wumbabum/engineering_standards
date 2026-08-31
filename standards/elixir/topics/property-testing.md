# Property testing

Scope: Judgment and practice for property-based tests written with **[StreamData](https://hexdocs.pm/stream_data/StreamData.html)** and
**[ExUnitProperties](https://hexdocs.pm/stream_data/ExUnitProperties.html)**. It runs on **ExUnit**, so the unit-testing conventions still apply; the
rules here are specific to properties and generators. Little of this is auto-enforced.
Candidates for custom **Credo** checks: flag a test named `property` that does not use
`check all`, and flag generated bindings a property never uses. The `import StreamData`
formatter setup is a `.formatter.exs` concern, not a **Credo** one.

## When to reach for a property test

#### Assert Invariants Across Many Inputs

Reach for a property test when a behavior must hold across many inputs or shapes. A
property proven over all inputs beats a handful of examples, so use one to assert
invariants such as a scalar passing through unchanged, to exercise real data boundaries,
and when a test would otherwise build lots of similar data by hand.

```elixir
property "scalars are returned unchanged" do
  check all scalar <- one_of([integer(), float(), string(:utf8), atom(), boolean()]) do
    assert Utils.detuple(scalar) == scalar
  end
end
```

#### Prefer Properties For Combinatorial Logic

For combinatorial, logic-heavy rules such as authorization, prefer property tests. They
cover the data space in a way that a few examples cannot.

#### Exercise Variability Once Per Unit

Do not use a property test to iterate over a tiny fixed set of variations; that is an
example test. Do not duplicate a function's property coverage in its callers either.
Exercise a function's variability once, at its own unit.

#### Constrain Costly Database Properties

Property tests over DB records are costly. Use a plain example test when the property is
not important. When a property is genuinely slow, constrain it with `max_run_time` (and
`max_shrinking_steps` for DB-backed tests) rather than cutting the run count. Under the
Ecto SQL Sandbox, **ExUnitProperties** rolls back the transaction on each run, so no manual
transaction wrapper is needed.

## Replacing example tests

#### Retire Subsumed Example Tests

Once a property test covers a behavior, remove the example tests and generator length
limits it subsumes. Keep only genuinely distinct edge cases as separate example tests
when they do not fit the property.

#### Name Property Only With Check All

Name a test `property` only when it uses `check all`. Otherwise name it `test`.

## What generators should produce

#### Do Not Cap Generator Sizes

Do not artificially cap generator sizes. Exercise empty and large collections unless a
real cost forces a limit, such as capping length to avoid n+1 database inserts.

#### Constrain Only For Preconditions

Constrain a generator only to satisfy the function's preconditions, for example
`min_length: 1`. Once you do, drop the guards that becomes redundant, such as explicitly
rejecting the empty list. Include the empty case whenever it is a valid input.

#### Give Strings A Minimum Length

Give generated strings a small minimum length, around 3 (for example
`string(:alphanumeric, min_length: 3)`), so values are not easily overlooked or hidden
when debugging.

#### Span Every Branch With Members

Generators should span every branch the code handles. Prefer `member_of/1` or `one_of/1`
over a realistic, safe value set, including all valid enum values, rather than generating
arbitrary atoms.

#### Reflect Realistic Domain Values Simply

Build dedicated generators that reflect realistic domain values across all categories, but
keep them simple. Vary only the inputs that actually change behavior.

#### Control Distribution With Frequency

Control the distribution of generated values with `frequency/1` rather than `one_of/1`.
Exercise `nil` in nullable fields through a shared frequency-based helper that occasionally
yields `nil`, overridable to force a non-nil value per test.

Prefer:

```elixir
def change_value do
  frequency([
    {1, constant(nil)},
    {9, string(:alphanumeric)}
  ])
end
```

Over:

```elixir
def change_value do
  one_of([constant(nil), string(:alphanumeric)])
end
```

#### Derive Dependent Values From One

Derive dependent or equal generated values from a single earlier generated value rather
than generating them independently.

Prefer:

```elixir
gen all kind <- member_of(["email", "phone"]),
        value <- contact_value(kind) do
  %{kind: kind, value: value}
end

defp contact_value("email"), do: repeatedly(&Faker.Internet.email/0)
defp contact_value("phone"), do: repeatedly(&Phone.EnUs.phone/0)
```

Over:

```elixir
gen all kind <- member_of(["email", "phone"]),
        value <- phone_number() do
  %{kind: kind, value: value}
end
```

When two fields must be equal, reuse the single binding rather than generating a second
value, for example `%{id: id, constituent_id: id}`.

## Writing and organizing generators

#### Override Fields With Named Options

Write generators that take explicit named options to override individual fields. Accept
alternate streams through `Keyword.get/3` or `Keyword.get_lazy/3` rather than tunneling an
`opts` bag down into nested generators.

```elixir
def user(opts \\ []) do
  gen all name <- Keyword.get(opts, :name, string(:alphanumeric, min_length: 1)),
          role <- Keyword.get(opts, :role, member_of([:read, :write])) do
    %User{name: name, role: role}
  end
end
```

#### Use Built In Generators Directly

Use **StreamData**'s built-in generators, such as `boolean()`, instead of hand-rolling
equivalents like `member_of([true, false])`. Reference them directly, since
`use ExUnitProperties` imports **StreamData** (or `import StreamData` where it does not).
Never wrap a plain value in `constant/1` where a real generator or value is expected;
`constant/1` yields a stream, not a value.

#### Register StreamData In The Formatter

Add `:stream_data` to the imported deps in `.formatter.exs` so `gen all` and `check all`
can omit parentheses.

```elixir
# .formatter.exs
[
  import_deps: [:stream_data],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
```

#### Centralize Generators In One Module

Keep test-data generators in a single `Generator` module and lean on them broadly. Expose
bang helpers such as `admin!/1` for record setup, use `StreamData.pick/1` on a generator as
a lightweight factory, and move repeated specific construction into a shared generator.

#### Produce Params Not Records

Generators should produce params only. Insert records inside the test's rolled-back sandbox
transaction, not inside the generator.

An insert done inside a generator runs outside the test's rolled-back transaction, so those
records accumulate across every property-test iteration. That leads to spurious uniqueness
violations, false test failures, and hard-to-debug state that depends on iteration order. Keep
the generator pure (params only) and insert inside the transaction so the sandbox rolls the
records back between iterations.

#### Inline Generators And Remove Unused Bindings

Inline generators directly in the property test where the codebase already does so, and
remove generated bindings the test never uses.
