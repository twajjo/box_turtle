defmodule BoxTurtle.Runtime.DynamicInterface.ModuleDispatch do
  @moduledoc """
  Generates a module that implements a behaviour by forwarding every callback to an implementation module,
  or by generating no-op stubs.

  Lets callers depend on a stable facade (`MyApp.Mailer`) while the implementation (`MyApp.Mailer.Impl`,
  a Mox mock in tests, ...) is chosen by configuration.

  ## Usage

      defmodule MyApp.Mailer do
        use BoxTurtle.Runtime.DynamicInterface.ModuleDispatch, otp_app: :my_app
      end

      # config/test.exs
      config :my_app, MyApp.Mailer, impl: MyApp.Mailer.Mock

  ## Options

    * `:behaviour` - the behaviour to implement. Defaults to `<using module>.API`. It must be compiled before
      the using module.
    * `:impl` - the default implementation module. Defaults to `<using module>.Impl`.
    * `:otp_app` - when given, `impl_module/0` reads `config :otp_app, <using module>, impl: module` at runtime,
      falling back to `:impl`.
    * `:generate_stub` - when `true`, every callback is defined to return `:ok` instead of forwarding.
      Defaults to `false`. Combine it with `Application.compile_env/3` to stub a fire-and-forget
      interface out of some builds.

  ## Patterns

  Because `impl_module/0` reads the configuration on every call, one facade supports:

    * **per-build implementations** - set `impl:` differently in `config/dev.exs`, `test.exs` and `prod.exs`;
    * **runtime switching** - `Application.put_env/3` takes effect on the next call (failover, feature flags);
    * **Mox** - point `impl:` at `Mox.defmock(MyApp.Mailer.Mock, for: MyApp.Mailer.API)` in the test
      build, and use `Mox.stub_with/2` to fall back to a real implementation;
    * **A/B tests** - make the configured implementation a router that implements the same behaviour
      and picks a variant per caller.

  Worked examples of each, with fake implementations and the tests that use them, are in the
  repository: `test/support/examples/dispatch.ex` and
  `test/runtime/dynamic_interface/dispatch_examples_test.exs`.
  """

  defmacro __using__(opts) do
    caller = __CALLER__.module

    behaviour_module =
      opts
      |> Keyword.get(:behaviour, Module.concat(caller, "API"))
      |> Macro.expand(__CALLER__)
      |> Code.ensure_compiled!()

    impl_module =
      opts |> Keyword.get(:impl, Module.concat(caller, "Impl")) |> Macro.expand(__CALLER__)

    otp_app = Keyword.get(opts, :otp_app)
    stub? = Keyword.get(opts, :generate_stub, false)

    callbacks =
      for {fun, arity} <- behaviour_module.behaviour_info(:callbacks) do
        args = Macro.generate_arguments(arity, __MODULE__)
        if stub?, do: stub_def(fun, args), else: forward_def(fun, args)
      end

    quote do
      @behaviour unquote(behaviour_module)

      unquote_splicing(callbacks)

      @doc "The module callbacks are forwarded to."
      @spec impl_module() :: module()
      unquote(impl_module_def(otp_app, impl_module))
    end
  end

  defp stub_def(fun, args) do
    ignored = Enum.map(args, fn {name, meta, ctx} -> {:"_#{name}", meta, ctx} end)

    quote do
      @impl true
      def unquote(fun)(unquote_splicing(ignored)), do: :ok
    end
  end

  defp forward_def(fun, args) do
    quote do
      @impl true
      def unquote(fun)(unquote_splicing(args)),
        do: impl_module().unquote(fun)(unquote_splicing(args))
    end
  end

  defp impl_module_def(nil, impl_module) do
    quote do
      def impl_module, do: unquote(impl_module)
    end
  end

  defp impl_module_def(otp_app, impl_module) do
    quote do
      def impl_module do
        unquote(otp_app)
        |> Application.get_env(__MODULE__, [])
        |> Keyword.get(:impl, unquote(impl_module))
      end
    end
  end
end
