# Application configuration

Scope: How we configure Elixir apps across compile-time and runtime, config files, environments, and secrets. This overlaps with mix, formatter, **Credo**, **Dialyzer**, and CI tooling conventions, which live elsewhere. The rule against setting config equal to its default, and the rule against leaving unread config in place, are candidates for custom Credo checks; a check that cannot cope with dynamically set values should be disabled rather than chased.

## Compile-time vs runtime

#### Compile Time Files Versus Runtime

Keep static values in the compile-time config files (`config.exs` and the per-environment files) and reserve `runtime.exs` for values derived from the system environment and their defaults. Move prod config that depends on env vars into `runtime.exs`, and keep everything else out of it.

#### Reading Compile Time Config Safely

Read compile-time config with `Application.compile_env/2` or `/3`, assigning it to a module attribute or reading it in the module body, so the compiler does not warn about a runtime lookup of a value fixed at compile time.

Use `Application.get_env` for values read at runtime and `compile_env` for values baked in at compile time.

#### Pass Runtime Values As Functions

Pass a value that must be evaluated at runtime as a function reference or MFA rather than as a compile-time config call, so it resolves when invoked and not once at build. For example, pass `&Web.Auth.okta_issuer/0` rather than the call `Web.Auth.okta_issuer()`.

#### System Env Calls In Runtime

Call `System.get_env`, `System.fetch_env!`, and other `System` functions only in `config/runtime.exs`. Do not call them in application code or in the compile-time config files. Application code reads those values back through `Application.get_env`.

#### Never Branch On Mix Env

Do not branch on `Mix.env()` in runtime code. Make environment-specific decisions in `config/*.exs`, where they are discoverable in one place, and read the result through `compile_env`.

## Reading configuration

#### Wrap Config Access In Getters

Wrap configuration access in a small private getter or predicate function when it carries a default or any logic worth naming. Read a trivial single lookup directly rather than wrapping it in a function that adds nothing.

#### Config Files Not Config Modules

Keep configuration in `config/*.exs` and read it through the `Application` env rather than a dedicated config module. Start applications and backends in `application.ex`; config files hold config, not startup.

## Fail-fast and required config

#### Fetch Required Config To Fail Fast

Read required configuration with `System.fetch_env!/1` or `Keyword.fetch!/2` so a missing or misconfigured value crashes the app at startup instead of yielding `nil` and failing obscurely later. In prod, required env vars use `fetch_env!`; dev and other optional reads use `get_env` with a default.

Split the read by environment: an optional default locally, a required fetch in prod.

```elixir
# runtime.exs
case config_env() do
  :dev ->
    # optional locally: a dev need not set it
    config :invoice_service, :api_key, System.get_env("API_KEY", "dev-api-key")

  :prod ->
    # required in every deployment: crash at startup if unset
    config :invoice_service, :api_key, System.fetch_env!("API_KEY")
end
```

#### Defaults For Optional Config

For optional configuration, supply the default through `System.get_env/2`'s second argument rather than a `get_env/1` call with a `||` fallback.

## Environment and env vars

#### Only Dev Test And Prod

Model Mix environments as only `dev`, `test`, and `prod`. Do not map deployment clusters onto Mix env or reuse Mix env names for cluster values; the two concepts are distinct. Remember that releases compile with `MIX_ENV=prod`, so a deployed image is always `prod` regardless of the cluster it runs in, and put environment comments in the `:prod` case.

#### Document Env Vars In Example File

Document required environment variables in an example env file such as `.envrc.example` or `.envrc.sample` so developers know what to set. Keep config comments accurate to the setting's true scope, and describe config in terms of the env variables it reads, not general deployment, k8s, or helm knowledge. General deployment docs do not belong inline in config or in the repo README.

#### Never Commit Local Env Files

Do not commit local env files. Gitignore the real `.envrc` and check in only the example.

#### Feature Flags Default To Disabled

Default a feature-flag environment variable to disabled so a flag is never enabled by accident when the var is unset.

#### Case On Environment In Runtime

When runtime config switches on the environment, use a `case`. It is the established pattern across our apps.

#### Annotate Cron With Comment And Ticket

Annotate a cron expression with a human-readable comment (for example a crontab.guru link) and a link to the owning ticket.

## Secrets

#### Secrets From Environment Variables

Read secrets and tokens from environment variables in runtime config, per environment, and hardcode them only in test config. Never give a required secret a default value; let the app fail fast when it is unset rather than silently running with a placeholder.

## Structuring config files

#### Namespace Config Under App Name

Namespace application config under the app or consuming-module name, mapping it to a keyword list. Group related keys under one namespacing key, and prefer generic, extensible names over ambiguous ones or names coupled to a single consumer.

#### Consistent Structure Read With Get In

Keep config structure consistent and strict, and read nested config with `get_in/2`.

#### Never Set A Key Twice

Do not set the same keyword key twice in a config block; only the first value is used.

#### Alphabetize Configuration Entries

Alphabetize configuration entries within each environment block so they are easy to scan.

#### One Canonical Place Per Value

Define each configuration value in a single canonical place. Set environment-varying values in the matching environment file rather than duplicating them across config files or restating what shared `config.exs` already sets.

#### Shared Defaults With Env Overrides

Set shared defaults in `config.exs` and let the environment files deep-merge and override them. Organize runtime config into per-environment sections rather than one catch-all block.

#### Never Restate A Default Value

Do not specify configuration that equals its default value.

#### Remove Unread Configuration

Remove configuration the application never reads, including config left behind for a plug or component that a dependency upgrade removed.

#### Phoenix Endpoint Server False Default

Default a [**Phoenix**](https://hexdocs.pm/phoenix/Phoenix.html) endpoint to `server: false` and start the web server explicitly with `mix phx.server`, enabling `server: true` only in prod config. This keeps `iex` startups free of the web server and avoids port conflicts.

#### Behavior Defaults Over Config Toggles

Prefer a behavior default passed through code over a config toggle that forces a redeploy to change.

#### Configure Logger Backends Explicitly

Configure logger backends explicitly, for example `LoggerBackends.add/1`, rather than the deprecated **Logger** `:backends` config.

## Libraries vs applications

#### Configure Under The Owning Application

Configure a component under the OTP application that actually owns it, and declare a dependency in the app that uses it.

#### Umbrella Wide Settings At Root

In an umbrella, configure umbrella-wide tooling and settings at the root. Keep only component-specific settings in a component app's config, and leave **Dialyzer**, docs, aliases, and other umbrella-wide concerns at the top.

#### Library Dependency And Lock Rules

For a library, `mix.lock` is irrelevant to consumers; the `mix.exs` constraints govern the versions a consumer resolves. Mark dependencies a consumer may not need as `optional`.

## Testing configuration

#### Static Dummy Values For Tests

Put test configuration in `config/test.exs` as static dummy values. Do not derive test values in the test itself, in `runtime.exs`, or from per-developer environment variables.

#### Inject Config Through Opts Parameter

Inject configuration through an `opts` parameter that falls back to `Application` config. This keeps tests isolated and async-safe instead of mutating `Application` env at runtime.

```elixir
def start_link(opts) do
  timeout = Keyword.get(opts, :timeout, Application.get_env(:invoice_service, :timeout))
  ...
end
```
