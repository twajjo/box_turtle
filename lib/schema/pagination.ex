defmodule BoxTurtle.Schema.Pagination do
  @moduledoc """
  Limit/offset pagination for Ecto queries.

  A page is given either as a page number (using the default page size) or as a keyword list:

      page(query, 2)                    # second page of @default_page_size rows
      page(query, number: 2, size: 10)  # rows 11-20

  Page numbers below 1 are treated as 1.
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
  def page(query, number, default_size) when is_integer(number), do: page(query, [number: number], default_size)

  def page(query, spec, default_size) when is_list(spec) do
    number = spec |> Keyword.get(:number, 1) |> max(1)
    size = Keyword.get(spec, :size, default_size)

    query
    |> limit(^size)
    |> offset(^((number - 1) * size))
  end
end
