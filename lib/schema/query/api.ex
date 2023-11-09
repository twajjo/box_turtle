defmodule BoxTurtle.Schema.Query.API do
  @moduledoc """
    Implementation supported options:
      preloads: [<associations>] (ignored on aggregation operations, e.g., count, max, min, avg)
        A list of table associations (parent or child tables) to preload.
      filters: keyword()
        Filter name pairs.
      sort: keyword()
      group_by: [<fields>]
      distinct:
      page:
      aggregate: :count | :max | :min | :avg
    Double-secret probation options (overrides of module-specific settings used for trixy callbacks...):
      repo: module(), REQUIRED
      schema: module(), REQUIRED
        The schema module to implement Query methods for.
      default_sort: [atom()] | [{:asc | :desc, atom()}], default: [{:asc, :id}]
        When given, specifies the default sort order for list queries.
      default_preloads: [atom()], default: []
        When given, preloads the specified associated tables.
      filter_module: module(), default: BoxTurtle.Schema.Filters
        When specified, provides a module that implements filter_with implementations
        of BoxTurtle.Schema.Filters.API.
      sorting_module: module(), default: BoxTurtle.Schema.Sort
    Special-use hooks
      ignore_defaults: true | false
        Completely ignore default settings (excepting repo and schema, unless overridden).  For preventing preloads,
        filter overrides, default sorting behaviours, etc.
      row_module: module(), default: nil
        Used to define row scope fetching implementation hooks.
  """

  @doc """
  Get a count of schema objects (plus options).
  """
  # Adorned
  @callback count() :: {:ok, integer}
  @callback count(opts :: keyword) :: {:ok, integer}
  # Unadorned
  @callback count!() :: integer
  @callback count!(opts :: keyword) :: integer

  @doc """
  Get a count of schema objects scoped by the given pattern or object (plus options).
  * Extension Query functions (implementation optional)
  """
  # Adorned
  @callback count_by(pattern :: any()) :: {:ok, integer}
  @callback count_by(pattern :: any(), opts :: keyword) :: {:ok, integer}
  # Unadorned
  @callback count_by!(pattern :: any()) :: integer
  @callback count_by!(pattern :: any(), opts :: keyword) :: integer

  @doc """
  Get a schema row by id (unadorned! and adorned versions)

  ## Parameters

  id - the id of the schema instance (row) to fetch.
  opts - query options (default: []).

  ## Returns:
  Adorned:
    {:ok, <schema>}
    {:error, map()}
  Unadorned!:
    <schema>
    nil
  """
  # Adorned
  @callback get(key :: any) :: {:ok, Ecto.Schema} | {:error, any}
  @callback get(key :: any, opts :: keyword) :: {:ok, Ecto.Schema} | {:error, any}
  # Unadorned
  @callback get!(key :: any) :: Ecto.Schema | nil
  @callback get!(key :: any, opts :: keyword) :: Ecto.Schema | nil

  @doc """
  Get a specific instance of the schema object identified by the given pattern or object (with options).
  * Extension Query functions (implementation optional)
  """
  # Adorned
  @callback get_by(pattern :: any()) :: {:ok, Ecto.Schema} | {:error, any()}
  @callback get_by(pattern :: any(), opts :: keyword()) :: {:ok, Ecto.Schema} | {:error, any()}
  # Unadorned
  @callback get_by!(pattern :: any()) :: Ecto.Schema | nil
  @callback get_by!(pattern :: any(), opts :: keyword()) :: Ecto.Schema | nil

  @doc """
  Get a list of schema objects (with options).
  """
  # Adorned
  @callback list() :: {:ok, [] | [Ecto.Schema]} | {:error, any}
  @callback list(opts :: keyword) :: {:ok, [] | [Ecto.Schema]} | {:error, any}
  # Unadorned
  @callback list!() :: [] | [Ecto.Schema]
  @callback list!(opts :: keyword) :: [] | [Ecto.Schema]

  @doc """
  Get a list of schema objects scoped by the given pattern or object (with options).
  * Extension Query functions (implementation optional)
  """
  # Adorned
  @callback list_by(pattern :: any()) :: {:ok, [] | [Ecto.Schema]} | {:error, any}
  @callback list_by(pattern :: any(), opts :: keyword) :: {:ok, [] | [Ecto.Schema]} | {:error, any}
  # Unadorned
  @callback list_by!(pattern :: any()) :: [] | [Ecto.Schema]
  @callback list_by!(pattern :: any(), opts :: keyword) :: [] | [Ecto.Schema]

  @doc """
  For injecting options into an existing Ecto.Queryable rather than creating a queryable from scratch.
  """
  @callback pipe_query!(Ecto.Queryable) :: Ecto.Queryable
  @callback pipe_query!(Ecto.Queryable, opts :: keyword) :: Ecto.Queryable

  @doc """
  Create an Ecto.Queryable from the schema object (with options).
  """
  @callback query!() :: Ecto.Queryable
  @callback query!(opts :: keyword) :: Ecto.Queryable

  @doc """
  Create an Ecto.Queryable from the schema object scoped by the given pattern or object (with options).
  * Extension Query functions (implementation optional)
  """
  @callback query_by!(pattern :: any()) :: Ecto.Queryable
  @callback query_by!(pattern :: any(), opts :: keyword) :: Ecto.Queryable

  @optional_callbacks [
    count_by: 1,
    count_by: 2,
    count_by!: 1,
    count_by!: 2,
    list_by: 1,
    list_by: 2,
    list_by!: 1,
    list_by!: 2,
    query_by!: 1,
    query_by!: 2,
    get_by: 1,
    get_by: 2,
    get_by!: 1,
    get_by!: 2
  ]
end
