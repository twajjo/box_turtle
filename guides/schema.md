# Schema guide

`BoxTurtle.Schema` gives every Ecto schema the same small data-access API. Callers use it instead of building queries and calling the Repo themselves.

This guide builds a blog with `Author` and `Post` schemas, then adds custom filters, custom sorts, pagination and pattern-scoped queries.

## 1. Schemas

BoxTurtle works with plain Ecto schemas. The only requirement is a changeset function for writes (`changeset/2` by default).

```elixir
defmodule MyApp.Blog.Author do
  use Ecto.Schema
  import Ecto.Changeset

  schema "authors" do
    field :name, :string
    has_many :posts, MyApp.Blog.Post
    timestamps()
  end

  def changeset(author, attrs) do
    author |> cast(attrs, [:name]) |> validate_required([:name])
  end
end

defmodule MyApp.Blog.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    field :title, :string
    field :status, :string, default: "draft"
    field :likes, :integer, default: 0
    belongs_to :author, MyApp.Blog.Author
    timestamps()
  end

  def changeset(post, attrs) do
    post
    |> cast(attrs, [:title, :status, :likes, :author_id])
    |> validate_required([:title])
  end

  # Used for updates: only the status may change after creation.
  def update_changeset(post, attrs) do
    post
    |> cast(attrs, [:status])
    |> validate_inclusion(:status, ~w(draft published archived))
  end
end
```

## 2. Query and Change modules

Put the modules inside the schema's namespace. The schema is then inferred: `MyApp.Blog.Post.Query` serves `MyApp.Blog.Post`. If yours live elsewhere, pass `schema:` explicitly.

```elixir
defmodule MyApp.Blog.Post.Query do
  use BoxTurtle.Schema.Query,
    repo: MyApp.Repo,
    default_sort: [desc: :inserted_at],
    page_size: 20
end

defmodule MyApp.Blog.Post.Change do
  use BoxTurtle.Schema.Change, repo: MyApp.Repo, update_changeset: :update_changeset
end
```

All `use` options are documented in `BoxTurtle.Schema.Query` and `BoxTurtle.Schema.Change`.

## 3. Writing

```elixir
alias MyApp.Blog.Post

{:ok, post} = Post.Change.create(%{title: "Hello", author_id: author.id})
{:error, %Ecto.Changeset{}} = Post.Change.create(%{})

{:ok, post} = Post.Change.update(post, %{status: "published"})
post = Post.Change.update!(post, %{status: "archived"})

{:ok, _} = Post.Change.delete(post)        # a struct...
{:ok, _} = Post.Change.delete(post.id)     # ...or a primary key
{:error, :not_found} = Post.Change.delete(-1)
Post.Change.delete!(-1)                    # raises Ecto.NoResultsError
```

`create/1` and `update/1` also accept a ready-made `Ecto.Changeset`. Inserts use `:create_changeset` and updates use `:update_changeset`; both default to `:changeset`.

## 4. Reading

Every function has a tuple form and a `!` form:

```elixir
{:ok, post} = Post.Query.get(id)
{:error, :not_found} = Post.Query.get(-1)
nil = Post.Query.get!(-1)
post = Post.Query.get!(%{title: "Hello"})   # look up by other columns

{:ok, posts} = Post.Query.list()
posts = Post.Query.list!(filters: [status: "published"])

Post.Query.count!()                          #=> 3
Post.Query.count!(group_by: [:status])       #=> [%{status: "draft", count: 1}, %{status: "published", count: 2}]
Post.Query.count!(distinct: [:author_id])    #=> number of distinct authors

query = Post.Query.query!(filters: [status: "draft"])   # an Ecto.Query, not run yet
```

Call-time options (all of them are listed in `BoxTurtle.Schema.Query.API`):

| Option | Example | Meaning |
|---|---|---|
| `:filters` | `[status: "draft", author_id: nil]` | `WHERE`, see below |
| `:sort` | `[desc: :likes, asc: :id]` | `ORDER BY`, replaces the default sort |
| `:page` | `2` or `[number: 2, size: 10]` | `LIMIT`/`OFFSET` |
| `:preloads` | `[:author, comments: :user]` | associations, `LEFT JOIN`ed and loaded in the same query |
| `:group_by` | `[:status]` | `count` returns one map per group |
| `:distinct` | `[:author_id]` | `DISTINCT ON` for lists (PostgreSQL), `COUNT(DISTINCT ...)` for counts |
| `:ignore_defaults` | `true` | skip the module's default sort, preloads and distinct |

### Filters

Default filters compare columns:

```elixir
filters: [status: "published"]                 # status = 'published'
filters: [status: ["draft", "published"]]      # status IN (...)
filters: [author_id: nil]                      # author_id IS NULL
filters: [{"status", "draft"}]                 # string keys, if the atom already exists
```

String keys are converted with `String.to_existing_atom/1`, so filters built from request params can't create new atoms. Still, only pass column names you allow. Any column of the schema is filterable.

