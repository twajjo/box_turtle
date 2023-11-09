defmodule BoxTurtle.Runtime.Config.Helper.Test do
  require Logger

  use ExUnit.Case

  alias BoxTurtle.Runtime.Config.Helper

  defmodule CustomValidator do
    def valid(value, _opt) do
      value
    end

    def invalid(_value, _opt) do
      {:error, "That is not what I expected!"}
    end
  end

  describe "get_env/2" do
    test "gets a string by default" do
      System.put_env("STRING_VAR", "string_val")
      assert(Helper.get_env("STRING_VAR") == "string_val")
    end

    test "supports type :string" do
      System.put_env("STRING_VAR", "string_val")
      assert(Helper.get_env("STRING_VAR", type: :string) == "string_val")
    end

    test "supports type :integer" do
      System.put_env("INTEGER_VAR", "23")
      assert(Helper.get_env("INTEGER_VAR", type: :integer) == 23)
    end

    test "supports type :float" do
      System.put_env("FLOAT_VAR", "3.14")
      assert(Helper.get_env("FLOAT_VAR", type: :float) == 3.14)
    end

    test "supports type :boolean" do
      System.put_env("BOOLEAN_VAR", "true")
      assert(Helper.get_env("BOOLEAN_VAR", type: :boolean) == true)
    end

    test "supports type :atom" do
      System.put_env("ATOM_VAR", "atom")
      assert(Helper.get_env("ATOM_VAR", type: :atom) == :atom)
    end

    test "supports type :module" do
      System.put_env("MODULE_VAR", "Elixir.BoxTurtle.Runtime.Config.Helper")
      assert(Helper.get_env("MODULE_VAR", type: :module) == BoxTurtle.Runtime.Config.Helper)
    end

    test "supports type :charlist" do
      System.put_env("CHARLIST_VAR", "Mott the Hoople")
      assert(Helper.get_env("CHARLIST_VAR", type: :charlist) == 'Mott the Hoople')
    end

    test "supports type :list" do
      System.put_env("LIST_VAR", "fish,cut,bait")
      assert(Helper.get_env("LIST_VAR", type: :list) == ["fish", "cut", "bait"])
      assert(Helper.get_env("LIST_VAR", type: :list, subtype: :string) == ["fish", "cut", "bait"])
    end

    test "supports type list of atoms" do
      System.put_env("LIST_VAR", "fish,cut,bait")
      assert(Helper.get_env("LIST_VAR", type: :list, subtype: :atom) == [:fish, :cut, :bait])
    end

    test "supports type list of integers" do
      System.put_env("LIST_VAR", "1,2,3")
      assert(Helper.get_env("LIST_VAR", type: :list, subtype: :integer) == [1, 2, 3])
    end

    test "supports type :tuple" do
      System.put_env("TUPLE_VAR", "fish,cut,bait")
      assert(Helper.get_env("TUPLE_VAR", type: :tuple) == {"fish", "cut", "bait"})
      assert(Helper.get_env("TUPLE_VAR", type: :tuple, subtype: :string) == {"fish", "cut", "bait"})
    end

    test "supports type :tuple of all :atom entries" do
      System.put_env("TUPLE_VAR", "fish,cut,bait")
      assert(Helper.get_env("TUPLE_VAR", type: :tuple, subtype: :atom) == {:fish, :cut, :bait})
    end

    test "supports type :tuple of all :integer entries" do
      System.put_env("TUPLE_VAR", "1,2,3")
      assert(Helper.get_env("TUPLE_VAR", type: :tuple, subtype: :integer) == {1, 2, 3})
    end

    test "supports default values for unset variables" do
      System.delete_env("INTEGER_VAR")
      System.delete_env("FLOAT_VAR")
      System.delete_env("BOOLEAN_VAR")
      System.delete_env("ATOM_VAR")
      System.delete_env("MODULE_VAR")
      System.delete_env("STRING_VAR")
      System.delete_env("LIST_VAR")
      System.delete_env("TUPLE_VAR")
      assert(Helper.get_env("INTEGER_VAR", default: 17, type: :integer) == 17)
      assert(Helper.get_env("FLOAT_VAR", default: 98.6, type: :float) == 98.6)
      assert(Helper.get_env("BOOLEAN_VAR", default: true, type: :boolean) == true)
      assert(Helper.get_env("ATOM_VAR", default: :ant, type: :atom) == :ant)
      assert(Helper.get_env("MODULE_VAR", default: BoxTurtle.Runtime.Config, type: :module) == BoxTurtle.Runtime.Config)
      assert(Helper.get_env("STRING_VAR", default: "narf", type: :string) == "narf")
      assert(Helper.get_env("LIST_VAR", default: ~w(winkin blinkin nod), type: :list) == ~w(winkin blinkin nod))
      assert(Helper.get_env("TUPLE_VAR", default: {"winkin", "blinkin", "nod"}, type: :tuple) == {"winkin", "blinkin", "nod"})
    end

    test "supports validation :in_set" do
      System.put_env("STRING_VAR", "2")
      assert(Helper.get_env("STRING_VAR", in_set: ~w(1 2 3)) == "2")
      assert({:error, _} = Helper.get_env("STRING_VAR", in_set: ~w(nope not in there)))
      System.put_env("INTEGER_VAR", "2")
      assert(Helper.get_env("INTEGER_VAR", type: :integer, in_set: [1, 2, 3]) == 2)
      assert({:error, _} = Helper.get_env("INTEGER_VAR", type: :integer, in_set: [1, 0, 3]))
      System.put_env("FLOAT_VAR", "2.0")
      assert(Helper.get_env("FLOAT_VAR", type: :float, in_set: [1.0, 2.0, 3.0]) == 2.0)
      assert({:error, _} = Helper.get_env("FLOAT_VAR", type: :float, in_set: [1.0, 0.0, 3.0]))
    end

    test "supports validation :in_range" do
      System.put_env("INTEGER_VAR", "23")
      assert(Helper.get_env("INTEGER_VAR", type: :integer, in_range: 1..100) == 23)
      assert({:error, _} = Helper.get_env("INTEGER_VAR", type: :integer, in_range: 50..100))
    end

    test "supports validation :regex" do
      System.put_env("STRING_VAR", "string_val")
      assert(Helper.get_env("STRING_VAR", type: :string, regex: ~r/^.*_val$/) == "string_val")
      assert({:error, _} = Helper.get_env("STRING_VAR", type: :string, regex: ~r/^.*_flurshinger$/))
    end

    test "supports custom validation" do
      System.put_env("STRING_VAR", "string_val")
      assert(Helper.get_env("STRING_VAR", custom: {CustomValidator, :valid}) == "string_val")
      assert({:error, _} = Helper.get_env("STRING_VAR", custom: {CustomValidator, :invalid}))
    end

    test "returns nil if no default given, variable is unset in the environment and no validations are specified" do
      System.delete_env("UNDEFINED_VAR")
      assert(is_nil(Helper.get_env("UNDEFINED_VAR")))
    end
  end

end
