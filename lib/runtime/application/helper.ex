defmodule BoxTurtle.Runtime.Application.Helper do
  @moduledoc """
  Utilities for building an application's supervision tree.

  Import the module in your `Application` and build the children list step by step:

      defmodule MyApp.Application do
        use Application

        import BoxTurtle.Runtime.Application.Helper

        @impl true
        def start(_type, _args) do
          children =
            [MyApp.Repo]
            # A boolean, e.g. from config: config :my_app, start_web?: false
            |> conditional_append(Application.get_env(:my_app, :start_web?, true), MyAppWeb.Endpoint)
            # A function, called when the tree is built
            |> conditional_append(&MyApp.Features.workers_enabled?/0, [MyApp.Worker, MyApp.Scheduler])
            # A function with arguments
            |> conditional_append(&Code.ensure_loaded?/1, MyApp.Metrics, [Telemetry.Metrics])

          Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
        end
      end
  """

  @typedoc "A boolean, or a function returning one when applied to the `args` list."
  @type condition :: boolean() | function()

  @doc """
  Appends `conditional` (a single child or a list of children) to `current` when `condition`
  holds.

  `condition` is either a boolean or a function. A function is applied to `args`
  (as with `Kernel.apply/2`) and must return a boolean.

  ## Examples

      iex> conditional_append([:a], true, :b)
      [:a, :b]

      iex> conditional_append([:a], false, [:b, :c])
      [:a]

      iex> conditional_append([:a], fn x, y -> x < y end, [:b], [1, 2])
      [:a, :b]
  """
  @spec conditional_append(list(), condition(), term(), list()) :: list()
  def conditional_append(current, condition, conditional, args \\ [])

  def conditional_append(current, false, _conditional, _args), do: current

  def conditional_append(current, true, conditional, _args) do
    List.wrap(current) ++ List.wrap(conditional)
  end

  def conditional_append(current, condition, conditional, args)
      when is_function(condition) and is_list(args) do
    conditional_append(current, apply(condition, args), conditional)
  end
end
