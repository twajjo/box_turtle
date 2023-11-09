defmodule Test.ModuleModule do
  defmacro make_module(module) do
    quote do
      defmodule unquote(module) do
        @compile {:no_warn_undefined, BoxTurtle.Debug.Test.FakeLogger.Mock}
        @compile {:no_warn_undefined, {BoxTurtle.Debug.Test.FakeLogger.Mock, :debug, 1}}
        @compile {:no_warn_undefined, {BoxTurtle.Debug.Test.FakeLogger.Mock, :info, 1}}
        use BoxTurtle.Debug.PipeDebug, logger_module: BoxTurtle.Debug.PipeDebug.Test.FakeLogger.Mock

        def debug_something(something) do
          something
          |> debug("From #{__MODULE__}")
        end
        def debug_something(something, condition) do
          something
          |> debug("Conditional #{condition.(something)} from #{__MODULE__}", condition: condition)
        end
      end
    end
  end
end

defmodule BoxTurtle.Debug.PipeDebug.Test do
  @moduledoc false

  use ExUnit.Case

  require Test.ModuleModule

  import Mox

  defmodule FakeLogger.API do
    @callback debug(binary()) :: :ok
    @callback info(binary()) :: :ok
  end

  setup_all do
    BoxTurtle.Debug.PipeDebug.Test.FakeLogger
    |> Module.concat(Mock)
    |> Mox.defmock(for: Module.concat(FakeLogger, API))

    :ok
  end

  @compile {:no_warn_undefined, BoxTurtle.Debug.Test.FakeLogger.Mock}
  @compile {:no_warn_undefined, {BoxTurtle.Debug.Test.FakeLogger.Mock, :debug, 1}}
  @compile {:no_warn_undefined, {BoxTurtle.Debug.Test.FakeLogger.Mock, :info, 1}}
  Test.ModuleModule.make_module(A)
  Test.ModuleModule.make_module(B)

  @fake_logger BoxTurtle.Debug.PipeDebug.Test.FakeLogger.Mock

  describe "debug/3" do
    test "Will only log debug messages from enabled modules" do
      Application.put_env(:box_turtle, :debug_enabled_modules, [])
      Application.put_env(:box_turtle, :logger_macro, :debug)
      expect(@fake_logger, :debug, 0, fn _ -> :ok end)
      expect(@fake_logger, :info, 0, fn _ -> :ok end)
      assert(A.debug_something("Warf") == "Warf")
      expect(@fake_logger, :debug, 0, fn _ -> :ok end)
      expect(@fake_logger, :info, 0, fn _ -> :ok end)
      assert(B.debug_something("Werf") == "Werf")
      Application.put_env(:box_turtle, :debug_enabled_modules, [A])
      Application.put_env(:box_turtle, :logger_macro, :debug)
      expect(@fake_logger, :debug, 1, fn _ -> :ok end)
      expect(@fake_logger, :info, 0, fn _ -> :ok end)
      assert(A.debug_something("Narf") == "Narf")
      expect(@fake_logger, :debug, 0, fn _ -> :ok end)
      expect(@fake_logger, :info, 0, fn _ -> :ok end)
      assert(B.debug_something("Nerf") == "Nerf")
      Application.put_env(:box_turtle, :debug_enabled_modules, [B])
      Application.put_env(:box_turtle, :logger_macro, :debug)
      expect(@fake_logger, :debug, 0, fn _ -> :ok end)
      expect(@fake_logger, :info, 0, fn _ -> :ok end)
      assert(A.debug_something("Scarf") == "Scarf")
      expect(@fake_logger, :debug, 1, fn _ -> :ok end)
      expect(@fake_logger, :info, 0, fn _ -> :ok end)
      assert(B.debug_something("Surf") == "Surf")
      Application.put_env(:box_turtle, :debug_enabled_modules, [A, B])
      Application.put_env(:box_turtle, :logger_macro, :debug)
      expect(@fake_logger, :debug, 1, fn _ -> :ok end)
      expect(@fake_logger, :info, 0, fn _ -> :ok end)
      assert(A.debug_something("Scarf") == "Scarf")
      expect(@fake_logger, :debug, 1, fn _ -> :ok end)
      expect(@fake_logger, :info, 0, fn _ -> :ok end)
      assert(B.debug_something("Surf") == "Surf")
    end
    test "Will log debug messages conditionally" do
      Application.put_env(:box_turtle, :debug_enabled_modules, [A])
      Application.put_env(:box_turtle, :logger_macro, :debug)
      expect(@fake_logger, :debug, 1, fn _ -> :ok end)
      expect(@fake_logger, :info, 0, fn _ -> :ok end)
      assert(A.debug_something(2, fn value -> Enum.member?(1..5, value) end) == 2)
      expect(@fake_logger, :debug, 1, fn _ -> :ok end)
      assert(A.debug_something(10, fn value -> Enum.member?(1..5, value) end) == 10)
    end
  end
end
