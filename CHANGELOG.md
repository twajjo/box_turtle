# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-11-02

First public release.

### Added

- `BoxTurtle.Schema.Query` and `BoxTurtle.Schema.Change`: generated read and write functions for Ecto schemas, with filters, sorting, pagination, preloads, grouping, distinct and pattern-scoped `*_by` extensions (`extend/2`, `delegate/1`).
- `BoxTurtle.Schema.Filters` and `BoxTurtle.Schema.Sort`: working defaults plus `use` bases for custom clauses. Filters support `nil` (`IS NULL`) and lists (`IN`).
- `BoxTurtle.Schema.Pagination`: `page: n` or `page: [number: n, size: s]`, with a per-module `:page_size`.
- `BoxTurtle.Schema.Ecto.Ksuid`: a KSUID `Ecto.Type`.
- `BoxTurtle.Runtime.Config.Helper`: the `:map` type (JSON, via the standard library) and the `unsafe_atoms` option.
- `BoxTurtle.Runtime.DynamicInterface.ModuleDispatch`: facade modules that forward a behaviour to a configurable implementation, or generate stubs.
- `BoxTurtle.Security.Password.min_length/0`.
- `:distinct` with an adapter that has no `DISTINCT ON` (SQLite3, MyXQL, Tds) raises a clear `ArgumentError` when the query is built. A `:default_distinct` like that is rejected at compile time.

### Changed (compared to the pre-release code)

- `:atom` and `:module` config values must name existing atoms unless `unsafe_atoms: true` is given.
- `Runtime.Config` reads scripts with Elixir's `Config.Reader`; the `external_config` dependency is gone.
- `Security.Password` uses a cryptographically secure random source and returns `{:error, :too_short}`. It also now honours the requested length; previously some lengths produced shorter passwords.
- `Schema.Query.get/2` returns `{:error, :not_found}` when no row matches.
- `count/1` uses `COUNT(*)` and no longer requires an `inserted_at` column.
- The `:no_defaults` option is now `:ignore_defaults`.
- `:preloads` are loaded with `LEFT JOIN`s in the same query instead of one query per association. With to-many preloads, paging and `distinct` are applied to parent rows through a primary-key subquery. Preload queries and functions are no longer accepted.

### Fixed

- `count(group_by: ["column"])` with string column names crashed while building the select.

### Removed

- `Application.Helper.conditional_applications/3,4`, `conditional_modules/3,4` and `conditional_children/3,4`. Use `conditional_append/3,4`.
- `Schema.Change.create/2`, and the placeholder `*_by` functions (generate them with `extend/2` or `delegate/1`).
- Dependencies on poison, hackney, sweet_xml, cloak_ecto, earmark, atomic_map, jason and external_config.

[0.1.0]: https://github.com/twajjo/box_turtle/releases/tag/v0.1.0
