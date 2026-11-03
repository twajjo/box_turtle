# Schema guide

`BoxTurtle.Schema` gives every Ecto schema the same small data-access API. Callers use it instead of building queries and calling the Repo themselves.

This guide builds a small blog step by step. Every snippet is complete, and later snippets show each module in full as it grows. Run them in order in `iex -S mix` and you'll get the results shown. The guide assumes an application `:my_app` with an Ecto repo `MyApp.Repo`.

## 1. Schemas and migration

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

  # Used for inserts.
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

```elixir
# priv/repo/migrations/20260101000000_create_blog.exs
defmodule MyApp.Repo.Migrations.CreateBlog do
  use Ecto.Migration

  def change do
    create table(:authors) do
      add :name, :string, null: false
      timestamps()
    end

    create table(:posts) do
      add :title, :string, null: false
      add :status, :string, null: false, default: "draft"
      add :likes, :integer, null: false, default: 0
      add :author_id, references(:authors, on_delete: :delete_all)
      timestamps()
    end

    create index(:posts, [:author_id])
  end
end
```

## 2. Query and Change modules

Put the modules inside the schema's namespace. The schema is then inferred: `MyApp.Blog.Post.Query` serves `MyApp.Blog.Post`. If yours live elsewhere, pass `schema:` explicitly.

```elixir
defmodule MyApp.Blog.Author.Query do
  use BoxTurtle.Schema.Query, repo: MyApp.Repo, default_sort: [:name, :id]
end

defmodule MyApp.Blog.Author.Change do
  use BoxTurtle.Schema.Change, repo: MyApp.Repo
end

defmodule MyApp.Blog.Post.Query do
  # Newest first; the id breaks ties between rows inserted in the same second.
  use BoxTurtle.Schema.Query, repo: MyApp.Repo, default_sort: [desc: :inserted_at, desc: :id]
end

defmodule MyApp.Blog.Post.Change do
  use BoxTurtle.Schema.Change, repo: MyApp.Repo, update_changeset: :update_changeset
end
```

All `use` options are documented in `BoxTurtle.Schema.Query` and `BoxTurtle.Schema.Change`.

## 3. Writing

```elixir
alias MyApp.Blog.{Author, Post}

{:ok, ann} = Author.Change.create(%{name: "Ann"})
{:ok, bob} = Author.Change.create(%{name: "Bob"})

{:ok, hello} = Post.Change.create(%{title: "Hello", author_id: ann.id})
{:ok, _second} = Post.Change.create(%{title: "Second post", likes: 12, author_id: ann.id})
{:ok, _news} = Post.Change.create(%{title: "Bob's news", status: "published", likes: 5, author_id: bob.id})
{:ok, scratch} = Post.Change.create(%{title: "Scratch"})

# changeset/2 requires a title
{:error, %Ecto.Changeset{}} = Post.Change.create(%{})

# Updates go through update_changeset/2
{:ok, hello} = Post.Change.update(hello, %{status: "published"})
{:error, %Ecto.Changeset{}} = Post.Change.update(hello, %{status: "deleted"})

# Delete a struct, a changeset or a primary key
{:ok, _} = Post.Change.delete(scratch)
{:error, :not_found} = Post.Change.delete(scratch.id)
```

`create/1` and `update/1` also accept a ready-made `Ecto.Changeset`. `create!/1`, `update!/2` and `delete!/1` return the struct or raise; `delete!/1` raises `Ecto.NoResultsError` for a missing key.

The blog now has three posts:

| title | status | likes | author |
|---|---|---|---|
| Hello | published | 0 | Ann |
| Second post | draft | 12 | Ann |
| Bob's news | published | 5 | Bob |

## 4. Reading

Every function has a tuple form and a `!` form:

```elixir
{:ok, %Post{title: "Hello"}} = Post.Query.get(hello.id)
{:error, :not_found} = Post.Query.get(-1)
nil = Post.Query.get!(-1)
%Post{likes: 12} = Post.Query.get!(%{title: "Second post"})   # look up by other columns

Post.Query.list!() |> Enum.map(& &1.title)
#=> ["Bob's news", "Second post", "Hello"]   (newest first)

Post.Query.list!(filters: [status: "published"], sort: [:title]) |> Enum.map(& &1.title)
#=> ["Bob's news", "Hello"]

Post.Query.count!()                          #=> 3
Post.Query.count!(group_by: [:status])       #=> [%{status: "draft", count: 1}, %{status: "published", count: 2}]
Post.Query.count!(distinct: [:author_id])    #=> 2

# An Ecto.Query, not run yet, to compose further or run yourself
query = Post.Query.query!(filters: [author_id: ann.id])
2 = query |> MyApp.Repo.all() |> length()
```

Call-time options (all of them are listed in `BoxTurtle.Schema.Query.API`):

