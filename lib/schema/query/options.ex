defmodule BoxTurtle.Schema.Query.Options do
  @moduledoc false
  # Generates the BoxTurtle.Schema.Query.Options.API accessors from validated `use BoxTurtle.Schema.Query` options.

  @settings ~w(default_distinct default_preloads default_sort filter_module page_size primary_key repo schema
               sorting_module)a

  @doc false
  def settings, do: @settings

  defmacro __using__(options) do
    accessors =
      for setting <- @settings do
        default = Keyword.fetch!(options, setting)

        quote do
          @impl BoxTurtle.Schema.Query.Options.API
          def unquote(setting)(opts \\ []),
            do: Keyword.get(opts, unquote(setting), unquote(default))
        end
      end

    quote do
      @behaviour BoxTurtle.Schema.Query.Options.API

      unquote_splicing(accessors)

      @impl BoxTurtle.Schema.Query.Options.API
      def inject_query_options(opts) do
        Enum.reduce(unquote(@settings), opts, fn setting, opts ->
          Keyword.put_new_lazy(opts, setting, fn -> apply(__MODULE__, setting, []) end)
        end)
      end

      defoverridable BoxTurtle.Schema.Query.Options.API
    end
  end
end
