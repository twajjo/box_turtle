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

  Use this module and add `sort_by/2` clauses for named sorts that aren't plain columns. Each clause
  handles the element at the head of the list and must pass the rest back to `sort_by/2`. Elements
  your clauses don't match fall through to the default behaviour, one element at a time.

  For a `MyApp.Blog.Post` schema with `likes` and `shares` fields:

      defmodule MyApp.Blog.Post.Sort do
        use BoxTurtle.Schema.Sort
        import Ecto.Query

        # Most engagement first; the primary key breaks ties so pages are stable.
        def sort_by(query, [:popularity | rest]) do
          query
          |> order_by([p], desc: p.likes + p.shares, asc: p.id)
          |> sort_by(rest)
        end
      end

      defmodule MyApp.Blog.Post.Query do
        use BoxTurtle.Schema.Query,
          repo: MyApp.Repo,
          sorting_module: MyApp.Blog.Post.Sort,
          default_sort: [:popularity]
      end

      MyApp.Blog.Post.Query.list!()                                  # most popular first
      MyApp.Blog.Post.Query.list!(sort: [desc: :inserted_at, asc: :id]) # plain columns still work

  `:default_sort` goes through your module too, so it may use your named sorts. Sorts on joined
  columns and closed modules for `?sort=-likes,title` params are shown in the repository's
  `test/support/examples/schema.ex`.
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
