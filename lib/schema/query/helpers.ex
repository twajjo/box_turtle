defmodule BoxTurtle.Schema.Query.Helpers do
  @moduledoc """
  BoxTurtle.Schema.Query options handling and MORE!

  """
  import Ecto.Query
  import BoxTurtle.Schema.Pagination

  ###
  # Options Handlers
  ###
  @spec add_filters(opts :: keyword, filters :: keyword) :: opts :: keyword
  def add_filters(opts, filters) when is_list(opts) and is_list(filters) do
    existing_filters = Keyword.get(opts, :filters, [])
    Keyword.merge(opts, filters: Keyword.merge(existing_filters, filters))
  end

  # Has suppressable defaults
  @spec aggregate_distinction(keyword(), keyword() | [atom()]) :: list()
  def aggregate_distinction(opts, default_distinct \\ []) do
    opts
    |> query_distinction(default_distinct)
    |> Enum.map(fn
       {_order, field} -> field
       field -> field
    end)
  end

  # Has non-suppressable defaults
  @spec aggregation(keyword()) :: atom() | nil
  def aggregation(opts) do
    opts
    |> get_opt(:aggregate, nil, nil)
  end

  # Has non-suppressable defaults
  @spec filtering(keyword()) :: list()
  def filtering(opts) do
    opts
    |> get_opt(:filters, [], [])
    |> List.wrap()
  end

  @spec get_opt(keyword(), atom(), any(), any()) :: any()
  def get_opt(opts, option, module_default, no_default_value)
      when option in ~w(aggregate distinct filters group_by page preloads sort)a do
    Keyword.get(opts, option, (use_module_defaults?(opts) && module_default) || no_default_value)
  end

  # Has suppressable defaults
  @spec grouping(keyword()) :: list()
  def grouping(opts) do
    opts
    |> get_opt(:group_by, [], [])
    |> List.wrap()
  end

  @spec is_aggregate?(keyword()) :: boolean()
  def is_aggregate?(opts) do
    !is_nil(aggregation(opts))
  end

  # Has suppressable defaults
  @spec joining(list(), keyword()) :: list()
  def joining(default_preloads, opts) do
    opts
    |> get_opt(:preloads, default_preloads, [])
    |> List.wrap()
  end

  # Has suppressable defaults
  @spec query_distinction(keyword(), keyword() | [atom()]) :: list()
  def query_distinction(opts, default_distinct \\ []) do
    opts
    |> get_opt(:distinct, default_distinct, [])
    |> List.wrap()
  end

  # What exactly does paging return?
  # Has suppressable defaults
  @spec paging(keyword()) :: any() | nil
  def paging(opts) do
    opts
    |> get_opt(:page, nil, nil)
  end

  # Has suppressable defaults
  @spec sorting(list(), keyword()) :: list()
  def sorting(default_sort, opts) do
    opts
    |> get_opt(:sort, default_sort, [])
    |> List.wrap()
  end

  @spec suppress_module_defaults?(keyword()) :: boolean()
  def suppress_module_defaults?(opts) do
    Keyword.get(opts, :no_defaults, false)
  end

  @spec use_module_defaults?(keyword()) :: boolean()
  def use_module_defaults?(opts) do
    !suppress_module_defaults?(opts)
  end

  ###
  # Query Assembly functions
  ###
  @spec aggregate_query!(Ecto.Queryable.t, aggregate_function :: atom(), module(), keyword()) :: Ecto.Queryable.t
  def aggregate_query!(query, :count, filter_module, opts) do
    query
    |> aggregate_select(grouping(opts), opts)
    |> build_query!(filter_module, opts)
  end

  @spec aggregate_result!(Ecto.Queryable.t, :count, [atom], module(), keyword()) :: nil | integer | [map]
  def aggregate_result!(query, :count, [], repo, _opts) do
    query
    |> repo.one()
    |> AtomicMap.convert([safe: true, ignore: true])
    |> Map.get(:count, 0)
  end
  def aggregate_result!(query, :count, grouping, repo, _opts) when is_list(grouping) do
    query
    |> repo.all()
    |> AtomicMap.convert([safe: true, ignore: true])
  end

  @spec aggregate_select(Ecto.Queryable.t(), atom | String.t() | [atom | String.t()], keyword()) :: Ecto.Queryable.t()
  def aggregate_select(query, group_by, opts) when group_by in [nil, []] do
    query
    |> aggregate_unique(opts |> aggregate_distinction())
  end
  def aggregate_select(query, group_by, opts) when is_list(group_by) do
    query
    |> aggregate_select(nil, opts)
    |> select_merge([q], map(q, ^group_by))
  end

  @spec aggregate_unique(Ecto.Queryable.t(), nil | [atom()] | atom()) :: Ecto.Queryable.t()
  # Currently, Ecto aggregate functions only support a single distinct column.
  def aggregate_unique(query, [column | _columns]) do
    query
    |> aggregate_unique(column)
  end
  def aggregate_unique(query, nil) do
    query
    |> select([q], %{count: count(q.inserted_at)})
  end
  def aggregate_unique(query, column) when is_atom(column) do
    query
    |> select([q], %{count: count(field(q, ^column), :distinct)})
  end
  def aggregate_unique(query, _) do
    query
    |> select([q], %{count: count(q.inserted_at)})
  end

  @spec build_listings!(Ecto.Queryable.t, module(), list(), keyword()) :: Ecto.Queryable.t
  def build_listings!(query, sorting_module, default_sort, opts) do
    query
    |> sorting_module.sort_by(sorting(default_sort, opts))
    |> page(paging(opts))
  end

  @spec build_query!(Ecto.Queryable.t, module(), keyword()) :: Ecto.Queryable.t
  def build_query!(query, filter_module, opts \\ []) do
    filters = Keyword.get(opts, :filters, [])
    query
    |> group(grouping(opts))
    |> filter_module.filter_with(filters)
  end

  @spec group(Ecto.Queryable.t(), nil | atom | String.t() | [atom | String.t()]) :: Ecto.Queryable.t()
  def group(query, nil), do: query
  def group(query, []), do: query
  def group(query, [column | columns]) do
    query
    |> group(column)
    |> group(columns)
  end
  def group(query, column) when is_atom(column) do
    query
    |> group_by([q], field(q, ^column))
  end
  def group(query, column) when is_binary(column) do
    group(query, column |> String.to_atom())
  end
  def group(query, _), do: query

  @spec preloads(Ecto.Queryable.t(), nil | [atom]) :: Ecto.Queryable.t()
  def preloads(query, nil), do: query
  def preloads(query, []), do: query
  def preloads(query, schemas) when is_list(schemas) do
    # Drop duplicates in the preload list
    joins = schemas |> Enum.uniq()

    query
    |> preload(^joins)
  end
  def preloads(query, schema) when is_atom(schema) do
    query
    |> preloads(schema |> List.wrap())
  end
  def preloads(query, nil), do: query

  @spec unique(Ecto.Queryable.t(), nil | [atom()] | atom()) :: Ecto.Queryable.t()
  def unique(query, nil), do: query
  def unique(query, []), do: query
  def unique(query, schemas) when is_list(schemas) do
    query
    |> distinct(^schemas)
  end
  def unique(query, schema) when is_atom(schema) do
    query
    |> unique(schema |> List.wrap())
  end
  def unique(query, _), do: query

end
