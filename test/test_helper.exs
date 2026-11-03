alias BoxTurtle.Test.{Migration, PgRepo, Repo}

# The mock config/test.exs points the BoxTurtle.Examples.Notifier facade at.
Mox.defmock(BoxTurtle.Examples.Notifier.Mock, for: BoxTurtle.Examples.Notifier.API)

{:ok, _} = Application.ensure_all_started(:ecto_sql)

# Start from an empty database on every run.
db = Repo.config()[:database]
for file <- [db, db <> "-shm", db <> "-wal"], do: File.rm(file)

# Switch the new file to WAL once, so the pool's connections don't race to do it ("database is locked").
{:ok, conn} = Exqlite.Sqlite3.open(db)
:ok = Exqlite.Sqlite3.execute(conn, "PRAGMA journal_mode=WAL")
:ok = Exqlite.Sqlite3.close(conn)

{:ok, _} = Repo.start_link()
Ecto.Migrator.run(Repo, [{0, Migration}], :up, all: true, log: false)
Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)

if System.get_env("BOX_TURTLE_PG_URL") do
  {:ok, _} = Application.ensure_all_started(:postgrex)
  _ = PgRepo.__adapter__().storage_down(PgRepo.config())
  :ok = PgRepo.__adapter__().storage_up(PgRepo.config())
  {:ok, _} = PgRepo.start_link()
  Ecto.Migrator.run(PgRepo, [{0, Migration}], :up, all: true, log: false)
  Ecto.Adapters.SQL.Sandbox.mode(PgRepo, :manual)
  ExUnit.start()
else
  ExUnit.start(exclude: [:postgres])
end
