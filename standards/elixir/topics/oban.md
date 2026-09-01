# Oban

Scope: how we write, run, configure, and test background jobs with [**Oban**](https://hexdocs.pm/oban/Oban.html). The same topic in another language would hold its background-job rules, for example Sidekiq in Ruby.

## Workers and jobs

#### Args Schema For Workers
Define an `args_schema` for [**Oban Pro**](https://oban.pro/docs/pro/overview.html) workers. It casts args to a struct with atom keys, so
match the struct rather than string keys.

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

## Queues

#### Avoid Extra Queues
Avoid creating extra queues unnecessarily, since each queue consumes PostgreSQL connections.

## Configuration

#### Start Oban In Base Application

Start **Oban** and other shared infrastructure, such as a logger backend, in a dedicated base or component application that the others depend on, not in `core`. This keeps database migrations from starting Oban prematurely and picking up jobs before they should.

## Testing

#### Test Oban Workers Natively

Test **[Oban](https://oban.hexdocs.pm/Oban.html)** workers with the framework's own tools. Use `Oban.Pro.Testing` with
`testing: :manual` for **Oban Pro** workers, and assert job insertion with **Oban**'s
`assert_enqueued` rather than wrapping insertion in a behaviour to mock.
