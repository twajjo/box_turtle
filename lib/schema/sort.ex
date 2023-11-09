defmodule BoxTurtle.Schema.Sort do
  use BoxTurtle.Debug.PipeDebug

  @behaviour BoxTurtle.Schema.Sort.API

  import Ecto.Query

  # https://hexdocs.pm/ecto/Ecto.Query.html#order_by/3
  @valid_order_options ~w(asc asc_nulls_first asc_nulls_last desc desc_nulls_first desc_nulls_last)a

  # TODO: Make dumb-as-dirt-- should only be concerned with general column case, all customs belong as sort
  # modules under the appropriate schema model.

  # Should recursively call until all sort_by fields are processed...
  @impl true
  def sort_by(query, []), do: query

  # Custom sorts go here, since this is a general handler, these should be limited to universally supported non-field sorts.
  # TODO: This still smells of a special case...
  @impl true
  def sort_by(query, [{order, []} = _sort | more_sorts]) when order in @valid_order_options do
    sort_by(query, more_sorts)
  end

  @impl true
  def sort_by(query, [{order, [column | columns]} = sort | more_sorts]) when order in @valid_order_options and is_atom(column) do
    sort |> debug("SORT_BY SORT by multifield")
    sort = List.wrap({order, column})
    query
    |> order_by(^sort)
    |> sort_by(List.wrap({order, columns}) ++ more_sorts)
  end

  # Default is to order by the named field (with default order ascending)
  @impl true
  def sort_by(query, [{order, _} = sort | more_sorts]) when order in @valid_order_options do
    sort |> debug("SORT_BY SORT tuple with order when")
    sort = List.wrap(sort)
    query
    |> order_by(^sort)
    |> sort_by(more_sorts)
  end
  # changing to handle keyword list as per https://hexdocs.pm/ecto/Ecto.Query.html#order_by/3
  # example, for asset we want: [desc_nulls_last: :last_report] as the order_by, similar for batteries, and more.
  # anytime there might be null values crowding the top of the returned sort.
  @impl true
  def sort_by(query, [field | more_sorts]) when is_atom(field) or is_tuple(field) do
    field |> debug("SORT_BY FIELD")
    query
    |> debug("SORT_BY QUERY")
    |> order_by(^field)
    |> sort_by(more_sorts)
  end
end
