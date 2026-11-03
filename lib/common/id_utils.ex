defmodule BoxTurtle.Common.IdUtils do
  @moduledoc """
  Small helpers for generating identifiers.

      alias BoxTurtle.Common.IdUtils

      IdUtils.generate_ksuid()  #=> "2Ux8k3WmS1mXJ9i1QeB6LcPq0Zf" (unique, sortable by time)
      IdUtils.generate_uuid()   #=> "5b0e3f4a-8c1d-4d2e-9f6a-1b2c3d4e5f60" (unique, random)
      IdUtils.generate_id()     #=> 734_201_558 (NOT unique: test data and labels only)
  """

  alias BoxTurtle.Schema.Ecto.Ksuid

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
    Ksuid.autogenerate()
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
