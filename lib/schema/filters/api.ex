defmodule BoxTurtle.Schema.Filters.API do
  @callback filter_with(Ecto.Queryable.t(), keyword()) :: Ecto.Queryable.t()
end
