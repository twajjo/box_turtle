defmodule BoxTurtle.Schema.Sort do
  @moduledoc """
  Default sorting for `BoxTurtle.Schema.Query`, and a base for schema-specific sort modules.

  A sort specification is a list whose elements are any of:

    * `:column` - ascending order on the column
    * `{direction, :column}` - e.g. `{:desc_nulls_last, :reported_at}`
    * `{direction, [:column, ...]}` - the same direction for several columns

  where `direction` is one of `#{inspect(~w(asc asc_nulls_first asc_nulls_last desc desc_nulls_first desc_nulls_last)a)}`
  (see `Ecto.Query.order_by/3`). Keyword lists such as `[desc: :inserted_at, asc: :id]` therefore work as-is.

  ## Custom sorts

  Use this module and add `sort_by/2` clauses for named sorts that aren't plain columns. Anything your clauses
  don't match falls through to the default behaviour one element at a time:

      defmodule MyApp.Post.Sort do
        use BoxTurtle.Schema.Sort
        import Ecto.Query

        def sort_by(query, [:popularity | rest]) do
          query
          |> order_by([p], desc: p.likes + p.shares)
          |> sort_by(rest)
        end
      end

  Then pass `sorting_module: MyApp.Post.Sort` to `use BoxTurtle.Schema.Query`.
  """
  @behaviour BoxTurtle.Schema.Sort.API

  import Ecto.Query

  @directions ~w(asc asc_nulls_first asc_nulls_last desc desc_nulls_first desc_nulls_last)a

  defmacro __using__(_opts) do
    quote do
      @behaviour BoxTurtle.Schema.Sort.API
      @before_compile BoxTurtle.Schema.Sort
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    # No @impl here: these clauses follow the user's own sort_by/2 clauses.
    quote do
      def sort_by(query, []), do: query

      def sort_by(query, [spec | specs]) do
        query
        |> unquote(__MODULE__).apply_sort(spec)
        |> sort_by(specs)
      end

      def sort_by(query, spec), do: sort_by(query, [spec])
    end
  end

  @impl true
  def sort_by(query, specs) do
    specs
    |> List.wrap()
    |> Enum.reduce(query, &apply_sort(&2, &1))
  end

  @doc """
  Applies a single sort element (see the module documentation) to the query.

  Raises `ArgumentError` for anything else.
  """
  @spec apply_sort(Ecto.Queryable.t(), term()) :: Ecto.Queryable.t()
  def apply_sort(query, column) when is_atom(column), do: order_by(query, ^[column])

  def apply_sort(query, {direction, column}) when direction in @directions and is_atom(column) do
    order_by(query, ^[{direction, column}])
  end

  def apply_sort(query, {direction, columns})
      when direction in @directions and is_list(columns) do
    Enum.reduce(columns, query, &apply_sort(&2, {direction, &1}))
  end

  def apply_sort(_query, spec) do
    raise ArgumentError, "invalid sort specification: #{inspect(spec)}"
  end
end