| Option | Example | Meaning |
|---|---|---|
| `:filters` | `[status: "draft", author_id: nil]` | `WHERE`, see below |
| `:sort` | `[desc: :likes, asc: :id]` | `ORDER BY`, replaces the default sort |
| `:page` | `2` or `[number: 2, size: 10]` | `LIMIT`/`OFFSET` |
| `:preloads` | `[author: :posts]` | associations, `LEFT JOIN`ed and loaded in the same query |
| `:group_by` | `[:status]` | `count` returns one map per group |
| `:distinct` | `[:author_id]` | `DISTINCT ON` for lists (PostgreSQL only; other adapters raise `ArgumentError`), `COUNT(DISTINCT ...)` for counts on any adapter |
| `:ignore_defaults` | `true` | skip the module's default sort, preloads and distinct |

### Filters

Default filters compare columns:

```elixir
Post.Query.count!(filters: [status: "published"])                # status = 'published'       => 2
Post.Query.count!(filters: [status: ["draft", "published"]])     # status IN (...)            => 3
Post.Query.count!(filters: [author_id: nil])                     # author_id IS NULL          => 0
Post.Query.count!(filters: [{"status", "draft"}])                # string key, existing atom  => 1
```

String keys are converted with `String.to_existing_atom/1`, so filters built from request params can't create new atoms. Still, only pass column names you allow. Any column of the schema is filterable.

For anything other than equality, write a filter module. Each clause handles the filter at the head of the list and must pass the rest back to `filter_with/2`. Filters your clauses don't match fall through to the defaults:

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

defmodule MyApp.Blog.Post.Query do
  use BoxTurtle.Schema.Query,
    repo: MyApp.Repo,
    default_sort: [desc: :inserted_at, desc: :id],
    filter_module: MyApp.Blog.Post.Filters
end
```

```elixir
Post.Query.list!(filters: [status: "published", min_likes: 1]) |> Enum.map(& &1.title)
#=> ["Bob's news"]
```

Custom clauses see keys exactly as given, so match atoms and convert request params yourself.

### Sorting

A sort spec is a list of columns, `{direction, column}` pairs, or `{direction, [columns]}`. Keyword lists work as-is: `[desc: :inserted_at, asc: :id]`. Named sorts work like filters:

```elixir
defmodule MyApp.Blog.Post.Sort do
  use BoxTurtle.Schema.Sort
  import Ecto.Query

  # Most liked first; the id keeps the order stable for pagination.
  def sort_by(query, [:popularity | rest]) do
    query
    |> order_by([p], desc: p.likes, asc: p.id)
    |> sort_by(rest)
  end
end

defmodule MyApp.Blog.Post.Query do
  use BoxTurtle.Schema.Query,
    repo: MyApp.Repo,
    default_sort: [desc: :inserted_at, desc: :id],
    filter_module: MyApp.Blog.Post.Filters,
    sorting_module: MyApp.Blog.Post.Sort
end
```

```elixir
Post.Query.list!(sort: [:popularity]) |> Enum.map(& &1.title)
#=> ["Second post", "Bob's news", "Hello"]
```

An unknown sort element raises `ArgumentError`.

### Preloads

Preloads are fetched with `LEFT JOIN`s, so a list or get, together with all its associations, is a single round trip to the database. Ecto's plain `preload` issues one extra query per association. Nesting works to any depth:

```elixir
[%Post{author: %Author{name: "Bob"}} | _] = Post.Query.list!(preloads: [:author])

Author.Query.list!(preloads: [posts: :author])
|> Enum.map(&{&1.name, length(&1.posts)})
#=> [{"Ann", 2}, {"Bob", 1}]
```

Joining a `has_many` repeats each parent row once per child. To keep `:page` and `:distinct` counting parents, BoxTurtle applies them in a primary-key subquery when a to-many association is preloaded, still in the same statement. Preloads accept association names only, not preload queries or functions.

### Pagination

`page: n` returns page `n` of `:page_size` rows (default 40; set `page_size:` in `use BoxTurtle.Schema.Query` to change it). `page: [number: n, size: s]` sets the size per call. Pages below 1 are treated as 1.

```elixir
Post.Query.list!(sort: [:popularity], page: [number: 1, size: 2]) |> Enum.map(& &1.title)
#=> ["Second post", "Bob's news"]

