defmodule BoxTurtle.Test.Support.Utils do
  def generate_id do
    :rand.uniform(1_000_000_000)
  end

  def generate_uid() do
    BoxTurtle.Schema.Ecto.Ksuid.autogenerate()
  end

  defdelegate generate_ksuid(), to: __MODULE__, as: :generate_uid

  def generate_uuid do
    Ecto.UUID.generate()
  end

  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
