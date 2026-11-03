import Config

config :box_turtle, ecto_repos: [BoxTurtle.Test.Repo]

config :box_turtle, BoxTurtle.Test.Repo,
  database: Path.expand("../test/support/box_turtle_test.db", __DIR__),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 2

# PostgreSQL tests (tagged :postgres) run only when BOX_TURTLE_PG_URL is set, e.g.
# BOX_TURTLE_PG_URL=postgres://postgres:postgres@localhost:5432/box_turtle_test mix test
config :box_turtle, BoxTurtle.Test.PgRepo,
  url: System.get_env("BOX_TURTLE_PG_URL"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 2

# Build-type choices for the ModuleDispatch examples (test/support/examples/dispatch.ex).
# In an application these lines would live in config/test.exs, while config/prod.exs would leave
# the defaults in place.
config :box_turtle, :examples, stub_analytics: true
config :box_turtle, BoxTurtle.Examples.Notifier, impl: BoxTurtle.Examples.Notifier.Mock

config :logger, level: :warning
