defmodule BoxTurtle.Common.IdUtils do
  @moduledoc """
  Small helpers for generating identifiers.
  """

  @doc """
  Returns a random integer between 1 and 1,000,000,000.

  This is **not** a unique identifier: values can and will collide once many are generated,
  and they are not cryptographically random. Use it for test data or throwaway labels; use
  `generate_ksuid/0` or `generate_uuid/0` for anything that must be unique.
  """
  @spec generate_id() :: pos_integer()
  def generate_id do
    :rand.uniform(1_000_000_000)
  end

  @doc """
  Returns a new, time-sortable KSUID string (see `BoxTurtle.Schema.Ecto.Ksuid`).
  """
  @spec generate_ksuid() :: String.t()
  def generate_ksuid do
    BoxTurtle.Schema.Ecto.Ksuid.autogenerate()
  end

  @doc """
  Same as `generate_ksuid/0`.
  """
  @spec generate_uid() :: String.t()
  defdelegate generate_uid(), to: __MODULE__, as: :generate_ksuid

  @doc """
  Returns a new random (version 4) UUID string.
  """
  @spec generate_uuid() :: String.t()
  def generate_uuid do
    Ecto.UUID.generate()
  end
end
