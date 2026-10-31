defmodule BoxTurtle.Schema.Filters.API do
  @moduledoc """
  Behaviour for modules that turn a list of filters into `where` clauses.
  See `BoxTurtle.Schema.Filters` for the default behaviour.
  """

  @typedoc "A list of `{column_or_filter_name, value}` pairs."
  @type filters :: [{atom() | String.t(), term()}]

  @callback filter_with(Ecto.Queryable.t(), filters()) :: Ecto.Queryable.t()
end