For anything other than equality, write a filter module. Clauses you don't define fall through to the defaults:

```elixir
defmodule MyApp.Blog.Post.Filters do
  use BoxTurtle.Schema.Filters
  import Ecto.Query

  def filter_with(query, [{:min_likes, likes} | rest]) do
    query
    |> where([p], p.likes >= ^likes)
    |> filter_with(rest)
  end
end
```

Pass it with `filter_module: MyApp.Blog.Post.Filters`. Then `Post.Query.list!(filters: [status: "published", min_likes: 10])` works.

### Sorting

A sort spec is a list of columns, `{direction, column}` pairs, or `{direction, [columns]}`. Keyword lists work as-is: `[desc: :inserted_at, asc: :id]`. Named sorts work like filters:

```elixir
defmodule MyApp.Blog.Post.Sort do
  use BoxTurtle.Schema.Sort
  import Ecto.Query

  def sort_by(query, [:popularity | rest]) do
    query
    |> order_by([p], desc: p.likes, asc: p.id)
    |> sort_by(rest)
  end
end
```

Pass it with `sorting_module: MyApp.Blog.Post.Sort`, then call `Post.Query.list!(sort: [:popularity])`. An unknown sort element raises `ArgumentError`.

### Preloads

Preloads are fetched with `LEFT JOIN`s, so a list or get, together with all its associations, is a single round trip to the database. Ecto's plain `preload` issues one extra query per association. Nesting works to any depth:

```elixir
Post.Query.list!(preloads: [author: [:company], comments: :user])
```

Joining a `has_many` repeats each parent row once per child. To keep `:page` and `:distinct` counting parents, BoxTurtle applies them in a primary-key subquery when a to-many association is preloaded, still in the same statement. Preloads accept association names only, not preload queries or functions.

### Pagination

`page: n` returns page `n` of `:page_size` rows (default 40). `page: [number: n, size: s]` sets the size per call. Pages below 1 are treated as 1. Combine pagination with a sort, since pages without an `ORDER BY` are not stable.

## 5. Scoped queries: `extend` and `delegate`

The optional `*_by(pattern, opts \\ [])` functions (`get_by`, `list_by`, `count_by`, `query_by!` and their `!` variants) answer questions like "the posts of this author".

### `extend/2`: your own clauses

```elixir
defmodule MyApp.Blog.Post.Query do
  use BoxTurtle.Schema.Query, repo: MyApp.Repo

  extend :get_by! do
    def get_by!(slug, opts) when is_binary(slug), do: get!(%{slug: slug}, opts)
  end

  extend :list_by do
    def list_by(%MyApp.Blog.Author{id: id}, opts), do: list(add_filters(opts, author_id: id))
  end
end

Post.Query.get_by!("hello-world")
{:ok, posts} = Post.Query.list_by(author)
{:ok, all} = Post.Query.list_by(nil)    # nil means unscoped
```

`extend/2` generates the function head with the `opts \\ []` default. For `list_by`, `count_by` and `query_by!` (and their variants), it also adds a clause that treats a `nil` pattern as "everything".

### `delegate/1`: share a scope across schemas

When many schemas are scoped the same way (every row with an `author_id`, say), write the scope once in a delegate module:

```elixir
defmodule MyApp.Blog.ByAuthor do
  use BoxTurtle.Schema.Query, repo: MyApp.Repo, schema: MyApp.Blog.Author

  extend :list_by do
    def list_by(%MyApp.Blog.Author{id: id}, opts), do: list(add_filters(opts, author_id: id))
  end

  extend :count_by do
    def count_by(%MyApp.Blog.Author{id: id}, opts), do: count(add_filters(opts, author_id: id))
  end
end
```

and delegate to it from each schema's Query module:

```elixir
defmodule MyApp.Blog.Post.Query do
  use BoxTurtle.Schema.Query,
    repo: MyApp.Repo,
    delegates: [{MyApp.Blog.ByAuthor, %MyApp.Blog.Author{}}]

  delegate [:list_by, :count_by]
end

{:ok, posts} = Post.Query.list_by(author)
{:ok, 3} = Post.Query.count_by(author, filters: [status: "published"])
```

`Post.Query` passes `%Author{}` arguments to `ByAuthor` with its own settings (repo, schema, default sort and so on) injected into the options. So `ByAuthor.list/1` queries posts, not authors. A delegate clause is generated only if the delegate module defines that function.

## 6. KSUID primary keys

```elixir
@primary_key {:id, BoxTurtle.Schema.Ecto.Ksuid, autogenerate: true}
schema "tags" do
  field :name, :string
end
```

KSUIDs are 27-character, time-sortable strings. Store them in a `:string` (or `char(27)`) column.

## 7. Testing

The generated functions are ordinary module functions, so test them with your usual `DataCase` and the Ecto SQL sandbox. BoxTurtle's own suite runs against SQLite (`ecto_sqlite3`); see `test/support/` in the repository for a compact example setup.
