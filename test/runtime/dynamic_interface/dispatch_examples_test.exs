defmodule BoxTurtle.Runtime.DynamicInterface.DispatchExamplesTest do
  @moduledoc """
  Demonstrates the ModuleDispatch patterns in test/support/examples/dispatch.ex: choosing an
  implementation per build, switching it at runtime, mocking it with Mox, A/B testing, and
  stubbing an interface out of a build.
  """
  # These tests change application config, which is global, so they can't run concurrently.
  use ExUnit.Case, async: false

  import Mox

  alias BoxTurtle.Examples.{Analytics, LiveAnalytics, Notifier, Signup}
  alias BoxTurtle.Examples.Notifier.{Experiment, Impl, Mock, RichEmail, Sms}

  setup :verify_on_exit!

  # Restore the facade's test-build configuration (the Mox mock) after each test.
  setup do
    original = Application.get_env(:box_turtle, Notifier)

    on_exit(fn ->
      Application.put_env(:box_turtle, Notifier, original)
      Application.delete_env(:box_turtle, Experiment)
    end)
  end

  defp use_implementation(module), do: Application.put_env(:box_turtle, Notifier, impl: module)

  describe "choosing the implementation per build" do
    test "the test build's config points the facade at the Mox mock" do
      assert Notifier.impl_module() == Mock
    end

    test "with no configuration, the facade uses <facade>.Impl" do
      Application.delete_env(:box_turtle, Notifier)

      assert Notifier.impl_module() == Impl

      assert {:ok, %{channel: :email, variant: :plain}} =
               Notifier.deliver("ann@example.com", "Hi")
    end
  end

  describe "switching implementations at runtime" do
    test "a config change takes effect on the next call, without recompiling" do
      use_implementation(Impl)
      assert {:ok, :email} = Signup.welcome("ann@example.com", "Ann")

      # e.g. failing over to SMS, or a feature flag moving users to a new channel.
      use_implementation(Sms)
      assert {:ok, :sms} = Signup.welcome("+15551234567", "Ann")
    end

    test "every implementation honours the same contract, including errors" do
      for impl <- [Impl, RichEmail, Sms] do
        use_implementation(impl)
        assert {:error, :invalid_recipient} = Signup.welcome("not a recipient", "Ann")
      end
    end
  end

  describe "unit testing callers with Mox" do
    # No real implementation runs: the test decides what the notifier returns and checks how
    # Signup calls it.
    test "expectations verify the call and script the response" do
      expect(Mock, :deliver, fn "ann@example.com", message ->
        assert message == "Welcome aboard, Ann!"
        {:ok, %{channel: :email, variant: :plain, to: "ann@example.com", body: message}}
      end)

      assert {:ok, :email} = Signup.welcome("ann@example.com", "Ann")
    end

    test "failure paths can be scripted without a misbehaving provider" do
      expect(Mock, :deliver, fn _recipient, _message -> {:error, :invalid_recipient} end)
      assert {:error, :invalid_recipient} = Signup.welcome("ann@example.com", "Ann")
    end

    test "stub_with/2 falls back to a real implementation when a test doesn't care" do
      stub_with(Mock, Sms)
      assert {:ok, :sms} = Signup.welcome("+15551234567", "Ann")
    end

    test "unexpected calls fail the test" do
      assert_raise Mox.UnexpectedCallError, fn -> Signup.welcome("ann@example.com", "Ann") end
    end
  end

  describe "A/B testing with a router implementation" do
    setup do
      use_implementation(Experiment)
      :ok
    end

    defp run_experiment(candidate_percent) do
      Application.put_env(:box_turtle, Experiment,
        control: Impl,
        candidate: RichEmail,
        candidate_percent: candidate_percent
      )
    end

    defp recipients, do: for(n <- 1..200, do: "user#{n}@example.com")

    defp variants(recipients) do
      for recipient <- recipients do
        {:ok, %{variant: variant}} = Notifier.deliver(recipient, "Hi")
        variant
      end
    end

    test "at 0% everyone gets the control, at 100% everyone gets the candidate" do
      run_experiment(0)
      assert recipients() |> variants() |> Enum.uniq() == [:plain]

      run_experiment(100)
      assert recipients() |> variants() |> Enum.uniq() == [:html]
    end

    test "a split sends roughly the configured share to the candidate" do
      run_experiment(30)
      html = recipients() |> variants() |> Enum.count(&(&1 == :html))
      assert html in 40..80
    end

    test "assignment is sticky: a recipient keeps their variant on every call" do
      run_experiment(50)
      first = variants(recipients())
      assert variants(recipients()) == first
    end

    test "raising the percentage only moves control recipients to the candidate" do
      run_experiment(20)
      before = Map.new(recipients(), &{&1, Experiment.variant_for(&1)})

      run_experiment(60)

      for {recipient, RichEmail} <- before do
        assert Experiment.variant_for(recipient) == RichEmail
      end
    end

    test "ending the experiment is a config change back to the winner" do
      use_implementation(RichEmail)
      assert recipients() |> variants() |> Enum.uniq() == [:html]
    end
  end

  describe "stubbing an interface out of a build" do
    test "the build-stubbed facade does nothing in this build" do
      assert Analytics.track("signup", %{plan: "pro"}) == :ok
      refute_received {:tracked, _, _}
    end

    test "a live facade for the same interface reaches the implementation" do
      assert LiveAnalytics.track("signup", %{plan: "pro"}) == :ok
      assert_received {:tracked, "signup", %{plan: "pro"}}
    end
  end
end
