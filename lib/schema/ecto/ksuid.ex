defmodule BoxTurtle.Schema.Ecto.Ksuid do
  @moduledoc """
  An `Ecto.Type` for [KSUID](https://github.com/segmentio/ksuid) keys, stored as 27-character base62 strings.
  KSUIDs sort by creation time, which makes them convenient primary keys.

      defmodule MyApp.Blog.Tag do
        use Ecto.Schema

        # Generated on insert; @foreign_key_type makes belongs_to fields KSUIDs too.
        @primary_key {:id, BoxTurtle.Schema.Ecto.Ksuid, autogenerate: true}
        @foreign_key_type BoxTurtle.Schema.Ecto.Ksuid

        schema "tags" do
          field :name, :string
        end
      end

      # The migration stores the key as a string column.
      defmodule MyApp.Repo.Migrations.CreateTags do
        use Ecto.Migration

        def change do
          create table(:tags, primary_key: false) do
            add :id, :string, size: 27, primary_key: true
            add :name, :string, null: false
          end
        end
      end

      {:ok, tag} = MyApp.Repo.insert(%MyApp.Blog.Tag{name: "elixir"})
      tag.id #=> "2Ux8k3WmS1mXJ9i1QeB6LcPq0Zf"
  """
  use Ecto.Type

  @impl Ecto.Type
  def type, do: :string

  @impl Ecto.Type
  def cast(ksuid) when is_binary(ksuid) do
    if valid?(ksuid), do: {:ok, ksuid}, else: :error
  end

  def cast(_), do: :error

  @impl Ecto.Type
  def load(ksuid) when is_binary(ksuid), do: {:ok, ksuid}
  def load(_), do: :error

  @impl Ecto.Type
  def dump(ksuid) when is_binary(ksuid), do: {:ok, ksuid}
  def dump(_), do: :error

  @impl Ecto.Type
  def autogenerate, do: Ksuid.generate()

  @doc "True for a 27-character base62 string."
  @spec valid?(term()) :: boolean()
  def valid?(ksuid) when is_binary(ksuid) and byte_size(ksuid) == 27 do
    for <<char <- ksuid>>, reduce: true do
      valid? -> valid? and (char in ?0..?9 or char in ?A..?Z or char in ?a..?z)
    end
  end

  def valid?(_), do: false
end
