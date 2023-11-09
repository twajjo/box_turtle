defmodule BoxTurtle.Common.IdUtils do
  def generate_id do
    :rand.uniform(1_000_000_000)
  end

  def generate_uid() do
    BoxTurtle.Schema.Ecto.Ksuid.autogenerate()
  end
  defdelegate generate_ksuid(), to: __MODULE__, as: :generate_uid

  def generate_uuid do
    Ecto.UUID.generate
  end
end
