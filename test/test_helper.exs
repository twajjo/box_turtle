alias BoxTurtle.Test.Repo

# Start from an empty database on every run.
db = Repo.config()[:database]
for file <- [db, db <> "-shm", db <> "-wal"], do: File.rm(file)

{:ok, _} = Application.ensure_all_started(:ecto_sql)
{:ok, _} = Repo.start_link()
Ecto.Migrator.run(Repo, [{0, BoxTurtle.Test.Migration}], :up, all: true, log: false)
Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)

ExUnit.start()
