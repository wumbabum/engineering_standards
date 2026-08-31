# Unit testing

Scope: Judgment and practice for **[ExUnit](https://hexdocs.pm/ex_unit/ExUnit.html)** tests: test data, assertions, mocks and Mox,
setup and context, structure, and what to cover. It overlaps with `mix format` (setup and
assertion layout) and with **Credo**. Candidates for custom **Credo** checks: a committed `:focus`
tag, a test file without the `.exs` extension, `is_nil/1` in an assertion where `== nil`
reads better, `setup` returning an `:ok` tuple instead of a keyword list, module attributes
used for test data, and custom assertion messages on `assert/1`. The rest is reviewer
judgment that tooling cannot enforce.

## Test data

#### Keep Test Data Inline

Keep test data in the test. Inline literal values at their point of use, or build shared
values in `setup`/context and read them back by pattern match, rather than hiding data in
module attributes or macros. Tests read as documentation.

#### Favor Readability Over DRY

Favor readability over DRY. Some duplication in tests is fine. Inline short helper
functions and simple values, build small structs directly, and reserve extraction for
genuinely complex data rather than obfuscated setup helpers.

#### Use Realistic Typed Data

Use realistic, correctly-typed test data: real UUIDs and `DateTime`s rather than
placeholders, conventional values consistent with the rest of the suite, realistic values
at least for the top levels of nested structures, arguments that mirror how the function is
actually called, and only the parameter forms the app produces at runtime. Design the data
to actually exercise the behavior under test.

#### Build Through Shared Factories

Build test data through shared factories rather than local ad-hoc helpers. Pull large
fixtures from shared schema examples, place construction in shared factory or context
modules, and rely on the case template to import them. Prefer factory functions called
within a test over `setup` when tests frequently override values, and set a field
explicitly only when you assert on it. Construct a struct from a base with update syntax
that names the struct, as in `%OktaConfig{base_config | url: url}`, to preserve its type.

#### Use Representative Expected Values

Use real, representative expected values. Derive them from the schema's example data or
from the test's own actual output, keep them literal rather than recomputed, and reuse
consistent example values across schemas and docs, especially ids known to be equal.

## Assertions

#### Match Assertion Breadth To Test

Match the assertion's breadth to the test. On the happiest-path test assert the full
expected value, the whole struct or map, including its concrete type so type regressions
surface. On edge or secondary tests assert only the fields that matter. Do not over-assert,
do not re-assert what the happy-path test already covers, do not assert a value's type when
you already assert its value, and do not give each simply-passed-through field its own test.

#### Condense Into Pattern Match

Condense related field assertions into a single pattern-match assertion, using `match?/2`
or a pinned `^var` pattern, rather than many separate equality checks. Wrap pattern matches
in `assert` for better failure messages, as in `assert %User{id: ^id, role: :admin} = result`.

#### Assert Meaningful Outcomes

Assert on meaningful outcomes: the actual persisted state or side effects rather than just
a success response, the specific error reason rather than a wildcard, and the changeset
itself for clearer failures, as in `assert %Changeset{valid?: true} = changeset`. Do not
assert a return that is always the same value like `:ok`.

#### Remove Redundant Assertions

Remove assertions and tests made redundant by a stronger later assertion or by another
test. Do not repeat coverage that varies no input the code uses, assert cross-cutting
behavior once and keep other tests focused, and omit tests that duplicate a case without
adding contrast.

#### Follow Assertion Operator Conventions

Follow assertion-operator conventions. Use `=` only for pattern matches, with the pattern
on the left. Use `==` with the actual on the left and the literal expected on the right.
Prefer `== nil` over `is_nil/1` for clearer failure output, use the match operator for
`:ok`/`:error` tuples that mirror app code, and compare dates with `DateTime.compare/2`
rather than direct equality.

Prefer:
```elixir
assert Keyword.get(headers, :client_slug) == "cityville"
assert Auth.role(conn, :pos) == nil
assert DateTime.compare(lower, now) in [:lt, :eq]
assert [] == parent_domains("localhost")
```

Over:
```elixir
assert "cityville" == Keyword.get(headers, :client_slug)
assert Auth.role(conn, :pos) |> is_nil()
assert DateTime.compare(lower, now) == :lt
assert [] = parent_domains("localhost")
```

#### Write Clear Specific Assertions

Write clear, specific assertions. Keep them readable rather than clever and specific enough
not to match unrelated values. Capture separate concerns, such as a result and its logs,
separately instead of nesting them. Do not bury assertions inside mock anonymous functions,
inline a transformation when it reads better than an intermediate binding, bind a response
once for reuse across assertions, and skip comments that imply routine setup is
significant.

#### Express Membership And Negation Clearly

Express membership and negative assertions clearly. Use `x in collection` for membership,
and `not in` or `refute Enum.any?` for negation rather than an awkward negation.

#### Rely On Default Failure Messages

Rely on `assert/1`'s failure messages instead of adding custom explanatory assertion
messages.

#### Prefer Tests Over Loops

Prefer several small hard-coded tests over one loop that iterates cases. When you must
assert over a collection, use `Enum.all?` or a single query rather than burying `assert`
inside a loop.

#### Exercise The Real Thing

Make sure a test exercises the real thing. Construct expected values independently rather
than restating the code under test, call the real helper rather than reimplementing it,
test the actual triggering mechanism rather than a function that bypasses it, and do not
test code with no logic such as behaviour declarations or standard-library calls.

## Mocks and Mox

#### Prefer Expect Over Stub

Prefer **[Mox](https://hexdocs.pm/mox/Mox.html)** `expect/3` over `stub/3` so an uncalled mock fails the test. Put expectations
inside each test rather than a shared `setup`, do not mock calls that should not happen, and
make expected call counts explicit rather than relying on defaults. Reserve `stub/3` for
functions not under test.

#### Configure Mox Once

Configure **Mox** once at the top of the module with `setup :set_mox_from_context` and
`setup :verify_on_exit!` so expectations are verified on exit. Rely on `verify_on_exit!`
rather than adding unnecessary expectations.

#### Assert On Mocked Arguments

Assert on the arguments passed into a mocked function, at least once, inside the `expect/3`
callback. Check meaningful values such as Authorization headers or passed credentials, and
avoid helpers that hide the param assertions.

```elixir
expect(MockHTTPClient, :get, fn url, headers, _opts ->
  assert url == "the-service-url/api/v1/addresses"
  assert Keyword.get(headers, :client_slug) == "cityville"
  {:ok, response}
end)
```

#### Mirror Real Signature And Return

A mock must reflect the real function's signature and return the same shape and realistic,
identifiable values the real implementation returns, or it masks production bugs.
Sanity-check mocked data, and test the real behavior where it is implemented.

#### Mock At Low Boundary

Mock at a single, low boundary and cover the rest with real integration. Mock external
calls at the HTTP-client or library-base level rather than wrapping them in a behaviour,
mock a module's collaborators through a configurable indirection and leave its internals to
its own tests, run cheap operations like serialization for real, and include at least one
less-mocked end-to-end test since mocking can hide real bugs. Consider `stub_with` to
exercise the real path.

#### Order Expectations By Call

Order **Mox** expectations in the sequence they are actually called.

#### Prefer Mox For Mocking

Prefer **Mox** for mocking, since it mocks behaviours the right way. Define mocks with the mock
name first, define a per-app mock rather than sharing one across umbrella apps, call
`expect`/`stub` without the `Mox.` prefix when **Mox** is imported, chain `expect/3` calls on
the same mock into one pipeline, and use `stub_with/2` to delegate to the real
implementation when a test needs real behavior.

## Setup and context

#### Return Keyword List From Setup

Return a plain keyword list from **ExUnit** `setup`, not an `:ok` tuple or a map.

```elixir
setup do
  [
    token: create_token(),
    absinthe_context: build_context()
  ]
end
```

#### Format Setup Returns Vertically

Format setup return values one definition per line and keep them multi-line. List setup
functions vertically, since their execution order often matters.

#### Write Setup As Named Functions

Write setup steps as small named functions that accept the test context and return `:ok`,
invoked via `setup`/`setup_all`. Declare shared setup once at the top rather than per
describe block, pass a single callback as a bare atom, group functions by purpose rather
than one combined list, pull optional values from the context, and skip `@spec` on them in
favor of `@doc`. Extract repeated per-test setup, such as header building or record
insertion, into a shared helper.

#### Choose Tag Versus Setup

Use `@tag` to inject context for a single test and `setup` for context shared across a
describe block, remembering that `@tag` is evaluated before `setup`. Keep the test's
context and options on the same line as `test` so the formatter handles them well.

## Structure and naming

#### Prefer Small Focused Tests

Prefer several small, focused tests over one large test, and split distinct assertions into
separate tests so failures pinpoint one behavior.

#### Name Describes And Tests Clearly

Name describe blocks after the function and arity under test, name each test for the
behavior or status it asserts, and keep names unique so none silently shadows another. Name
test variables for what they hold rather than `expected`.

#### Organize Describes By Scenario

Organize describe blocks by scenario, with setup functions written from the business code
rather than shared helper soup. Combine describes that share the same setup, do not
over-describe distinctions that do not matter, and flatten nested describe intent into
separate tag-driven describe blocks.

## What to test

#### Cover Paths That Matter

Cover the paths that matter, not just the happy one. Give every public function a
happy-path test, and add tests for each error and edge return, the raising path with
`assert_raise` alongside the default-return path, the no-match path that would raise a
`MatchError`, missing-field validation, boundary and event-handler logic, and regression
tests that lock in behavior dependent on clause ordering. Exercise behavior like pagination
with varied inputs rather than static values.

#### Test Your Own Code

Test your own code, not your dependencies. Do not write tests that primarily exercise a
third-party library's behavior or re-verify what the library already tests. Test your app's
own integration and wiring of the dependency instead.

Besides being redundant, tests that exercise a dependency are brittle: they tend to break when
you upgrade Elixir, Erlang, or the library, and they can be flaky when they depend on behavior
you do not control (timing, log output, concurrency). Test the seam you own instead, for example
that a plug is wired into the router, not that the library behind it works.

#### Test Behavior Once Per Layer

Test each behavior once, at the lowest layer that owns it, then do not duplicate that
coverage upward. Assert details at the API or unit layer so controllers and downstream
consumers need only smoke tests, assert extracted shared behavior in its own module rather
than in every caller, keep each layer's tests to the cases its logic handles, add
end-to-end coverage where a behavior only manifests end-to-end, and keep cases that fail
before doing I/O in unit tests rather than manual scripts.

#### Test Through Public API

Test through the public API. Cover public functions, even trivial ones, and test private
functions indirectly through their public callers rather than exposing them just for tests.
When logic is hard to reach, extract it into atomic, testable functions out of controllers
and workers rather than making internals public.

#### Do Not Game Coverage

Do not game coverage. Never add production code or expose functions solely to hit a
coverage target, and never lower the threshold to accommodate new code. Add meaningful
tests or doctests for new modules instead, configure coverage at the umbrella level, exclude
thin library-wrapper lines rather than testing library behavior, and ensure a shared or
generic test covers any path not tested per-unit.

#### Use Doctests Deliberately

Use doctests deliberately. Register `iex>` examples with `doctest` and convert documented
function examples into doctests where feasible so they run, but do not rely on doctests as a
substitute for unit tests or overuse them for non-trivial cases. Remove `doctest`
declarations from modules that contain none.

#### Test Authentication Paths Honestly

Test authentication paths honestly. Include an unhappy-path and a 401 unauthorized test on
authenticated endpoints, set up the real-world auth scenario rather than a misleading mocked
one, and cover one variant fully while spot-checking the rest rather than exhausting every
combination.

## Logs

#### Capture Expected Log Output

Capture or suppress expected log output with `@moduletag :capture_log` (or
`capture_log: true`) rather than lowering log levels or wrapping the logger, so runs stay
signal-rich. Assert that expected log messages are emitted, especially after changing
behavior that logs.

#### Do Not Assert Message Wording

Do not assert on exact user-facing or log message wording, so copy can change without
breaking tests.

## Isolation and determinism

#### Set Async By Shared State

Set `async: true` for tests that share no global state and `async: false` for tests that
use globally-registered or shared resources. **ExUnit** runs async tests concurrently across
modules but serially within a module.

#### Use Shared DataCase

Use the shared `Core.DataCase` instead of manually checking out the **[Ecto](https://hexdocs.pm/ecto/Ecto.html)** sandbox, do not
duplicate setup it already provides, and seed or create the required database records before
asserting on database-dependent behavior.

#### Keep Tests Deterministic And Independent

Keep tests deterministic and independent. Never use `Process.sleep` to synchronize, add
fallback paths that hide failures, or rescue unexpected exceptions. Do not assume collection
ordering; filter by attribute rather than taking the first element. Never delete or mutate
global application configuration.

## Configuration in tests

#### Do Not Override Application Config

Do not override `Application` config in tests. Prefer dependency injection or **Mox**, and treat
`Application.put_env/3` as a smell. In a library, exercise configurations with `put_env` but
confine overrides to one module and hard-code config in consuming apps. Use fake values so
tests never make real external requests, mock all external requests with informative dummy
URLs, and read values that must stay in sync via `Application.get_env` rather than
hardcoding them.

## Framework specifics

#### Test Oban Workers Natively

Test **[Oban](https://oban.hexdocs.pm/Oban.html)** workers with the framework's own tools. Use `Oban.Pro.Testing` with
`testing: :manual` for **Oban Pro** workers, and assert job insertion with **Oban**'s
`assert_enqueued` rather than wrapping insertion in a behaviour to mock.

#### Use Verified Routes Everywhere

Use verified routes (`~p`) consistently, including in tests, such as `~p"/check/#{id}"`,
rather than legacy route helpers.

#### Guard Struct Types In Context

Guard struct and field types in the test context by pattern-matching the struct in
`setup`/context, so downstream field access type-checks without inline defensive matches in
each test. Nested fields type-check too when the whole shape is matched in the head, as in
`%{data: %Data{results: %Results{} = results} = data}`.

Prefer:
```elixir
test "sets orchestrator metadata", %{data: %Data{} = data} do
  # ...
end
```

Over:
```elixir
test "sets orchestrator metadata", %{data: data} do
  %Data{} = data = data
  # ...
end
```

## Tooling and hygiene

#### Pin And Verify Versions

Pin and verify dependency and runtime versions. Test applications against a single committed
Elixir/OTP version and reserve version matrices for libraries, pin CI matrix versions at the
minor level, and run CI against the versions used in production. Before upgrading a
dependency, add a test that passes against current behavior first.

#### Do Not Commit Focus Tags

Do not commit **ExUnit** `:focus` tags.

#### Name Test Files Exs

Name test files with the `.exs` extension so they run, and use strings rather than `~c`
charlists.

#### Remove Unused Test Bindings

Remove unused bindings from tests: values in `setup` or context that no test uses, and
variables that only raise compiler warnings.

#### Lint Shared Support Modules

Test support modules are shared with dependent umbrella apps just like application modules,
so run linters over them and match CI to local aliases. A library generally should not ship
functions meant solely as test setup callbacks.

#### Name Full Battery Alias

Name the mix alias that runs the full test battery `all_tests` for consistency across apps.
