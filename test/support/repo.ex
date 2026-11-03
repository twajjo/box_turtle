defmodule BoxTurtle.Test.Repo do
  use Ecto.Repo, otp_app: :box_turtle, adapter: Ecto.Adapters.SQLite3
end

# Only started when BOX_TURTLE_PG_URL is set; covers PostgreSQL-only features such as DISTINCT ON.
defmodule BoxTurtle.Test.PgRepo do
  use Ecto.Repo, otp_app: :box_turtle, adapter: Ecto.Adapters.Postgres
end

defmodule BoxTurtle.Test.Migration do
  use Ecto.Migration

  def change do
    create table(:authors) do
      add(:name, :string, null: false)
      timestamps(type: :utc_datetime)
    end

    create table(:posts) do
      add(:title, :string, null: false)
      add(:status, :string, null: false, default: "draft")
      add(:likes, :integer, null: false, default: 0)
      add(:author_id, references(:authors, on_delete: :delete_all))
      timestamps(type: :utc_datetime)
    end

    create(index(:posts, [:author_id]))

    # No timestamps and a KSUID key, to check nothing assumes :inserted_at or integer ids.
    create table(:tags, primary_key: false) do
      add(:id, :string, primary_key: true)
      add(:name, :string, null: false)
    end

    # A primary key not named :id.
    create table(:codes, primary_key: false) do
      add(:code, :string, primary_key: true)
      add(:label, :string)
    end
  end
end
