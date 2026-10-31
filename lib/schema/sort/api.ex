defmodule BoxTurtle.Schema.Sort.API do
  @moduledoc """
  Behaviour for modules that turn a sort specification into `order_by` clauses.
  See `BoxTurtle.Schema.Sort` for the supported specification forms.
  """

  @typedoc "A column, `{direction, column}`, `{direction, [column]}`, or a list of those."
  @type sort_spec :: atom() | {atom(), atom() | [atom()]} | [atom() | {atom(), atom() | [atom()]}]

  @callback sort_by(Ecto.Queryable.t(), sort_spec()) :: Ecto.Queryable.t()
end
