defmodule BoxTurtle.Schema.Pagination do
  @moduledoc """
  Limit/offset pagination for Ecto queries.

  `BoxTurtle.Schema.Query` applies it for the `:page` option, so you rarely call it directly. It also
  works on any Ecto query. A page is either a page number, using the default size, or a keyword list:

      import Ecto.Query
      alias BoxTurtle.Schema.Pagination

      query = from(p in MyApp.Blog.Post, order_by: [desc: p.inserted_at, desc: p.id])

      # Second page of 40 rows (the default size): LIMIT 40 OFFSET 40
      query |> Pagination.page(2) |> MyApp.Repo.all()

      # Rows 11-20: LIMIT 10 OFFSET 10
      query |> Pagination.page(number: 2, size: 10) |> MyApp.Repo.all()

  Page numbers below 1 are treated as 1. Give the query an `order_by` ending in a unique column,
  so rows don't move between pages.
  """
  import Ecto.Query

  @default_page_size 40

  @typedoc "A page number, or `[number: pos_integer(), size: pos_integer()]`."
  @type page_spec :: nil | pos_integer() | keyword()

  @doc "The page size used when none is configured: #{@default_page_size}."
  @spec default_page_size() :: pos_integer()
  def default_page_size, do: @default_page_size

  @doc """
  Applies `limit`/`offset` for the given page to the query. A `nil` page leaves the query untouched.
  """
  @spec page(Ecto.Queryable.t(), page_spec(), pos_integer()) :: Ecto.Queryable.t()
  def page(query, page, default_size \\ @default_page_size)
  def page(query, nil, _default_size), do: query

  def page(query, number, default_size) when is_integer(number),
    do: page(query, [number: number], default_size)

  def page(query, spec, default_size) when is_list(spec) do
    number = spec |> Keyword.get(:number, 1) |> max(1)
    size = Keyword.get(spec, :size, default_size)

    query
    |> limit(^size)
    |> offset(^((number - 1) * size))
  end
end
