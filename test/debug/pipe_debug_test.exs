defmodule BoxTurtle.Debug.PipeDebugTest.FakeLogger do
  @callback debug(binary()) :: :ok
  @callback info(binary()) :: :ok
end

Mox.defmock(BoxTurtle.Debug.PipeDebugTest.FakeLogger.Mock,
  for: BoxTurtle.Debug.PipeDebugTest.FakeLogger
)

for module <- [BoxTurtle.Debug.PipeDebugTest.A, BoxTurtle.Debug.PipeDebugTest.B] do
  defmodule module do
    use BoxTurtle.Debug.PipeDebug, logger_module: BoxTurtle.Debug.PipeDebugTest.FakeLogger.Mock

    def debug_something(something), do: debug(something, "From #{inspect(__MODULE__)}")

    def debug_something(something, condition) do
      debug(something, "Conditional from #{inspect(__MODULE__)}", condition: condition)
    end
  end
end

defmodule BoxTurtle.Debug.PipeDebugTest.InfoLevel do
  use BoxTurtle.Debug.PipeDebug,
    logger_module: BoxTurtle.Debug.PipeDebugTest.FakeLogger.Mock,
    logger_macro: :info

  def debug_something(something), do: debug(something)
end

defmodule BoxTurtle.Debug.PipeDebugTest do
  # Changes application env, so not async.
  use ExUnit.Case, async: false

  import Mox

  alias BoxTurtle.Debug.PipeDebugTest.{A, B, InfoLevel}
  alias BoxTurtle.Debug.PipeDebugTest.FakeLogger.Mock, as: FakeLogger

  setup :verify_on_exit!

  setup do
    on_exit(fn -> Application.delete_env(:box_turtle, :debug_enabled_modules) end)
  end

  defp enable(modules), do: Application.put_env(:box_turtle, :debug_enabled_modules, modules)

  describe "debug/3" do
    test "returns the value and logs nothing for modules that are not enabled" do
      enable([])
      assert A.debug_something("Warf") == "Warf"
      assert B.debug_something("Werf") == "Werf"
    end

    test "logs only for enabled modules" do
      enable([A])

      expect(FakeLogger, :debug, fn message ->
        assert message =~ ~s(From BoxTurtle.Debug.PipeDebugTest.A: "Narf")
      end)

      assert A.debug_something("Narf") == "Narf"
      assert B.debug_something("Nerf") == "Nerf"
    end

    test "logs for every enabled module" do
      enable([A, B])
      expect(FakeLogger, :debug, 2, fn _ -> :ok end)
      assert A.debug_something("Scarf") == "Scarf"
      assert B.debug_something("Surf") == "Surf"
    end

    test "logs only when the condition holds" do
      enable([A])
      in_range? = &(&1 in 1..5)
      expect(FakeLogger, :debug, 1, fn _ -> :ok end)
      assert A.debug_something(2, in_range?) == 2
      assert A.debug_something(10, in_range?) == 10
    end

    test "logs at the configured level" do
      enable([InfoLevel])
      expect(FakeLogger, :info, fn message -> assert message == ":hello" end)
      assert InfoLevel.debug_something(:hello) == :hello
    end

    test "works with the real Logger" do
      defmodule RealLogger do
        use BoxTurtle.Debug.PipeDebug
        def go(value), do: debug(value, "real")
      end

      enable([RealLogger])

      log =
        ExUnit.CaptureLog.capture_log([level: :debug], fn ->
          Logger.configure(level: :debug)
          assert RealLogger.go(42) == 42
        end)

      Logger.configure(level: :warning)
      assert log =~ "real: 42"
    end
  end

  test "rejects unsupported logger macros" do
    assert_raise ArgumentError, ~r/:logger_macro must be :debug or :info/, fn ->
      Code.compile_string(
        "defmodule BadDebug do use BoxTurtle.Debug.PipeDebug, logger_macro: :error end"
      )
    end
  end
end
