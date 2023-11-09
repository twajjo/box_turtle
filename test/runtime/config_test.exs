defmodule BoxTurtle.Runtime.Config.Test do
  @moduledoc false
  use ExUnit.Case, async: false

  describe "load_config/1" do
    setup do
      Application.put_env(:box_turtle, :test_not_replaced, "Still here")
      Application.put_env(:box_turtle, :test_integer_value, 123)
      Application.put_env(:box_turtle, :test_string_value, "Original")
      Application.put_env(:box_turtle, :test_atom_value, :original)
      Application.put_env(:box_turtle, :runtime_config_file, "test/support/runtime.exs")
    end

    test "replaces values referenced in the runtime script" do
      # Compile time
      assert(Application.get_env(:box_turtle, :test_not_replaced) == "Still here")
      assert(Application.get_env(:box_turtle, :test_integer_value) == 123)
      assert(Application.get_env(:box_turtle, :test_string_value) == "Original")
      assert(Application.get_env(:box_turtle, :test_atom_value) == :original)
      IO.puts("Loading Runtime Config from #{__MODULE__}")
      OsBase.Runtime.Config.load_runtime_config(:box_turtle)
      # Run time
      assert(Application.get_env(:box_turtle, :test_not_replaced) == "Still here")
      assert(Application.get_env(:box_turtle, :test_integer_value) != 123)
      assert(Application.get_env(:box_turtle, :test_string_value) != "Original")
      assert(Application.get_env(:box_turtle, :test_atom_value) != :original)
    end
  end
end
