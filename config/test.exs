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

config :logger, level: :warning
