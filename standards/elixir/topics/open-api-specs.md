# OpenAPI schemas (OpenApiSpex)

Scope: conventions specific to our OpenAPI specs, written with [**OpenApiSpex**](https://hexdocs.pm/open_api_spex/OpenApiSpex.html). These are split out of the general Elixir docs because they apply only when a service exposes an OpenAPI-documented HTTP API.

## Schemas

#### Nullable Non-Required Fields
Mark every non-required field nullable with `nullable: true` so casting and struct-to-JSON
encoding stay valid.

#### Reference Schemas For Refs
Reference schema modules directly in array items so **OpenApiSpex** emits a `$ref` instead of
inlining.

#### Record Type Property First
Place the `record_type` property first in a schema definition.

#### Email Format On Strings
Use `format: :email` on string schemas to document and validate email fields.

#### Literal Data For Examples
Use plain literal data, not schema modules, for schema examples.

#### List Only Unreferenced Schemas
List OpenAPI schemas explicitly only when no operation references them, and do not list ones
already referenced.

#### Empty Response Body Description
For a response with no body, give only the description and let `open_api_spex` fill in the
rest; by convention a 404 needs no response body.

## Operations and validation

#### Specify Every Action Operation
When adding [**OpenApiSpex**](https://hexdocs.pm/open_api_spex/OpenApiSpex.html) to a controller, specify or explicitly disable every action's
operation, or tests fail.

#### Omit Redundant Action Doc
Omit `@doc` on a controller action when its operation already documents it.

#### CastAndValidate For Validation Errors
Let [**OpenApiSpex**](https://hexdocs.pm/open_api_spex/OpenApiSpex.html)'s `CastAndValidate` plug produce
validation error responses instead of hand-rolling them.

#### View Matches Schema Fields
Target a view to the fields declared in its OpenAPI schema.

## Request parameters

#### OpenAPI Header Parameters

Avoid declaring header parameters with OpenAPI `in: :header`; **open_api_spex** maps the
header name straight into the params key and distorts it. Read the header explicitly with
`get_req_header/2` instead.

## Testing

#### Assert OpenAPI Schema Conformance

Assert that controller and API responses conform to their OpenAPI schema with
`assert_schema`, test only the response statuses the code meaningfully handles, those with
schemas, and explicitly test that values cast to their schema type.
