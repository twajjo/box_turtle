defmodule BoxTurtle.Security.Password do
  @moduledoc """
  Generates random passwords containing at least one lowercase letter, one uppercase letter,
  one digit and one special character.

  All randomness comes from `:crypto.strong_rand_bytes/1` (through `:crypto.rand_seed_s/0`),
  so the passwords are suitable for credentials. The caller's `:rand` seed is not touched.

      alias BoxTurtle.Security.Password

      {:ok, password} = Password.generate(16)
      String.length(password)  #=> 16
      {:error, :too_short} = Password.generate(4)

      # e.g. a temporary password for an account created by an admin
      def create_invited_user(attrs) do
        {:ok, password} = Password.generate(20)
        attrs |> Map.put(:password, password) |> MyApp.Accounts.register_user()
      end

  The approach is inspired by the Rosetta Code
  [Password generator](https://rosettacode.org/wiki/Password_generator) task.
  """

  @min_length 8
  @lower Enum.map(?a..?z, &<<&1>>)
  @upper Enum.map(?A..?Z, &<<&1>>)
  @digit Enum.map(?0..?9, &<<&1>>)
  @other String.codepoints("!\"#$%&'()*+,-./:;<=>?@[]^_{|}~")
  @all @lower ++ @upper ++ @digit ++ @other

  @doc """
  Returns the minimum password length accepted by `generate/1` (#{@min_length}).
  """
  @spec min_length() :: pos_integer()
  def min_length, do: @min_length

  @doc """
  Generates a random password of `length` characters (default #{@min_length}).

  Returns `{:ok, password}`, or `{:error, :too_short}` when `length` is not an integer of at
  least #{@min_length}.
  """
  @spec generate(integer()) :: {:ok, String.t()} | {:error, :too_short}
  def generate(length \\ @min_length)

  def generate(length) when is_integer(length) and length >= @min_length do
    state = :crypto.rand_seed_s()
    {required, state} = Enum.map_reduce([@lower, @upper, @digit, @other], state, &pick/2)
    {rest, state} = Enum.map_reduce(1..(length - 4)//1, state, fn _, st -> pick(@all, st) end)
    {password, _state} = shuffle(required ++ rest, state)
    {:ok, Enum.join(password)}
  end

  def generate(_length), do: {:error, :too_short}

  defp pick(chars, state) do
    {index, state} = :rand.uniform_s(length(chars), state)
    {Enum.at(chars, index - 1), state}
  end

  defp shuffle(chars, state) do
    {keyed, state} = Enum.map_reduce(chars, state, fn char, st -> with_key(char, st) end)
    {keyed |> Enum.sort() |> Enum.map(&elem(&1, 1)), state}
  end

  defp with_key(char, state) do
    {key, state} = :rand.uniform_s(state)
    {{key, char}, state}
  end
end
