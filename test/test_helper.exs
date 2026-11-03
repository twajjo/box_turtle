alias BoxTurtle.Test.Repo

# Start from an empty database on every run.
db = Repo.config()[:database]
for file <- [db, db <> "-shm", db <> "-wal"], do: File.rm(file)

# Switch the new file to WAL once, so the pool's connections don't race to do it ("database is locked").
{:ok, conn} = Exqlite.Sqlite3.open(db)
:ok = Exqlite.Sqlite3.execute(conn, "PRAGMA journal_mode=WAL")
:ok = Exqlite.Sqlite3.close(conn)

{:ok, _} = Application.ensure_all_started(:ecto_sql)
{:ok, _} = Repo.start_link()
Ecto.Migrator.run(Repo, [{0, BoxTurtle.Test.Migration}], :up, all: true, log: false)
Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)

ExUnit.start()
