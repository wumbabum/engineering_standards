# Principles

Scope: The design philosophy behind the concrete rules in the rest of this collection. This is the WHY. It is almost entirely reviewer judgment with little tooling overlap; the closest a linter comes is dependency hygiene, where a mix dependency check can flag direct dependencies that are not declared. Its siblings hold the how: `idioms.md` for do-this patterns and `anti-patterns.md` for avoid-this hazards.

## Designing for failure

#### Let Unexpected States Crash

We build on the BEAM, so we let it do its job. Under supervision, let unexpected states crash rather than smothering them in defensive catch-all clauses. Use guards and pattern matching to state the invariants a function depends on, and let a violation raise so supervision and error reporting surface it. A process that crashes loudly is easier to fix than one that limps along in a state you never designed for.

#### Fail Fast On Contracts

Fail fast at the edges of that contract. Reject types and shapes that should never occur, handle `nil` and absent inputs deliberately instead of assuming a happy path, and make an invalid state observable rather than dressing it up as silent success. The goal is that a broken assumption becomes a visible failure, not a quiet wrong answer downstream.

#### Surface Async Failures

Failures in spawned or asynchronous work must surface the same way. A task that runs off on its own still reports through logging and error monitoring; it never fails silently. Supervise the task and let error monitoring watch the spawned process instead of firing it into the void.

Prefer:

```elixir
Task.Supervisor.async_nolink(MyApp.TaskSupervisor, fn ->
  Airbrake.monitor(self())
  deliver(webhook_url, request_id, fun)
end)
```

Over:

```elixir
Task.async(fn -> deliver(webhook_url, request_id, fun) end)
```

#### Preserve Errors And Stacktraces

When a failure does travel, keep it legible. Preserve error names and stacktraces so the original problem stays troubleshootable, and keep fallback error paths minimal so they do not bury the real cause.

#### Verify The Match On Non-Unique Key Lookups

When you fetch a record by a key that is not guaranteed unique, such as an external trace or reference number, verify additional attributes of the result against what you expect before acting on it. Do not assume the first row is the right one, and do not trust a correlated count to stay consistent. A bare lookup on a non-unique column is a correctness and security hazard.

#### Release Cross-Cutting Resources On Every Terminal Path

When a flow takes on a cross-cutting obligation that must be released, such as an unlock, a lease, or a cleanup, release it on every terminal path, ideally through one shared function. Do not thread a sentinel tuple up through extra `else` branches just to defer the release; call it where each path ends so no exit can skip it.

Prefer:

```elixir
{:error, reason} ->
  escalate_unresolved_payment(device_payment, reason)
  release_device_and_return(device, {:cancel, inspect(reason)})
```

Over:

```elixir
{:error, reason} ->
  escalate_unresolved_payment(device_payment, reason)
  {:unlock_and_cancel, device, inspect(reason)}

# ...forcing process/1 to grow an `else` that only routes the tuple back down:
else
  {:unlock_and_cancel, device, msg} ->
    unlock_or_escalate(device)
    {:cancel, msg}

  other ->
    other
end
```

## Separation of concerns and layering

#### Keep Transport Out Of Core

Keep transport concerns out of the core. Core and context functions return plain data and stay ignorant of the request that triggered them; the web layer parses input, enforces request-specific constraints, and decides status codes. This keeps the domain reusable and the boundary honest about what belongs to HTTP.

#### Thin Controllers And Subscribers

Controllers and subscribers stay thin. Business logic such as filtering lives in the core or API layer, and data access goes through API functions rather than direct **Repo** calls at the web layer.

#### Authorization In Its Layer

Authorization is its own concern: keep those decisions in the authorization or policy layer, not hard-coded into plugs or controllers.

#### Contain Third Party Libraries

Treat third-party and infrastructure libraries as details to be contained. Keep their knowledge out of domain and orchestration code, pass raw data into core modules, and encapsulate a dependency within one app so replacing it later has a limited blast radius.

#### Respect Umbrella Layering

Respect umbrella layering while you are at it: avoid circular dependencies, keep lower-level apps like core free of web, and reach across apps only through an app's public API module.

#### Give Each Concern A Home

Give every concern its own home. Separate distinct responsibilities such as logging and error reporting, and keep the construction of data apart from the side effect that consumes it, leaving the side-effecting call visible at the top level so a reader can see where the effect happens.

#### Normalize Sources At The Boundary

