import Config

config :box_turtle, ecto_repos: [BoxTurtle.Test.Repo]

config :box_turtle, BoxTurtle.Test.Repo,
  database: Path.expand("../test/support/box_turtle_test.db", __DIR__),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 2

config :logger, level: :warning
