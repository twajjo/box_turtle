defmodule BoxTurtle.Security.PasswordTest do
  use ExUnit.Case, async: true

  alias BoxTurtle.Security.Password

  describe "generate/1" do
    test "defaults to the minimum length" do
      assert {:ok, password} = Password.generate()
      assert String.length(password) == Password.min_length()
    end

    test "returns a password of exactly the requested length" do
      for length <- [8, 9, 16, 64] do
        assert {:ok, password} = Password.generate(length)
        assert String.length(password) == length
      end
    end

    test "always includes a lowercase, uppercase, digit and special character" do
      for _ <- 1..200 do
        {:ok, password} = Password.generate(8)
        assert password =~ ~r/[a-z]/
        assert password =~ ~r/[A-Z]/
        assert password =~ ~r/[0-9]/
        assert password =~ ~r/[^a-zA-Z0-9]/
      end
    end

    test "produces different passwords" do
      passwords = for _ <- 1..50, do: elem(Password.generate(16), 1)
      assert passwords |> Enum.uniq() |> length() == 50
    end

    test "rejects lengths below the minimum and non-integers" do
      assert Password.generate(7) == {:error, :too_short}
      assert Password.generate(0) == {:error, :too_short}
      assert Password.generate(-3) == {:error, :too_short}
      assert Password.generate("12") == {:error, :too_short}
    end

    test "does not change the caller's :rand seed" do
      :rand.seed(:exsss, {1, 2, 3})
      expected = :rand.uniform(1_000_000)
      :rand.seed(:exsss, {1, 2, 3})
      {:ok, _} = Password.generate(32)
      assert :rand.uniform(1_000_000) == expected
    end
  end
end
