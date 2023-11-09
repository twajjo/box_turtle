defmodule BoxTurtle.Schema.Sort.API do
  @callback sort_by(Ecto.Queryable.t(), keyword()) :: Ecto.Queryable.t()
end
