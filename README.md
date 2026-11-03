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

Given an ordinary Ecto schema with a `changeset/2`, in an application with an Ecto repo `MyApp.Repo`:

```elixir
defmodule MyApp.Blog.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    field :title, :string
    field :status, :string, default: "draft"
    field :likes, :integer, default: 0
    timestamps()
  end

  def changeset(post, attrs) do
    post |> cast(attrs, [:title, :status, :likes]) |> validate_required([:title])
  end
end
```

add a `Query` module and a `Change` module next to it:

```elixir
defmodule MyApp.Blog.Post.Query do
  # Newest first; the id breaks ties between rows inserted in the same second.
  use BoxTurtle.Schema.Query, repo: MyApp.Repo, default_sort: [desc: :inserted_at, desc: :id]
end

defmodule MyApp.Blog.Post.Change do
  use BoxTurtle.Schema.Change, repo: MyApp.Repo
end
```

and use them (starting from an empty `posts` table):

```elixir
alias MyApp.Blog.Post

{:ok, hello} = Post.Change.create(%{title: "Hello"})
{:ok, _} = Post.Change.create(%{title: "Popular", status: "published", likes: 40})
{:ok, _} = Post.Change.create(%{title: "Also out", status: "published", likes: 3})
{:error, %Ecto.Changeset{}} = Post.Change.create(%{title: nil})

{:ok, hello} = Post.Change.update(hello, %{status: "published"})
{:ok, %Post{title: "Hello"}} = Post.Query.get(hello.id)
{:error, :not_found} = Post.Query.get(-1)

Post.Query.list!(filters: [status: "published"], sort: [desc: :likes]) |> Enum.map(& &1.title)
#=> ["Popular", "Also out", "Hello"]

Post.Query.list!(page: [number: 2, size: 2]) |> Enum.map(& &1.title)
#=> ["Hello"]

Post.Query.count!()                      #=> 3
Post.Query.count!(group_by: [:status])   #=> [%{status: "published", count: 3}]

{:ok, _deleted} = Post.Change.delete(hello.id)
```

The schema is inferred from the module name (`MyApp.Blog.Post.Query` serves `MyApp.Blog.Post`). The [Schema guide](guides/schema.md) is a complete walkthrough that adds associations and single-query join preloads, custom filters and sorts, and pattern-scoped `list_by/2` functions with shared delegates.

## Runtime configuration

`BoxTurtle.Runtime.Config.Helper.get_env/2` reads an environment variable, parses it into the type you want and validates it:

```elixir
# config/runtime.exs
import Config
alias BoxTurtle.Runtime.Config.Helper

config :my_app,
  # POOL_SIZE=20 -> 20; unset -> 10; POOL_SIZE=500 -> {:error, "value 500 not in specified range 1..100"}
  pool_size: Helper.get_env("POOL_SIZE", type: :integer, default: 10, in_range: 1..100),
  # HOSTS="a.example.com, b.example.com" -> ["a.example.com", "b.example.com"]
  hosts: Helper.get_env("HOSTS", type: :list, default: ["localhost"]),
  # LOG_LEVEL=debug -> :debug (must be an existing atom in the set)
  log_level: Helper.get_env("LOG_LEVEL", type: :atom, in_set: [:debug, :info, :warning], default: :info),
  # FEATURES='{"beta": true}' -> %{"beta" => true}
  features: Helper.get_env("FEATURES", type: :map, default: %{})
```

Supported types: `:string`, `:integer`, `:float`, `:boolean`, `:atom`, `:module`, `:charlist`, `:list`, `:tuple` and `:map` (JSON). Lists and tuples can have typed elements (`subtype:`). Atoms and modules must already exist, unless you pass `unsafe_atoms: true`. Invalid values come back as `{:error, message}`. With a validation and no `:default`, an unset variable is an error too.

`BoxTurtle.Runtime.Config.load_runtime_config/1` loads a separate `import Config` script (from any path, e.g. beside a release) into the application environment at runtime. `BoxTurtle.Runtime.Application.Helper.conditional_append/4` builds supervision trees whose children depend on a condition. Both modules' docs show complete setups.

## Module dispatch

Put a stable facade in front of a configurable implementation:

```elixir
# The contract (compiled before the facade).
defmodule MyApp.Mailer.API do
  @callback deliver(to :: String.t(), subject :: String.t()) :: {:ok, term()} | {:error, term()}
end

# The default implementation, found by the <facade>.Impl naming convention.
defmodule MyApp.Mailer.Impl do
  @behaviour MyApp.Mailer.API

  @impl true
  def deliver(to, subject), do: MyApp.SmtpClient.send(to, subject)
end

# The facade: implements MyApp.Mailer.API by forwarding each call to MyApp.Mailer.Impl,
# or to whatever `config :my_app, MyApp.Mailer, impl: ...` names.
defmodule MyApp.Mailer do
  use BoxTurtle.Runtime.DynamicInterface.ModuleDispatch, otp_app: :my_app
end

# Callers only know the facade.
defmodule MyApp.Accounts do
  def send_welcome(user), do: MyApp.Mailer.deliver(user.email, "Welcome!")
end
```

Tests swap in a Mox mock through config:

```elixir
# test/test_helper.exs
Mox.defmock(MyApp.Mailer.Mock, for: MyApp.Mailer.API)

# config/test.exs
config :my_app, MyApp.Mailer, impl: MyApp.Mailer.Mock

# test/my_app/accounts_test.exs
defmodule MyApp.AccountsTest do
  use ExUnit.Case, async: true
  import Mox

  setup :verify_on_exit!

  test "send_welcome/1 mails the user" do
    expect(MyApp.Mailer.Mock, :deliver, fn "ann@example.com", "Welcome!" -> {:ok, :sent} end)
    assert {:ok, :sent} = MyApp.Accounts.send_welcome(%{email: "ann@example.com"})
  end
end
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
```

```elixir
# config/dev.exs: only these modules log, at :debug level
config :my_app, debug_enabled_modules: [MyApp.Billing]
config :logger, level: :debug
```

`MyApp.Billing.total(%{items: [%{price: 5}, %{price: 7}]})` returns `12` and logs `prices: [5, 7]`. In builds where `MyApp.Billing` isn't listed, the `debug/2` calls stay in the code and log nothing.

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
