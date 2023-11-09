defmodule BoxTurtle.Security.Password do
  @moduledoc """
  Generates a random password with at minimum one upper case, one lower case, one digit and one special character.

  Slightly modified code blatantly stolen from [here](https://rosettacode.org/wiki/Password_generator#Elixir)
"""
  @min_length 8
  @lower Enum.map(?a..?z, &to_string([&1]))
  @upper Enum.map(?A..?Z, &to_string([&1]))
  @digit Enum.map(?0..?9, &to_string([&1]))
  @other ~S"""
!"#$%&'()*+,-./:;<=>?@[]^_{|}~
""" |> String.codepoints |> List.delete_at(-1)
  @all @lower ++ @upper ++ @digit ++ @other

  @doc """
  Generate a random password string containing 1 or more uppercase, lowercase, digit and special characters of
  the specified length.

  # Parameters

    length - the number of characters in the generated password.  Passwords of less than 4 characters are not
      allowed.

  # Returns

    {:ok, password} - if the proper length is provided.
    {:error, reason} - if the password cannot be generated.
"""
  @spec generate(integer()) :: {:error, binary()} | {:ok, binary()}
  def generate(length \\ @min_length)
  def generate(length) when length >= @min_length do
    pswd = [Enum.random(@lower), Enum.random(@upper), Enum.random(@digit), Enum.random(@other)]
    {:ok, generator(length - @min_length, pswd)}
  end
  def generate(_bad_len) do
    {:error, "Passwords cannot be less than #{@min_length} characters in length"}
  end

  defp generator(0, pswd), do: Enum.shuffle(pswd) |> Enum.join
  defp generator(len, pswd), do: generator(len-1, [Enum.random(@all) | pswd])
end
