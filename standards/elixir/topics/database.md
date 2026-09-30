# Database

Scope: how we work with the database in Elixir, through [**Ecto**](https://hexdocs.pm/ecto/Ecto.html): changesets, queries, migrations, and bulk or streaming operations. This is the persistence layer; the same topic in another language would hold its ORM, query, and migration rules.

## Changesets

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

#### Unpopulated Virtual Fields

Prefer real, preloaded associations over virtual fields that Elixir code must populate; an
unpopulated virtual field is silently `nil`.

#### Matching Changeset Internal Values

Do not pattern-match on a changeset's internal values; read the values from the source
params instead.

## Queries

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

#### N Plus One Queries

Avoid N+1 and redundant queries. Do not fetch related data one row at a time in a loop,
and treat fetching the same record with the same params more than once in a single request
as a smell to eliminate. Prefer [`Ecto.Query.preload/3`](https://hexdocs.pm/ecto/Ecto.Query.html)
over [`Ecto.Repo.preload/3`](https://hexdocs.pm/ecto/Ecto.Repo.html): loading the association
in the query fetches it as part of that query, while a separate `Repo.preload` issues another
query after the fact.

```elixir
# one round trip
from(o in Order, where: o.client_id == ^client_id, preload: [:line_items])
|> Repo.all()

# a second query after the fact
orders = Repo.all(from o in Order, where: o.client_id == ^client_id)
Repo.preload(orders, :line_items)
```

## Streaming and bulk operations

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

## Migrations

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
