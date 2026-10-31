defmodule BoxTurtle.DataCase do
  @moduledoc """
  Tests that touch the SQLite test database. SQLite serializes writers, so these cases
  run synchronously.
  """
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      alias BoxTurtle.Test.{Author, Post, Repo, Tag}
      import BoxTurtle.DataCase
    end
  end

  setup tags do
    pid = Sandbox.start_owner!(BoxTurtle.Test.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
    :ok
  end

  def author_fixture(attrs \\ %{}) do
    {:ok, author} = attrs |> Enum.into(%{name: "Ursula"}) |> BoxTurtle.Test.Author.Change.create()
    author
  end

  def post_fixture(attrs \\ %{}) do
    {:ok, post} = attrs |> Enum.into(%{title: "A post"}) |> BoxTurtle.Test.Post.Change.create()
    post
  end

  @doc "Transforms changeset errors into a map of messages."
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
