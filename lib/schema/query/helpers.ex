defmodule BoxTurtle.Schema.Query.Helpers do
  @moduledoc """
  Option handling and query assembly used by the functions `BoxTurtle.Schema.Query` generates.

  Public so custom query extensions can reuse them; `add_filters/2` in particular is handy for adding
  filters to the options an extension receives.
  """
  import Ecto.Query
  import BoxTurtle.Schema.Pagination

  @option_keys ~w(aggregate distinct filters group_by page preloads sort)a

  ###
  # Options handlers
  ###

  @doc "Merges `filters` into the `:filters` already present in `opts`."
  @spec add_filters(keyword(), keyword()) :: keyword()
  def add_filters(opts, filters) when is_list(opts) and is_list(filters) do
    existing_filters = Keyword.get(opts, :filters, [])
    Keyword.put(opts, :filters, Keyword.merge(existing_filters, filters))
  end

  @doc "The columns to count distinctly in an aggregate (sort directions dropped)."
  @spec aggregate_distinction(keyword(), list()) :: [atom()]
  def aggregate_distinction(opts, default_distinct \\ []) do
    opts
    |> query_distinction(default_distinct)
    |> Enum.map(fn
      {_order, field} -> field
      field -> field
    end)
  end

  @doc "The `:aggregate` option, or nil."
  @spec aggregation(keyword()) :: atom() | nil
  def aggregation(opts), do: get_opt(opts, :aggregate, nil, nil)

  @doc "True when the options request an aggregate (e.g. a count)."
  @spec aggregate?(keyword()) :: boolean()
  def aggregate?(opts), do: not is_nil(aggregation(opts))

  @doc """
  Fetches a call-time option, falling back to `module_default`, or to `no_default_value` when the
  `ignore_defaults: true` option is set.
  """
  @spec get_opt(keyword(), atom(), any(), any()) :: any()
  def get_opt(opts, option, module_default, no_default_value) when option in @option_keys do
    Keyword.get(
      opts,
      option,
      if(ignore_defaults?(opts), do: no_default_value, else: module_default)
    )
  end

  @doc "The `:group_by` columns."
  @spec grouping(keyword()) :: list()
  def grouping(opts), do: opts |> get_opt(:group_by, [], []) |> List.wrap()

  @doc "True when the `ignore_defaults: true` option is set."
  @spec ignore_defaults?(keyword()) :: boolean()
  def ignore_defaults?(opts), do: Keyword.get(opts, :ignore_defaults, false)

  @doc "The associations to preload."
  @spec joining(list(), keyword()) :: list()
  def joining(default_preloads, opts),
    do: opts |> get_opt(:preloads, default_preloads, []) |> List.wrap()

  @doc "The `:distinct` columns for list queries."
  @spec query_distinction(keyword(), list()) :: list()
  def query_distinction(opts, default_distinct \\ []) do
    opts
    |> get_opt(:distinct, default_distinct, [])
    |> List.wrap()
  end

  @doc "The `:page` option (see `BoxTurtle.Schema.Pagination`)."
  @spec paging(keyword()) :: BoxTurtle.Schema.Pagination.page_spec()
  def paging(opts), do: get_opt(opts, :page, nil, nil)

  @doc "The sort specification."
  @spec sorting(list(), keyword()) :: list()
  def sorting(default_sort, opts), do: opts |> get_opt(:sort, default_sort, []) |> List.wrap()

  ###
  # Query assembly
  ###

  @doc "Builds an aggregate query. Only `:count` is supported."
  @spec aggregate_query!(Ecto.Queryable.t(), :count, module(), keyword()) :: Ecto.Query.t()
  def aggregate_query!(query, :count, filter_module, opts) do
    query
    |> aggregate_select(grouping(opts), opts)
    |> build_query!(filter_module, opts)
  end

  @doc """
  Runs an aggregate query: a single integer without grouping, otherwise a list of maps holding the grouped
  columns and `:count`.
  """
  @spec aggregate_result!(Ecto.Queryable.t(), :count, [atom()], module(), keyword()) ::
          integer() | [map()]
  def aggregate_result!(query, :count, [], repo, _opts) do
    case repo.one(query) do
      %{count: count} -> count
      nil -> 0
    end
  end

  def aggregate_result!(query, :count, grouping, repo, _opts) when is_list(grouping),
    do: repo.all(query)

  @doc false
  @spec aggregate_select(Ecto.Queryable.t(), nil | [atom()], keyword()) :: Ecto.Query.t()
  def aggregate_select(query, group_by, opts) when group_by in [nil, []] do
    aggregate_unique(query, aggregate_distinction(opts))
  end

  def aggregate_select(query, group_by, opts) when is_list(group_by) do
    query
    |> aggregate_select(nil, opts)
    |> select_merge([q], map(q, ^group_by))
  end

  # Ecto aggregates only support a single distinct column.
  @doc false
  @spec aggregate_unique(Ecto.Queryable.t(), nil | atom() | [atom()]) :: Ecto.Query.t()
  def aggregate_unique(query, [column | _columns]), do: aggregate_unique(query, column)

  def aggregate_unique(query, column) when is_atom(column) and not is_nil(column) do
    select(query, [q], %{count: count(field(q, ^column), :distinct)})
  end

  def aggregate_unique(query, _), do: select(query, [q], %{count: count()})

  @doc "Applies sorting and pagination."
  @spec build_listings!(Ecto.Queryable.t(), module(), list(), keyword(), pos_integer()) ::
          Ecto.Queryable.t()
  def build_listings!(query, sorting_module, default_sort, opts, page_size \\ default_page_size()) do
    query
    |> sorting_module.sort_by(sorting(default_sort, opts))
    |> page(paging(opts), page_size)
  end

  @doc "Applies grouping and filters."
  @spec build_query!(Ecto.Queryable.t(), module(), keyword()) :: Ecto.Queryable.t()
  def build_query!(query, filter_module, opts \\ []) do
    query
    |> group(grouping(opts))
    |> filter_module.filter_with(Keyword.get(opts, :filters, []))
  end

  @doc "Adds `group_by` clauses. String column names must already exist as atoms."
  @spec group(Ecto.Queryable.t(), nil | atom() | String.t() | [atom() | String.t()]) ::
          Ecto.Queryable.t()
  def group(query, nil), do: query
  def group(query, []), do: query
  def group(query, [column | columns]), do: query |> group(column) |> group(columns)
  def group(query, column) when is_atom(column), do: group_by(query, [q], field(q, ^column))

  def group(query, column) when is_binary(column),
    do: group(query, String.to_existing_atom(column))

  @doc """
  Preloads associations through `LEFT JOIN`s, so rows and their associations come back from the
  database in a single query instead of one extra query per association.

  `assocs` takes the usual preload shapes, nested to any depth: `:author`, `[:author, :tags]`,
  `[author: [:company], comments: :user]`. Duplicates are merged.

  Joining a to-many association repeats each parent row once per child, so `LIMIT`, `OFFSET` and
  `DISTINCT` would count child rows. When the query has any of them, they are applied in a subquery
  selecting `primary_key`, and the joins are made against that selection.
  """
  @spec preloads(Ecto.Queryable.t(), nil | atom() | list(), atom()) :: Ecto.Queryable.t()
  def preloads(query, assocs, primary_key \\ :id)
  def preloads(query, nil, _primary_key), do: query
  def preloads(query, [], _primary_key), do: query

  def preloads(query, assocs, primary_key) do
    query = Ecto.Queryable.to_query(query)
    schema = root_schema!(query)
    tree = preload_tree(assocs, [])

    query =
      if to_many?(schema, tree) and paged_or_distinct?(query),
        do: restrict_to_selection(query, primary_key),
        else: query

    {joined, query} = join_preloads(query, :root, schema, tree)
    Ecto.Query.Builder.Preload.apply(query, [], joined)
  end

  defp root_schema!(%Ecto.Query{from: %{source: {_source, schema}}})
       when is_atom(schema) and not is_nil(schema),
       do: schema

  defp root_schema!(query),
    do:
      raise(ArgumentError, "join preloads need a query on an Ecto schema, got: #{inspect(query)}")

  # Normalizes preload specs into a merged keyword tree: [author: [company: []], tags: []].
  defp preload_tree(assoc, tree) when is_atom(assoc), do: preload_tree({assoc, []}, tree)

  defp preload_tree(assocs, tree) when is_list(assocs),
    do: Enum.reduce(assocs, tree, &preload_tree/2)

  defp preload_tree({assoc, children}, tree) when is_atom(assoc),
    do: Keyword.update(tree, assoc, preload_tree(children, []), &preload_tree(children, &1))

  defp preload_tree(other, _tree) do
    raise ArgumentError,
          "preloads must be association names, optionally nested in lists, got: #{inspect(other)}"
  end

  defp association!(schema, assoc) do
    schema.__schema__(:association, assoc) ||
      raise ArgumentError, "#{inspect(schema)} has no association #{inspect(assoc)}"
  end

  defp to_many?(schema, tree) do
    Enum.any?(tree, fn {assoc, children} ->
      reflection = association!(schema, assoc)
      reflection.cardinality == :many or to_many?(reflection.related, children)
    end)
  end

  defp paged_or_distinct?(%Ecto.Query{limit: limit, offset: offset, distinct: distinct}),
    do: not (is_nil(limit) and is_nil(offset) and is_nil(distinct))

  defp restrict_to_selection(query, primary_key) do
    selection = select(query, [q], %{key: field(q, ^primary_key)})

    query
    |> exclude(:limit)
    |> exclude(:offset)
    |> exclude(:distinct)
    |> join(:inner, [q], s in subquery(selection), on: field(q, ^primary_key) == s.key)
  end

  # Joins each association to its parent binding and returns the {assoc, {binding_index, children}}
  # tree that join preloads expect (what `preload([p, a], author: a)` builds at compile time).
  defp join_preloads(query, parent, schema, tree) do
    Enum.map_reduce(tree, query, fn {assoc, children}, query ->
      reflection = association!(schema, assoc)
      index = length(query.joins) + 1
      name = :"box_turtle_preload_#{index}"
      query = join_assoc(query, parent, assoc, name)
      {child_joins, query} = join_preloads(query, name, reflection.related, children)
      {{assoc, {index, child_joins}}, query}
    end)
  end

  defp join_assoc(query, :root, assoc, name),
    do: join(query, :left, [q], a in assoc(q, ^assoc), as: ^name)

  defp join_assoc(query, parent, assoc, name),
    do: join(query, :left, [{^parent, p}], a in assoc(p, ^assoc), as: ^name)

  @doc "Adds a `distinct` clause."
  @spec unique(Ecto.Queryable.t(), nil | atom() | list()) :: Ecto.Queryable.t()
  def unique(query, nil), do: query
  def unique(query, []), do: query
  def unique(query, columns) when is_list(columns), do: distinct(query, ^columns)
  def unique(query, column) when is_atom(column), do: unique(query, [column])

  @doc """
  Restricts the query to one key: a single value for `primary_key`, or a map/keyword list of
  column values for composite keys.
  """
  @spec where_key(Ecto.Queryable.t(), term(), atom()) :: Ecto.Query.t()
  def where_key(query, %{} = key, _primary_key) when not is_struct(key),
    do: where(query, ^Enum.to_list(key))

  def where_key(query, [{_, _} | _] = key, _primary_key), do: where(query, ^key)
  def where_key(query, key, primary_key), do: where(query, ^[{primary_key, key}])
end
