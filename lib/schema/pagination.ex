defmodule BoxTurtle.Schema.Pagination do
  @moduledoc """

  """
  import Ecto.Query

  # FIXME: there are 2 pagination modules each with their own pagination limit
  # In addition, pagination should have a default but also be a field on the page to change the desired pagination.
  #TODO: make this a configuration setting or overridable default page size...
  @pagination_limit 40

  def page(query, nil), do: query

  def page(query, page) do
    query
    |> limit(@pagination_limit)
    |> offset(((^page - 1) * @pagination_limit))
  end
end
