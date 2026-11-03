# Reference implementations of custom filter and sort modules, exercised by
# test/schema/custom_filters_test.exs and test/schema/custom_sort_test.exs.
#
# Two styles are shown:
#
#   * "Open" modules `use BoxTurtle.Schema.Filters` / `use BoxTurtle.Schema.Sort` and add clauses for
#     named filters and sorts. Anything their clauses don't match falls through to the defaults (plain
#     column comparisons and column sorts). Suited to filters built by your own code.
#
#   * "Closed" modules implement the behaviour directly and accept only what they list. Suited to
#     filters and sorts that come straight from request params, where unknown keys must not reach
#     the database as column names.

defmodule BoxTurtle.Examples.Joins do
  @moduledoc """
  Joins an association once under a named binding, so several filters and sorts can share it.
  """
  import Ecto.Query

  @doc """
  Left-joins `assoc` as the named binding `assoc`, unless the query already has that binding.
  A left join keeps rows without the association; a filter's `where` on it removes them when
  it should.
  """
  def join_once(query, assoc) do
    if has_named_binding?(query, assoc),
      do: query,
      else: join(query, :left, [q], a in assoc(q, ^assoc), as: ^assoc)
  end
end

defmodule BoxTurtle.Examples.PostFilters do
  @moduledoc """
  An open filter module: named filters for posts, with plain column filters falling through to
  `BoxTurtle.Schema.Filters`.

  How the clauses work: `filter_with/2` receives the whole remaining filter list. Each clause
  matches the filter at the head, narrows the query, and passes the rest of the list back to
  `filter_with/2`, so filters after it are applied too, whether they are custom or plain. Filters
  no clause matches go to the default clauses that `use` adds after yours.

  Keys are matched exactly as given. The defaults accept string column names, but these clauses
  match atoms only, so `{"min_likes", 5}` would be treated as an (unknown) column. Convert
  request params to atoms you control first, or use a closed module such as
  `BoxTurtle.Examples.PostParamFilters`.
  """
  use BoxTurtle.Schema.Filters
  import Ecto.Query

  alias BoxTurtle.Examples.Joins

  # A comparison other than equality.
  def filter_with(query, [{:min_likes, likes} | rest]) do
    query
    |> where([p], p.likes >= ^likes)
    |> filter_with(rest)
  end

  # Text search. LIKE wildcards in the term are escaped so they match literally; ESCAPE is
  # spelled out because SQLite has no default escape character.
  def filter_with(query, [{:search, term} | rest]) do
    pattern = "%" <> String.replace(term, ["\\", "%", "_"], &("\\" <> &1)) <> "%"

    query
    |> where([p], fragment("? LIKE ? ESCAPE '\\'", p.title, ^pattern))
    |> filter_with(rest)
  end

  # Overriding a real column for one value: "any" means no restriction. Any other status
  # doesn't match this clause and falls through to the default equality filter.
  def filter_with(query, [{:status, "any"} | rest]), do: filter_with(query, rest)

  # A convenience flag expressed with other filters, which are then processed normally.
  def filter_with(query, [{:published, true} | rest]),
    do: filter_with(query, [{:status, "published"} | rest])

  def filter_with(query, [{:published, false} | rest]) do
    query
    |> where([p], p.status != "published")
    |> filter_with(rest)
  end

  # A filter on a belongs_to association, joined once under the :author binding that
  # BoxTurtle.Examples.PostSort shares.
  def filter_with(query, [{:author_name, name} | rest]) do
    query
    |> Joins.join_once(:author)
    |> where([author: a], a.name == ^name)
    |> filter_with(rest)
  end
end

defmodule BoxTurtle.Examples.AuthorFilters do
  @moduledoc """
  Filtering parents by their children. Joining a has_many would repeat a parent once per
  matching child, so the condition goes in a subquery instead and each author appears once.
  """
  use BoxTurtle.Schema.Filters
  import Ecto.Query

  alias BoxTurtle.Test.Post

  def filter_with(query, [{:has_post_with_status, status} | rest]) do
    authors_with_status = from(p in Post, where: p.status == ^status, select: p.author_id)

    query
    |> where([a], a.id in subquery(authors_with_status))
    |> filter_with(rest)
  end
end

