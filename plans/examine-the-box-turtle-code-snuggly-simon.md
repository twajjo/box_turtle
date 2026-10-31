# BoxTurtle → open-source Hex package

## Context

`box_turtle` is a utility toolkit extracted from a private codebase (leftover `PurpleEngine`/`PurpleBase`/`:os_base` names prove it). It is about to go on GitHub/Hex. Right now it **does not compile**, Schema has **zero tests**, and the package metadata is missing. The goal is a clean, documented, tested 0.x release.

Decisions made with the user:
- **Keep every area** (Schema, Runtime, Debug, Common, Security) in one package.
- **Breaking changes are fine.** This is a fresh 0.x API.
- **Elixir `~> 1.20`.**
- **Schema integration tests use SQLite** (`ecto_sqlite3`).

## Phase 0: Repo hygiene and packaging (do first)

- Remove `.elixir-tools/` from git and add it to `.gitignore`. Change `os_base-*.tar` to `box_turtle-*.tar`.
- In `test/support/mox_hooks/mox.ex`, delete the dead `_modules_to_mock` block that references Purple* modules. In `test/support/runtime.exs`, rename `:os_base` to `:box_turtle`. Grep for any other proprietary leftovers.
- `mix.exs`:
  - Set `elixir: "~> 1.20"` and drop `vsn:`.
  - Add `description`, `package` (licenses, links, files), `source_url`, `homepage_url` and `docs` (main: "readme", extras, `groups_for_modules` per area).
  - Dependencies:
    - **Drop:** `poison`, `hackney` (and from `extra_applications`), `sweet_xml`, `cloak_ecto`, `earmark`, `atomic_map`.
    - **Replace:** `ecto_sql` with `ecto ~> 3.12`.
    - **Loosen:** `jason` to `~> 1.4`, and mark it optional unless Config.Helper's `:map` type needs it.
    - **Add:** `ecto_sqlite3` and `ecto_sql` as test-only, and `dialyxir`/`credo` as dev/test.
  - Decide what happens to `external_config` (Phase 3).
- Add `LICENSE` (Apache-2.0 or MIT; ask the user), `CHANGELOG.md`, and a rewritten `README.md` that covers the purpose, install, a quick tour of each area and a Schema walkthrough.
- `config/config.exs`: remove the `mix_env: config_env()` line and the leftover `:message_dispatcher`/`:nhg_resolver` comments. A library must not rely on its own config.
- Add `.github/workflows/ci.yml`: `mix format --check-formatted`, `mix compile --warnings-as-errors`, `mix credo --strict`, `mix test`, `mix dialyzer` and `mix docs`.

## Phase 1: Make it compile (blockers)

- `lib/debug/pipe_debug.ex`: it uses the nonexistent `BoxTurtle.Runtime.Application.Environment` and `test_mode?/1`. Remove both and always log through `@logger_module` at the configured level. Tests can capture output with `ExUnit.CaptureLog`. Rename the private `dbg/3` so it doesn't shadow `Kernel.dbg`. Replace `Logger.warn` with `Logger.warning` in `lib/common/return_ok_or.ex`.
- `lib/runtime/dynamic_Interface/module_dispatch.ex` is not valid Elixir (`elsif`, dead branches, `arg#{1}` bug, `is_runtime` reads `:generate_stub`). Rewrite it as two clear modes:
  - `generate_stub: true` produces stubs that return `:ok`.
  - The default dispatches to `impl_module()`, resolved through `Application.get_env` or the `:impl` option.
  - Generate correct `arg1..argN` vars, and handle arity 0.
  - Rename the directory to `dynamic_interface/`.
- `mix compile --warnings-as-errors` must pass before going further.

## Phase 2: Schema (`lib/schema/`), the main focus

**Query (`query.ex`, `query/*.ex`)**
- Default `schema` comes from `__CALLER__.module` minus its last segment, not `__MODULE__`. Run all `schema`/`repo`/module options through `Macro.expand(…, __CALLER__)`. `extract_schema`/`extract_scope`/`extract` then work with plain atoms, which removes the hand-rolled `glom` alias AST matching.
- Raise a `CompileError`/`ArgumentError` when `:repo` is missing. Validate options with `NimbleOptions`, or a small keyword validator if we want to avoid the dependency. That also gives generated option docs.
- `get!/2` must use `filter_module(opts)`. Make `multi_key_where/3` private (wrapped in `@doc false`) and drop its no-op `Enum.map`. Delete the unused `@supported_aggregates`.
- `*_by` placeholder functions: either generate them only through `extend/delegate`, or return `{:error, :not_implemented}` consistently (the `!` variants raise). Add the arity-1 forms that the callbacks declare.
- Rename the option to a single name, `ignore_defaults:`, everywhere. Remove the unused `default_order`. Make the docs match the code (`default_sort: [asc: :id]`).
- Replace the PipeDebug `debug(...)` calls with `Logger.debug` metadata, or drop them. Library hot paths shouldn't inspect every query.

