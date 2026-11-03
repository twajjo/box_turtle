# BoxTurtle

[![CI](https://github.com/twajjo/box_turtle/actions/workflows/ci.yml/badge.svg)](https://github.com/twajjo/box_turtle/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/box_turtle.svg)](https://hex.pm/packages/box_turtle)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/box_turtle)

A toolkit of Elixir building blocks:

- **Schema**: a convention-driven Ecto data-access layer. You get `get`, `list`, `count`, `create`, `update` and `delete` for a schema, with filters, sorting, pagination and preloads, in two lines of code.
- **Runtime**: typed, validated configuration from environment variables, runtime config scripts, and configurable module dispatch (handy for Mox).
- **Debug**: a pipe-friendly `debug/3` that you turn on per module through config.
- **Common / Security**: result-tuple helpers, ID generators, and a secure password generator.

## Installation

Add `box_turtle` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:box_turtle, "~> 0.1"}
  ]
end
```

BoxTurtle requires Elixir 1.20 or later. The Schema modules work with any Ecto SQL adapter. `:distinct` on lists uses `DISTINCT ON`, which is PostgreSQL-only. With SQLite, MySQL or MSSQL it raises an `ArgumentError`: at compile time for `:default_distinct`, and when the query is built for call-time `:distinct`. Counts can use `:distinct` with any adapter.

## Schema in two minutes

Given an ordinary Ecto schema with a `changeset/2`:

```elixir
defmodule MyApp.Blog.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    field :title, :string
    field :status, :string, default: "draft"
    belongs_to :author, MyApp.Blog.Author
    timestamps()
  end

  def changeset(post, attrs), do: cast(post, attrs, [:title, :status, :author_id])
end
```

add a `Query` module and a `Change` module next to it:

```elixir
defmodule MyApp.Blog.Post.Query do
  use BoxTurtle.Schema.Query, repo: MyApp.Repo, default_sort: [desc: :inserted_at]
end

defmodule MyApp.Blog.Post.Change do
  use BoxTurtle.Schema.Change, repo: MyApp.Repo
end
```

and use them:

```elixir
alias MyApp.Blog.Post

{:ok, post} = Post.Change.create(%{title: "Hello"})
{:ok, post} = Post.Change.update(post, %{status: "published"})

{:ok, ^post} = Post.Query.get(post.id)
{:error, :not_found} = Post.Query.get(-1)

Post.Query.list!(filters: [status: ["draft", "published"]], sort: [asc: :title], page: 2)
Post.Query.list!(filters: [author_id: nil], preloads: [:author])
Post.Query.count!()                      #=> 42
Post.Query.count!(group_by: [:status])   #=> [%{status: "draft", count: 30}, ...]

{:ok, _deleted} = Post.Change.delete(post.id)
```

The schema is inferred from the module name (`MyApp.Blog.Post.Query` serves `MyApp.Blog.Post`). Custom filters, custom sorts, pattern-scoped `list_by/2`-style functions and shared delegates are covered in the [Schema guide](guides/schema.md).

## Runtime configuration

`BoxTurtle.Runtime.Config.Helper.get_env/2` reads an environment variable, parses it into the type you want and validates it:

```elixir
# config/runtime.exs
import Config
alias BoxTurtle.Runtime.Config.Helper

config :my_app,
  pool_size: Helper.get_env("POOL_SIZE", type: :integer, default: 10, in_range: 1..100),
  hosts: Helper.get_env("HOSTS", type: :list, default: ["localhost"]),
  log_level: Helper.get_env("LOG_LEVEL", type: :atom, in_set: [:debug, :info, :warning]),
  features: Helper.get_env("FEATURES", type: :map, default: %{})
```

Supported types: `:string`, `:integer`, `:float`, `:boolean`, `:atom`, `:module`, `:charlist`, `:list`, `:tuple` and `:map` (JSON). Lists and tuples can have typed elements (`subtype:`). Atoms and modules must already exist, unless you pass `unsafe_atoms: true`.

`BoxTurtle.Runtime.Config.load_runtime_config/1` loads a separate `import Config` script into the application environment at runtime. `BoxTurtle.Runtime.Application.Helper.conditional_append/4` builds supervision trees whose children depend on a condition.

## Module dispatch

Put a stable facade in front of a configurable implementation:

```elixir
defmodule MyApp.Mailer do
  # Implements MyApp.Mailer.API by forwarding to MyApp.Mailer.Impl,
  # or to whatever `config :my_app, MyApp.Mailer, impl: ...` names.
  use BoxTurtle.Runtime.DynamicInterface.ModuleDispatch, otp_app: :my_app
end

# config/test.exs
config :my_app, MyApp.Mailer, impl: MyApp.Mailer.Mock
```

The implementation is read on every call. So the same facade gives you a different implementation per build, runtime switching (failover, feature flags), Mox mocks that can fall back to a real implementation, and A/B tests through a router implementation. All of these are demonstrated, with fake implementations, in [`test/support/examples/dispatch.ex`](https://github.com/twajjo/box_turtle/blob/main/test/support/examples/dispatch.ex) and [its tests](https://github.com/twajjo/box_turtle/blob/main/test/runtime/dynamic_interface/dispatch_examples_test.exs).

## Pipe debugging

```elixir
defmodule MyApp.Billing do
  use BoxTurtle.Debug.PipeDebug

  def total(order) do
    order.items
    |> Enum.map(& &1.price)
    |> debug("prices")
    |> Enum.sum()
  end
end

# config/dev.exs: only these modules log
config :my_app, debug_enabled_modules: [MyApp.Billing]
```

## Utilities

- `BoxTurtle.Common.ReturnOkOr.return_ok_or/2`: `nil`, bare values, `:error` → `{:ok, _}` / `{:error, reason}`.
- `BoxTurtle.Common.IdUtils`: KSUID and UUID generators.
- `BoxTurtle.Schema.Ecto.Ksuid`: a KSUID `Ecto.Type` for primary keys.
- `BoxTurtle.Security.Password.generate/1`: random passwords from a cryptographically secure source, always containing lowercase, uppercase, digit and special characters.

## Development

```bash
mix deps.get
mix test            # Schema tests run against SQLite; no database server needed

# Also run the PostgreSQL-only tests (DISTINCT ON); the database is created and dropped for you
BOX_TURTLE_PG_URL=postgres://postgres:postgres@localhost:5432/box_turtle_test mix test
mix credo --strict
mix dialyzer
mix docs
```

## License

MIT. See [LICENSE](https://github.com/twajjo/box_turtle/blob/main/LICENSE).
