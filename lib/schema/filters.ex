defmodule BoxTurtle.Schema.Filters do
  @moduledoc """

  Options:
    validate_columns
    error_catchall
  """
  @behaviour BoxTurtle.Schema.Filters.API

  import Ecto.Query

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @impl true
      def filter_with(query, []), do: query

      # User implementations go here...

      @before_compile BoxTurtle.Schema.Filters
    end
  end

  defmacro __before_compile__(%{module: schema_filter} = env) do
    env
    |> IO.inspect(label: "Here 'tis bubba")
    quote do
      # General cases and catchalls
      # TODO: find other default functions, like inserted at, etc.
      def filter_with(query, [{column, value} | filters ]) when is_atom(column) do
        query
        |> where([q], ^[{column, value}])
        |> filter_with(filters)
      end

      def filter_with(query, [{column, value} | _filters]) do
        query
        |> where([i], field(i, ^column) == ^value)
      end
    end
  end
end
