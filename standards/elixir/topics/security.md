# Security and sensitive data

Scope: how we handle secrets, personal data, authorization, and untrusted input in our Elixir
services. These are concrete, reviewer-enforced hazards, several of them flagged as blocking in
review, rather than general design principles.

## Secrets and personal data

#### Never Log Or Report Secrets Or PII

Never write a secret, verification key, credential, or piece of personal data to logs, `Logger`
metadata, or an error reporter such as **Airbrake**. Storing a value encrypted at rest is not
permission to log it. Do not `inspect/1` a struct that may hold a secret, and mask sensitive
identifiers completely rather than partially: do not log any digits of an SSN, not even the last
four. Filter these fields explicitly so they cannot leak through a stacktrace or an error notice.

## Authorization

#### Verify JWT And Resource Ownership Before Acting

Before performing an authenticated action, verify the caller's JWT first and propagate its error
if verification fails. Then confirm the target resource actually belongs to the JWT's subject
before reading or mutating it. Do not act on a resource id just because it was supplied: if Bob's
token requests an update to a payment instrument that Alice owns, the request must be refused.
Return a non-revealing error on a mismatch so the response does not disclose whether the resource
exists. This is the defense against an insecure direct object reference (IDOR).

Verify the token, then confirm ownership before the mutation, and map a mismatch to a
non-revealing error.

Prefer:

```elixir
def call(topic, %{id: id, payment_instrument: attrs}, context) do
  with {:ok, claims} <- Token.decode_and_verify(context),
       {:ok, %PaymentInstrument{} = pi} <- core_api().get_payment_instrument(id),
       :ok <- verify_owner(pi, claims) do
    core_api().update_payment_instrument(id, attrs)
  else
    {:error, :not_owner} -> {:error, :not_found}
    error -> error
  end
end
```

Over:

```elixir
def call(topic, %{id: id, payment_instrument: attrs}, _context) do
  core_api().update_payment_instrument(id, attrs)
end
```

## Untrusted input

#### Fail Safe By Redacting On Parse Failure

When a sanitizer or redactor cannot parse its input, fail closed: redact and drop the value
rather than passing the raw, potentially sensitive input through. A parse-failure branch that
forwards the original text can send unredacted data straight to logs or **Airbrake**. The safe
default on any parse error is to treat the whole input as sensitive.

When **Absinthe** cannot parse the query, returning it verbatim sends any inline literals straight
to **Airbrake**.

Prefer:

```elixir
case Absinthe.Phase.Parse.run(query) do
  {:ok, blueprint} -> redact(blueprint)
  {:error, _} -> "[REDACTED: unparseable query]"
end
```

Over:

```elixir
case Absinthe.Phase.Parse.run(query) do
  {:ok, blueprint} -> redact(blueprint)
  {:error, _} -> query
end
```

#### Bound Untrusted Input Before Parsing

Cap the size of untrusted input before parsing it into memory. Parsing an unbounded string, for
example a **GraphQL** query, into an in-memory AST lets a caller exhaust resources. Guard the
input with `byte_size/1` against a fixed cap and reject over-length input before the parse step
rather than after.

#### Validate User Input Before Interpolating Into URLs

Validate user-supplied values before interpolating them into a URL, so malformed or malicious
input cannot alter the request target. For an id, cast it first with `Ecto.UUID.cast/1` and build
the URL only on the `{:ok, uuid}` branch. Even a value that today comes from a trusted column
deserves the guard, because the source can change.
