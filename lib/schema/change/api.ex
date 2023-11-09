defmodule BoxTurtle.Schema.Change.API do
  @moduledoc """
  Basic CUD (missing Read, so a COW's paritally digested dinner) operations for changing a schema object
  backed by a relational database or any other data store.

  Could be used to front SQL, NoSQL, Redis, ETS, etc.

  The purpose of this interface is to support and enforce change operation consistency across schema objects.

  Counterpoint to the sibling Query.API, but for basic write operations: create, update, delete.
  With the idea that NOBODY outside a Change or Query touches the Repo or other underlying storage container.
  """
  @callback delete!(integer() | String.t() | Ecto.Schema.t()) :: nil | Ecto.Schema.t()
  @callback delete(integer() | String.t() | Ecto.Schema.t()) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}

  @callback update!(Ecto.Schema.t(), map() | Ecto.Schema.t()) :: Ecto.Changeset.t()
  @callback update!(Ecto.Changeset.t()) :: EctoChangeset.t()
  @callback update(Ecto.Schema.t(), map() | Ecto.Schema.t()) :: {:ok, Ecto.Changeset.t()} | {:error, any()}
  @callback update(Ecto.Changeset.t()) :: {:ok, Ecto.Changeset.t()} | {:error, Ecto.Changeset.t()}

  @callback create!(map() | Ecto.Schema.t() | Ecto.Changeset.t()) :: Ecto.Schema.t()
  @callback create(map() | Ecto.Schema.t() | Ecto.Changeset.t()) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  @callback create!(new_child :: map() | Ecto.Schema.t() | Ecto.Changeset.t(), parent :: Ecto.Schema.t()) :: Ecto.Schema.t()
  @callback create(new_child :: map() | Ecto.Schema.t() | Ecto.Changeset.t(), parent :: Ecto.Schema.t()) :: {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}

  @optional_callbacks [
    create: 2,
    create!: 2
  ]
end
