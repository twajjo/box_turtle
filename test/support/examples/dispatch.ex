# Reference use of BoxTurtle.Runtime.DynamicInterface.ModuleDispatch, exercised by
# test/runtime/dynamic_interface/dispatch_examples_test.exs.
#
# The pattern: callers depend on a facade module (`Notifier`) that implements a behaviour
# (`Notifier.API`) by forwarding each call to whichever implementation the configuration names.
# Because the implementation is looked up on every call, it can be chosen
#
#   * per build type, in config/dev.exs, config/test.exs and config/prod.exs;
#   * at runtime, with Application.put_env/3 (feature flags, failover, A/B tests);
#   * per test, with a Mox mock that can fall back to a real implementation.
#
# The implementations below are fakes standing in for real email/SMS providers: they validate and
# format like a real adapter would, and "send" by returning a receipt, so the examples can show
# which implementation handled a call.

defmodule BoxTurtle.Examples.Notifier.API do
  @moduledoc """
  The contract every notifier implementation fulfils. The facade and all implementations
  share it, which is also what lets Mox build a mock of it.
  """

  @typedoc "What a delivery returns: which implementation handled it, and what it sent."
  @type receipt :: %{channel: atom(), variant: atom(), to: String.t(), body: String.t()}

  @callback deliver(recipient :: String.t(), message :: String.t()) ::
              {:ok, receipt()} | {:error, :invalid_recipient}
end

defmodule BoxTurtle.Examples.Notifier do
  @moduledoc """
  The facade. Code everywhere calls `Notifier.deliver/2`; it forwards to `Notifier.Impl` unless
  the configuration names another module:

      # config/prod.exs: production uses the real provider (the default, so optional)
      config :box_turtle, BoxTurtle.Examples.Notifier, impl: BoxTurtle.Examples.Notifier.Impl

      # config/test.exs: tests get a Mox mock
      config :box_turtle, BoxTurtle.Examples.Notifier, impl: BoxTurtle.Examples.Notifier.Mock

  No `:behaviour` or `:impl` options are needed because the modules follow the naming
  convention: `<facade>.API` and `<facade>.Impl`.
  """
  use BoxTurtle.Runtime.DynamicInterface.ModuleDispatch, otp_app: :box_turtle
end

defmodule BoxTurtle.Examples.Notifier.Impl do
  @moduledoc "The default implementation: a plain-text email (fake transport)."
  @behaviour BoxTurtle.Examples.Notifier.API

  @impl true
  def deliver(recipient, message) do
    if String.contains?(recipient, "@"),
      do: {:ok, %{channel: :email, variant: :plain, to: recipient, body: message}},
      else: {:error, :invalid_recipient}
  end
end

defmodule BoxTurtle.Examples.Notifier.RichEmail do
  @moduledoc "A candidate replacement: the same email as HTML. The B side of the A/B test."
  @behaviour BoxTurtle.Examples.Notifier.API

  @impl true
  def deliver(recipient, message) do
    if String.contains?(recipient, "@"),
      do: {:ok, %{channel: :email, variant: :html, to: recipient, body: "<p>#{message}</p>"}},
      else: {:error, :invalid_recipient}
  end
end

defmodule BoxTurtle.Examples.Notifier.Sms do
  @moduledoc "A different channel behind the same contract: SMS, truncated to 160 characters."
  @behaviour BoxTurtle.Examples.Notifier.API

  @impl true
  def deliver("+" <> digits = recipient, message) do
    if digits =~ ~r/^\d{7,15}$/,
      do:
        {:ok,
         %{channel: :sms, variant: :plain, to: recipient, body: String.slice(message, 0, 160)}},
      else: {:error, :invalid_recipient}
  end

  def deliver(_recipient, _message), do: {:error, :invalid_recipient}
end

defmodule BoxTurtle.Examples.Notifier.Experiment do
  @moduledoc """
  An A/B router that is itself just another implementation of the contract, so switching the
  experiment on or off is a configuration change:

      config :box_turtle, BoxTurtle.Examples.Notifier, impl: BoxTurtle.Examples.Notifier.Experiment

      config :box_turtle, BoxTurtle.Examples.Notifier.Experiment,
        control: BoxTurtle.Examples.Notifier.Impl,
        candidate: BoxTurtle.Examples.Notifier.RichEmail,
        candidate_percent: 20

  Each recipient is assigned to a group by hashing their address, so a recipient always gets the
  same variant ("sticky" assignment), and `candidate_percent` can be raised gradually at runtime.
  """
  @behaviour BoxTurtle.Examples.Notifier.API

  @impl true
  def deliver(recipient, message), do: variant_for(recipient).deliver(recipient, message)

  @doc "The implementation `recipient` is assigned to under the current configuration."
  def variant_for(recipient) do
    config = Application.get_env(:box_turtle, __MODULE__, [])
    control = Keyword.fetch!(config, :control)
    candidate = Keyword.fetch!(config, :candidate)

    if :erlang.phash2(recipient, 100) < Keyword.get(config, :candidate_percent, 0),
      do: candidate,
      else: control
  end
end

defmodule BoxTurtle.Examples.Signup do
  @moduledoc """
  Application code that depends on the facade, never on an implementation. This is the code a
  Mox test exercises in isolation.
  """
  alias BoxTurtle.Examples.Notifier

  @doc "Sends the welcome message and reports which channel it went out on."
  def welcome(recipient, name) do
    with {:ok, %{channel: channel}} <- Notifier.deliver(recipient, "Welcome aboard, #{name}!") do
      {:ok, channel}
    end
  end
end

# Fire-and-forget interfaces can be stubbed out entirely in some builds with `generate_stub: true`:
# every callback just returns :ok. Here the choice is made at compile time from the build's
# config, which config/test.exs sets with `config :box_turtle, :examples, stub_analytics: true`.

defmodule BoxTurtle.Examples.Analytics.API do
  @moduledoc "A fire-and-forget interface, a good fit for build-time stubbing."
  @callback track(event :: String.t(), properties :: map()) :: :ok
end

defmodule BoxTurtle.Examples.Analytics.Impl do
  @moduledoc "The real tracker (fake transport: it messages the calling process)."
  @behaviour BoxTurtle.Examples.Analytics.API

  @impl true
  def track(event, properties) do
    send(self(), {:tracked, event, properties})
    :ok
  end
end

defmodule BoxTurtle.Examples.Analytics do
  @moduledoc """
  Stubbed in builds whose config sets `stub_analytics: true`, and live in every other build.
  """
  use BoxTurtle.Runtime.DynamicInterface.ModuleDispatch,
    generate_stub: Application.compile_env(:box_turtle, [:examples, :stub_analytics], false)
end

defmodule BoxTurtle.Examples.LiveAnalytics do
  @moduledoc "The same interface, always live, for comparison with the build-stubbed facade."
  use BoxTurtle.Runtime.DynamicInterface.ModuleDispatch,
    behaviour: BoxTurtle.Examples.Analytics.API,
    impl: BoxTurtle.Examples.Analytics.Impl
end
