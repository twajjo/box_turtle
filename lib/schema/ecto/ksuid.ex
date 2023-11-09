defmodule BoxTurtle.Schema.Ecto.Ksuid do
  @behaviour Ecto.Type

  @impl Ecto.Type
  def type, do: :string

  @impl Ecto.Type
  def cast(ksuid)
      when is_binary(ksuid) and byte_size(ksuid) == 27,
      do: {:ok, ksuid}

  @impl Ecto.Type
  def cast(_), do: :error

  @impl Ecto.Type
  def embed_as(_format) do
    :self
  end

  @impl Ecto.Type
  def equal?(a, b) do
    a == b
  end

  @impl Ecto.Type
  def load(ksuid), do: {:ok, ksuid}

  @impl Ecto.Type
  def dump(binary) when is_binary(binary), do: {:ok, binary}
  def dump(_), do: :error

  @impl Ecto.Type
  def autogenerate(), do: Ksuid.generate()
end