defmodule BoxTurtle.Examples.PostParamFilters do
  @moduledoc """
  A closed filter module for filters taken straight from request params (string keys and
  string values). It implements `BoxTurtle.Schema.Filters.API` directly, without `use`, so only
  the filters listed here exist, and anything else raises `ArgumentError` instead of becoming a
  column lookup.

  `filter_with/2` can only return a query, so invalid input raises. Validate params beforehand
  (for example with a schemaless changeset) if you need `{:error, reason}` results.
  """
  @behaviour BoxTurtle.Schema.Filters.API

  import Ecto.Query

  alias BoxTurtle.Schema.Filters

  @statuses ~w(draft published archived)

  @impl true
  def filter_with(query, filters), do: Enum.reduce(filters, query, &filter(&2, &1))

  # Delegate plain column comparisons to the default implementation, with an atom you chose.
  defp filter(query, {"status", status}) when status in @statuses,
    do: Filters.apply_filter(query, {:status, status})

  defp filter(query, {"min_likes", likes}) do
    case Integer.parse(likes) do
      {likes, ""} -> where(query, [p], p.likes >= ^likes)
      _ -> raise ArgumentError, "min_likes must be an integer, got: #{inspect(likes)}"
    end
  end

  defp filter(_query, {key, value}) do
    raise ArgumentError, "unsupported post filter #{inspect(key)} => #{inspect(value)}"
  end
end

defmodule BoxTurtle.Examples.PostSort do
  @moduledoc """
  An open sort module. Like filters, each clause handles the head of the sort list and passes
  the rest back to `sort_by/2`, and anything unmatched falls through to the default column
  sorting of `BoxTurtle.Schema.Sort`.
  """
  use BoxTurtle.Schema.Sort
  import Ecto.Query

  alias BoxTurtle.Examples.Joins

  # A named sort. It ends on the primary key so rows with equal likes keep a stable order,
  # which pagination needs.
  def sort_by(query, [:popularity | rest]) do
    query
    |> order_by([p], desc: p.likes, asc: p.id)
    |> sort_by(rest)
  end

  # A sort on a joined column, written like a column sort ({direction, :author_name}). Without
  # this clause the default would look for an author_name column on posts.
  def sort_by(query, [{direction, :author_name} | rest])
      when direction in [:asc, :desc, :asc_nulls_last, :desc_nulls_last] do
    query
    |> Joins.join_once(:author)
    |> order_by([author: a], [{^direction, a.name}])
    |> sort_by(rest)
  end

  def sort_by(query, [:author_name | rest]), do: sort_by(query, [{:asc, :author_name} | rest])
end

defmodule BoxTurtle.Examples.PostParamSort do
  @moduledoc """
  A closed sort module for a `?sort=-likes,title` style parameter: column names as strings, with
  a leading `-` for descending order. Only the listed columns are sortable.

  The Query module's `:default_sort` also goes through this module, so it must be written in
  the same format (see `BoxTurtle.Examples.ParamPost.Query`).
  """
  @behaviour BoxTurtle.Schema.Sort.API

  import Ecto.Query

  @sortable ~w(title likes inserted_at id)

  @impl true
  def sort_by(query, specs), do: Enum.reduce(specs, query, &sort(&2, &1))

  defp sort(query, "-" <> column) when column in @sortable,
    do: order_by(query, [p], desc: field(p, ^String.to_existing_atom(column)))

  defp sort(query, column) when column in @sortable,
    do: order_by(query, [p], asc: field(p, ^String.to_existing_atom(column)))

  defp sort(_query, spec), do: raise(ArgumentError, "unsupported post sort #{inspect(spec)}")
end

defmodule BoxTurtle.Examples.Post.Query do
  @moduledoc """
  Wires the open filter and sort modules into a Query module, with a delegated author scope.
  """
  use BoxTurtle.Schema.Query,
    repo: BoxTurtle.Test.Repo,
    schema: BoxTurtle.Test.Post,
    filter_module: BoxTurtle.Examples.PostFilters,
    sorting_module: BoxTurtle.Examples.PostSort,
    delegates: [{BoxTurtle.Test.ByAuthor, %BoxTurtle.Test.Author{}}]

  delegate([:list_by, :count_by])
end

defmodule BoxTurtle.Examples.Author.Query do
  @moduledoc false
  use BoxTurtle.Schema.Query,
    repo: BoxTurtle.Test.Repo,
    schema: BoxTurtle.Test.Author,
    filter_module: BoxTurtle.Examples.AuthorFilters
end

defmodule BoxTurtle.Examples.ParamPost.Query do
  @moduledoc """
  Wires the closed, param-style modules. `:default_sort` uses the param format because it is
  passed to `BoxTurtle.Examples.PostParamSort` like any other sort.
  """
  use BoxTurtle.Schema.Query,
    repo: BoxTurtle.Test.Repo,
    schema: BoxTurtle.Test.Post,
    filter_module: BoxTurtle.Examples.PostParamFilters,
    sorting_module: BoxTurtle.Examples.PostParamSort,
    default_sort: ["id"]
end
