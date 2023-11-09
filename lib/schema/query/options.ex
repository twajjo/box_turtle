defmodule BoxTurtle.Schema.Query.Options do
  @moduledoc """
  """

  defmacro __using__(options) do
    repo = options
#      |> IO.inspect(label: "Raw use options")
      |> Keyword.get(:repo, nil)
    schema = options
      |> Keyword.get(:schema, nil)
    default_order = options
      |> Keyword.get(:default_order, [:id])
    default_sort = options
      |> Keyword.get(:default_sort, [:id])
    filter_module = options
      |> Keyword.get(:filter_module, BoxTurtle.Schema.Filters)
    sorting_module = options
      |> Keyword.get(:sorting_module, BoxTurtle.Schema.Sort)
    default_preloads = options
      |> Keyword.get(:default_preloads, [])
    default_distinct = options
      |> Keyword.get(:default_distinct, [])
    primary_key = options
      |> Keyword.get(:primary_key, :id)

    # Inject header requirements for extension generation
    quote do
      # See OptionsAPI for module and callback descrptions.
      alias BoxTurtle.Schema.Query.Options.API, as: OptionsAPI
      @behaviour OptionsAPI

      use BoxTurtle.Debug.PipeDebug

      @query_options ~w(
        default_distinct
        default_order
        default_preloads
        default_sort
        filter_module
        primary_key
        repo
        schema
        sorting_module
      )a

      @impl OptionsAPI
      def default_distinct(opts \\ []), do: opts |> Keyword.get(:default_distinct, unquote(default_distinct))
      @impl OptionsAPI
      def default_order(opts \\ []), do: opts |> Keyword.get(:default_order, unquote(default_order))
      @impl OptionsAPI
      def default_preloads(opts \\ []), do: opts |> Keyword.get(:default_preloads, unquote(default_preloads))
      @impl OptionsAPI
      def default_sort(opts \\ []), do: opts |> Keyword.get(:default_sort, unquote(default_sort))
      @impl OptionsAPI
      def filter_module(opts \\ []), do: opts |> Keyword.get(:filter_module, unquote(filter_module))
      @impl OptionsAPI
      def primary_key(opts \\ []), do: opts |> Keyword.get(:primary_key, unquote(primary_key))
      @impl OptionsAPI
      def repo(opts \\ []), do: opts |> Keyword.get(:repo, unquote(repo))
      @impl OptionsAPI
      def schema(opts \\ []), do: opts |> Keyword.get(:schema, unquote(schema))
      @impl OptionsAPI
      def sorting_module(opts \\ []), do: opts |> Keyword.get(:sorting_module, unquote(sorting_module))

      @impl OptionsAPI
      def inject_query_options(opts) do
        @query_options
        |> Enum.reduce(opts, fn setting, opts ->
          opts
          |> Keyword.put(setting, Kernel.apply(__MODULE__, setting, [[]]))
        end)
      end

      defoverridable OptionsAPI
    end
  end

end