**Helpers (`query/helpers.ex`)**
- `aggregate_unique(query, nil|_)` → `select(%{count: count()})`. No more hard-coded `inserted_at`.
- `aggregate_result!`: plain map access; remove `AtomicMap`.
- `group/2` on a binary → `String.to_existing_atom`, or reject it. This prevents atom exhaustion.
- Remove the duplicate `preloads(query, nil)` clause.

**Filters (`filters.ex`, `filters/api.ex`)**
- Remove the `IO.inspect(env, …)` from `__before_compile__`.
- Make `BoxTurtle.Schema.Filters` itself export a working default `filter_with/2`, so the default `filter_module` actually works. Keep `use BoxTurtle.Schema.Filters` for custom clauses with a catch-all that falls back to the shared implementation.
- The catch-all must keep processing the remaining filters. Support `nil` values (`is_nil`), lists (`in`) and string keys through `to_existing_atom`.
- Fix the `@behaviour` warning. Add `@moduledoc` and `@callback` docs.

**Sort (`sort.ex`)**: drop the debug calls, add a final catch-all that raises `ArgumentError` on an invalid spec, and fix the API typespec (`list()`, not `keyword()`).

**Pagination (`pagination.ex`)**: support `page: n` and `page: [number: n, size: s]`, with a default size taken from a `use` option (`:page_size`, default 40). Clamp `n < 1` to 1. Resolve the FIXME about two pagination modules.

**Change (`change.ex`, `change/api.ex`)**
- Require `:repo` at compile time. Allow `:schema` explicitly, defaulting to the parent module. Allow `:query` (default `Module.concat(schema, Query)`).
- Make the required schema functions (`changeset/2`, `update_changeset/2`) a documented contract, or add optional callbacks with defaults. Remove `new_changeset/0` and use `struct(schema)` instead.
- Fix the typespecs: `Ecto.Changeset.t()`, and `update!` returns `Ecto.Schema.t()`. Either implement `create/2` and `create!/2` (parent association through `Ecto.build_assoc`) or remove them from the API.
- Rename `bollox`. Fix the unused-variable warnings in `from_struct`. Add `defoverridable`.

**Ksuid (`ecto/ksuid.ex`)**: validate the base62 charset in `cast`, and add `@moduledoc`.

**Docs**: add a top-level `BoxTurtle.Schema` moduledoc and a `guides/schema.md` with an end-to-end example (schema → Query → Change → filters/sort/pagination/extend/delegate).

## Phase 3: Other areas

- **Runtime.Config**: `external_config` is unmaintained. Replace `ExternalConfig.read!` with Elixir's built-in `Config.Reader.read!/1`, which gives the same `[{app, kw}]` shape, and drop the dependency. Update `test/support/runtime.exs` to `import Config`.
- **Config.Helper**: `:atom` parsing → `String.to_existing_atom` by default, with an `unsafe_atoms: true` opt-in. Review the `{} = value` patterns, which only match empty tuples (a bug).
- **Application.Helper**: collapse the duplicated `conditional_*` aliases into `conditional_append/3,4` and deprecate the rest.
- **Security.Password**: use `:crypto.strong_rand_bytes`-based selection instead of `Enum.random` (which isn't cryptographically secure). Make `@min_length` match the doc (it says 4; the code says 8). Credit the Rosetta Code source under its license.
- **Common.IdUtils**: rename `generate_id` (a random integer that can collide) or document the risk. Remove `test/support/utils.ex`, which duplicates it.

## Phase 4: Tests

- `test/support/repo.ex` (Ecto SQLite repo), migrations in `priv/test_repo/migrations` or created in `test_helper.exs`, and a `DataCase` with the sandbox. Fixture schemas: `Post` (timestamps, belongs_to `Author`), `Author`, and `Tag` (no timestamps, for the count regression).
- Schema tests: `get/get!`, `list` with filters/sort/page/preloads/distinct, `count` with and without `group_by`, `ignore_defaults`, `extend`/`delegate` code generation, and all of `Change` create/update/delete in both bang and tuple forms. Also Filters/Sort/Pagination unit tests and Ksuid cast/dump tests.
- Keep the existing tests for runtime and pipe_debug green, and add tests for ModuleDispatch, Password and ReturnOkOr.

## Critical files

`mix.exs`, `README.md`, `lib/schema/**`, `lib/debug/pipe_debug.ex`, `lib/runtime/dynamic_Interface/module_dispatch.ex`, `lib/runtime/config.ex`, `lib/runtime/config/helper.ex`, `test/test_helper.exs`, `test/support/**`, new `LICENSE`/`CHANGELOG.md`/`.github/workflows/ci.yml`.

## Verification

1. `mix deps.get && mix compile --warnings-as-errors`
2. `mix format --check-formatted && mix credo --strict`
3. `mix test --cover`: new Schema suite against SQLite, coverage above 80% for `lib/schema`
4. `mix dialyzer` is clean
5. `mix docs` builds; check the module groups and the Schema guide by eye
6. `mix hex.build` succeeds, and the file list contains only lib/, mix.exs, README, LICENSE and CHANGELOG
7. Smoke test: a scratch Mix project with `{:box_turtle, path: "..."}` defines `MyApp.Post.Query` and `MyApp.Post.Change` and runs list/create in `iex -S mix`.