Post.Query.list!(sort: [:popularity], page: [number: 2, size: 2]) |> Enum.map(& &1.title)
#=> ["Hello"]
```

Always page with a sort that ends in a unique column, so rows don't move between pages.

### More filter and sort examples

The repository has reference filter and sort modules with tests that use them:
[`test/support/examples/schema.ex`](https://github.com/twajjo/box_turtle/blob/main/test/support/examples/schema.ex),
[`custom_filters_test.exs`](https://github.com/twajjo/box_turtle/blob/main/test/schema/custom_filters_test.exs)
and [`custom_sort_test.exs`](https://github.com/twajjo/box_turtle/blob/main/test/schema/custom_sort_test.exs). They cover:

- **Open modules** (`use BoxTurtle.Schema.Filters` / `Sort`):
  - comparisons, LIKE search with escaping, flags that expand to other filters;
  - overriding a real column for one value;
  - filters and sorts on a joined association, sharing one named join;
  - filtering parents by their children with a subquery.
- **Closed modules** that implement the behaviour directly. They accept only allow-listed, string-keyed request params, and everything else raises.

## 5. Scoped queries: `extend` and `delegate`

The optional `*_by(pattern, opts \\ [])` functions (`get_by`, `list_by`, `count_by`, `query_by!` and their `!` variants) answer questions like "the posts of this author".

- `extend/2` defines one of them with your own clauses. It generates the function head with the `opts \\ []` default. For `list_by`, `count_by` and `query_by!` (and their variants), it also adds a clause that treats a `nil` pattern as "everything".
- `delegate/1` defines them by forwarding to a shared delegate module. Use it when many schemas are scoped the same way (every row with an `author_id`, say).

Write the scope once, in a delegate module. It is an ordinary Query module whose clauses use `extend/2`:

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

Then delegate to it from each schema's Query module, and add your own clauses with `extend/2`. This is the final `Post.Query`:

```elixir
defmodule MyApp.Blog.Post.Query do
  use BoxTurtle.Schema.Query,
    repo: MyApp.Repo,
    default_sort: [desc: :inserted_at, desc: :id],
    filter_module: MyApp.Blog.Post.Filters,
    sorting_module: MyApp.Blog.Post.Sort,
    delegates: [{MyApp.Blog.ByAuthor, %MyApp.Blog.Author{}}]

  # list_by/2 and count_by/2 for %Author{} (and nil) patterns
  delegate [:list_by, :count_by]

  # get_by!/2 for a title
  extend :get_by! do
    def get_by!(title, opts) when is_binary(title), do: get!(%{title: title}, opts)
  end
end
```

```elixir
{:ok, posts} = Post.Query.list_by(ann)
Enum.map(posts, & &1.title)   #=> ["Second post", "Hello"]

{:ok, 1} = Post.Query.count_by(ann, filters: [status: "published"])
{:ok, 2} = Post.Query.count_by(ann, filters: [min_likes: 0])   # custom filters work in delegates too
{:ok, all_posts} = Post.Query.list_by(nil)                     # nil means unscoped
3 = length(all_posts)

%Post{likes: 5} = Post.Query.get_by!("Bob's news")
```

`Post.Query` passes `%Author{}` arguments to `ByAuthor` with its own settings (repo, schema, default sort, filter module and so on) injected into the options. So `ByAuthor.list/1` queries posts, not authors. A delegate clause is generated only if the delegate module defines that function. That check happens at compile time, so the delegate must compile first. Mix handles this when the delegate is in its own file; within a single file, define the delegate above the modules that use it.

## 6. KSUID primary keys

```elixir
defmodule MyApp.Blog.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, BoxTurtle.Schema.Ecto.Ksuid, autogenerate: true}
  schema "tags" do
    field :name, :string
  end

  def changeset(tag, attrs), do: tag |> cast(attrs, [:name]) |> validate_required([:name])
end

defmodule MyApp.Blog.Tag.Query do
  use BoxTurtle.Schema.Query, repo: MyApp.Repo, default_sort: [:name]
end

defmodule MyApp.Blog.Tag.Change do
  use BoxTurtle.Schema.Change, repo: MyApp.Repo
end
```

```elixir
# priv/repo/migrations/20260101000001_create_tags.exs
defmodule MyApp.Repo.Migrations.CreateTags do
  use Ecto.Migration

  def change do
    create table(:tags, primary_key: false) do
      add :id, :string, size: 27, primary_key: true
      add :name, :string, null: false
    end
  end
end
```

```elixir
{:ok, tag} = MyApp.Blog.Tag.Change.create(%{name: "elixir"})
27 = String.length(tag.id)
{:ok, ^tag} = MyApp.Blog.Tag.Query.get(tag.id)
```

KSUIDs are 27-character, time-sortable strings.

## 7. Testing

The generated functions are ordinary module functions, so test them through your context with the Ecto SQL sandbox. With a Phoenix-generated `MyApp.DataCase`:

```elixir
defmodule MyApp.BlogTest do
  use MyApp.DataCase, async: true

  alias MyApp.Blog.{Author, Post}

  test "list_by/2 returns only the author's published posts" do
    {:ok, ann} = Author.Change.create(%{name: "Ann"})
    {:ok, bob} = Author.Change.create(%{name: "Bob"})
    {:ok, _} = Post.Change.create(%{title: "Mine", status: "published", author_id: ann.id})
    {:ok, _} = Post.Change.create(%{title: "Draft", author_id: ann.id})
    {:ok, _} = Post.Change.create(%{title: "Theirs", status: "published", author_id: bob.id})

    assert {:ok, [%Post{title: "Mine"}]} = Post.Query.list_by(ann, filters: [status: "published"])
  end
end
```

BoxTurtle's own suite runs against SQLite (`ecto_sqlite3`). For a compact setup, see `test/support/` in the repository.