Where the system meets an external source, normalize vendor- and source-specific representations at your own boundary, so the rest of the code stays agnostic and adding a new source stays a centralized change.

## Single responsibility

#### Single Responsibility Per Function

A function, module, or file should do one thing. Extract a function once it grows too long or starts serving more than one purpose, decompose a long function into small well-named helpers so each clause reads as a sequence of intent, and push an operation's own details into the function that owns it rather than scattering them across callers.

## Simplicity and YAGNI

#### Build Only What Is Needed

Build only what is needed now. Do not add dependencies, generated files, or speculative flexibility until a real need exists, and weigh a new dependency's ongoing maintenance cost against the value it actually adds.

#### Do Not Abstract Prematurely

Do not abstract prematurely. Wait for concrete repetition before extracting shared code, and prefer function-head pattern matching over generality invented on speculation.

#### Balance DRY Against Clarity

Balance this against DRY with judgment: keep distinct things separate when merging them adds more complexity than it removes, and for throwaway code favor easy future removal over sharing.

#### Defer Refactoring Until Justified

Defer refactoring until real churn or confusion justifies it, and never invest in refactoring code that is already slated for deletion.

#### Prefer The Simplest Thing

Prefer the simplest thing that works. Reach for existing framework features and well-tested abstractions instead of hand-rolling equivalents, do not spend code optimizing away work that is unlikely to matter, and keep shared libraries from becoming so magical that callers cannot follow what they do.

## One source of truth

#### One Home Per Fact

Every fact should have a single home. Derive values from one place instead of hardcoding duplicate lists, call the shared function that encapsulates a rule rather than reimplementing it so a change propagates everywhere, and lift logic duplicated across clauses or apps into one well-named home.

#### Parameterize Instead Of Copying Scripts

The same discipline applies to scripts: parameterize a single script through command-line arguments instead of maintaining near-identical copies per case.

#### Document In One Place

Documentation follows the same rule. Keep it in one authoritative place and link to it rather than restating it, put usage where readers actually look, and let each source (module docs, config files, and other services) own its own details instead of copies that quietly drift out of date.

#### Store Timestamps In UTC

Store every timestamp in the database in UTC, for example `:utc_datetime_usec`. Treat UTC as the single canonical representation and convert to local time only at the edges, such as display or API layers, rather than storing local times.

## Explicitness

#### Declare Direct Dependencies

Depend explicitly on what you use: declare a module's direct dependencies in `mix.exs` even when they happen to be available transitively, so the dependency graph tells the truth.

#### Prefer Explicit Over Implicit

Prefer explicit over implicit. Give each parameter its own argument, use a library's public API rather than reaching into its internals, and drop wrapper dependencies that hide the underlying library from you.

#### Comment The Nonobvious Why

Explicitness extends to intent. Capture non-obvious rationale close to the code, commenting the why that a reader cannot infer, such as where unusual test data comes from. Save the comment for what the code cannot say for itself.

## Backward compatibility and versioning

#### Follow Semantic Versioning

We version for the people who consume our libraries. Follow semantic versioning: a patch for bug fixes, a minor bump for new features, and a major bump for anything backward-incompatible, including dropping support for older language versions.

#### Judge Breaking By Consumer Impact

Judge whether a change is breaking by whether it could break a consumer, not by whether anything happens to use it that way today.

#### Write CHANGELOG For Consumers

Write the CHANGELOG for those same consumers. Record user-facing changes, call out breaking ones plainly to ease upgrades, order entries by audience, and leave out the internal dev and test churn that does not warrant a release.

## Boundaries and information hiding

#### Do Not Leak Internals

What crosses an outward-facing boundary is a deliberate choice. Do not leak internal or sensitive detail across it: keep internal identifiers, large internal objects, PII, and internal rejection reasons out of API and error responses. Be as specific as you can internally, where precise error tuples aid debugging, and obfuscate only at the HTTP layer where the audience changes.

#### Expose Data Through Accessors

Hide internals from callers within the code too. Expose data through accessor functions and schema-based serialization rather than deep struct pattern matching, so the shape underneath can be refactored without breaking everyone who reads it.

## Small changes and reviewability

#### Keep Changes Small And Reviewable

Keep changes small and reviewable. Split unrelated large changes into separate PRs so each one carries a single, reviewable intent. Review generated code with particular care, since it can confidently reproduce incorrect patterns such as swapped arguments.
