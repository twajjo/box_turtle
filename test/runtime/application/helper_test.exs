defmodule OsBase.Runtime.Application.Helper.Test do
  require Logger

  use ExUnit.Case

  import OsBase.Runtime.Application.Helper

  describe "conditional_append/3" do
    test "appends new children if the condition validates to true" do
      assert(
        [:old_kids]
        |> conditional_append(2 > 1, [:new_kids]) == [:old_kids, :new_kids]
      )
    end

    test "appends new child if the condition validates to true" do
      assert(
        [:old_kids]
        |> conditional_append(2 > 1, :new_kids) == [:old_kids, :new_kids]
      )
    end
    test "does not append new children if the condition validates to false" do
      assert(
        [:old_kids]
        |> conditional_append(2 < 1, [:new_kids]) == [:old_kids]
      )
    end
    test "does not append new child if the condition validates to false" do
      assert(
        [:old_kids]
        |> conditional_append(2 < 1, :new_kids) == [:old_kids]
      )
    end
  end

  describe "conditional_append/4" do
    test "supports arguments to the evaluation function" do
      assert(
        [:old_kids]
        |> conditional_append(fn a, b -> a < b end, [:new_kids], [2, 1]) == [:old_kids]
      )
      assert(
        [:old_kids]
        |> conditional_append(fn a, b -> a < b end, :new_kids, [2, 1]) == [:old_kids]
      )
    end

    test "supports no arguments to the evaluation function" do
      assert(
        [:old_kids]
        |> conditional_append(fn -> true end, [:new_kids]) == [:old_kids, :new_kids]
      )
      assert(
        [:old_kids]
        |> conditional_append(fn -> true end, :new_kids) == [:old_kids, :new_kids]
      )
    end

    test "appends new children if the function evaluates to true" do
      assert(
        [:old_kids]
        |> conditional_append(fn -> true end, [:new_kids]) == [:old_kids, :new_kids]
      )
      assert(
        [:old_kids]
        |> conditional_append(fn -> true end, :new_kids) == [:old_kids, :new_kids]
      )
    end

    test "does not append new children if the function evaluates to false" do
      assert(
        [:old_kids]
        |> conditional_append(fn -> false end, [:new_kids]) == [:old_kids]
      )
      assert(
        [:old_kids]
        |> conditional_append(fn -> false end, :new_kids) == [:old_kids]
      )
    end
  end
end
