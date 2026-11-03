defmodule BoxTurtle.Schema.Filters do
  @moduledoc """
  Default filtering for `BoxTurtle.Schema.Query`, and a base for schema-specific filter modules.

  Each filter is a `{column, value}` pair, combined with `AND`:

    * `{:status, "active"}` - `status = 'active'`
    * `{:status, ["active", "pending"]}` - `status IN (...)`
    * `{:deleted_at, nil}` - `deleted_at IS NULL`

  String column names are accepted, but only if the atom already exists (`String.to_existing_atom/1`), so
  filters built from request params can't create atoms.

  ## Custom filters

  Use this module and add `filter_with/2` clauses for named filters that aren't plain column comparisons.
  Anything your clauses don't match falls through to the default behaviour one filter at a time:

      defmodule MyApp.Post.Filters do
        use BoxTurtle.Schema.Filters
        import Ecto.Query

        def filter_with(query, [{:published_after, date} | rest]) do
          query
          |> where([p], p.published_at > ^date)
          |> filter_with(rest)
        end
      end

  Then pass `filter_module: MyApp.Post.Filters` to `use BoxTurtle.Schema.Query`.
  """
  @behaviour BoxTurtle.Schema.Filters.API

  import Ecto.Query

  defmacro __using__(_opts) do
    quote do
      @behaviour BoxTurtle.Schema.Filters.API
      @before_compile BoxTurtle.Schema.Filters
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    # No @impl here: these clauses follow the user's own filter_with/2 clauses.
    quote do
      def filter_with(query, []), do: query

      def filter_with(query, [filter | filters]) do
        query
        |> unquote(__MODULE__).apply_filter(filter)
        |> filter_with(filters)
      end
    end
  end

  @impl true
  def filter_with(query, filters) do
    Enum.reduce(filters, query, &apply_filter(&2, &1))
  end

  @doc """
  Applies a single `{column, value}` filter (see the module documentation) to the query.
  """
  @spec apply_filter(Ecto.Queryable.t(), {atom() | String.t(), term()}) :: Ecto.Queryable.t()
  def apply_filter(query, {column, value}) when is_binary(column) do
    apply_filter(query, {String.to_existing_atom(column), value})
  end

  def apply_filter(query, {column, nil}) when is_atom(column) do
    where(query, [q], is_nil(field(q, ^column)))
  end

  def apply_filter(query, {column, values}) when is_atom(column) and is_list(values) do
    where(query, [q], field(q, ^column) in ^values)
  end

  def apply_filter(query, {column, value}) when is_atom(column) do
    where(query, [q], field(q, ^column) == ^value)
  end
end
