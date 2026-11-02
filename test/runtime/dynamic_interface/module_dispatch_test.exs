defmodule BoxTurtle.ModuleDispatchTest.Greeter.API do
  @callback hello() :: String.t()
  @callback greet(String.t(), String.t()) :: String.t()
end

defmodule BoxTurtle.ModuleDispatchTest.Greeter.Impl do
  @behaviour BoxTurtle.ModuleDispatchTest.Greeter.API

  @impl true
  def hello, do: "hello"

  @impl true
  def greet(greeting, name), do: "#{greeting}, #{name}"
end

defmodule BoxTurtle.ModuleDispatchTest.Shouty do
  @behaviour BoxTurtle.ModuleDispatchTest.Greeter.API

  @impl true
  def hello, do: "HELLO"

  @impl true
  def greet(greeting, name), do: String.upcase("#{greeting}, #{name}")
end

defmodule BoxTurtle.ModuleDispatchTest.Greeter do
  use BoxTurtle.Runtime.DynamicInterface.ModuleDispatch
end

defmodule BoxTurtle.ModuleDispatchTest.Configured do
  use BoxTurtle.Runtime.DynamicInterface.ModuleDispatch,
    behaviour: BoxTurtle.ModuleDispatchTest.Greeter.API,
    impl: BoxTurtle.ModuleDispatchTest.Greeter.Impl,
    otp_app: :box_turtle
end

defmodule BoxTurtle.ModuleDispatchTest.Stub do
  use BoxTurtle.Runtime.DynamicInterface.ModuleDispatch,
    behaviour: BoxTurtle.ModuleDispatchTest.Greeter.API,
    generate_stub: true
end

defmodule BoxTurtle.Runtime.DynamicInterface.ModuleDispatchTest do
  # Changes application env, so not async.
  use ExUnit.Case, async: false

  alias BoxTurtle.ModuleDispatchTest.{Configured, Greeter, Shouty, Stub}

  describe "default dispatch" do
    test "forwards every callback to <module>.Impl" do
      assert Greeter.hello() == "hello"
      assert Greeter.greet("Hi", "Ann") == "Hi, Ann"
      assert Greeter.impl_module() == Greeter.Impl
    end

    test "implements the behaviour" do
      behaviours =
        Greeter.__info__(:attributes) |> Keyword.get_values(:behaviour) |> List.flatten()

      assert Greeter.API in behaviours
    end
  end

  describe ":otp_app" do
    setup do
      on_exit(fn -> Application.delete_env(:box_turtle, Configured) end)
    end

    test "falls back to :impl when nothing is configured" do
      assert Configured.impl_module() == Greeter.Impl
      assert Configured.greet("Hi", "Bo") == "Hi, Bo"
    end

    test "reads the implementation from the application environment at runtime" do
      Application.put_env(:box_turtle, Configured, impl: Shouty)
      assert Configured.impl_module() == Shouty
      assert Configured.greet("Hi", "Bo") == "HI, BO"
    end
  end

  describe ":generate_stub" do
    test "defines every callback to return :ok" do
      assert Stub.hello() == :ok
      assert Stub.greet("Hi", "Cy") == :ok
    end
  end

  test "raises when the behaviour module does not exist" do
    assert_raise ArgumentError, fn ->
      Code.compile_string("""
      defmodule NoApiHere do
        use BoxTurtle.Runtime.DynamicInterface.ModuleDispatch
      end
      """)
    end
  end
end
