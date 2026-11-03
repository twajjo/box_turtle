defmodule BoxTurtle.Schema do
  @moduledoc """
  A convention-driven data-access layer for Ecto schemas.

  For a schema `MyApp.Blog.Post`, define two sibling modules and let them be the only code that touches the Repo:

      defmodule MyApp.Blog.Post.Query do
        use BoxTurtle.Schema.Query, repo: MyApp.Repo, default_sort: [desc: :inserted_at]
      end

      defmodule MyApp.Blog.Post.Change do
        use BoxTurtle.Schema.Change, repo: MyApp.Repo
      end

      alias MyApp.Blog.Post

      {:ok, post} = Post.Change.create(%{title: "Hello"})   # uses Post.changeset/2
      [^post] = Post.Query.list!(filters: [title: "Hello"])
      1 = Post.Query.count!()

    * `BoxTurtle.Schema.Query` - `get`, `list`, `count` and `query!` with filters, sorting, pagination,
      preloads, grouping and distinct, plus pattern-scoped `*_by` extensions.
    * `BoxTurtle.Schema.Change` - `create`, `update` and `delete`.
    * `BoxTurtle.Schema.Filters`, `BoxTurtle.Schema.Sort` - default filtering and sorting, and bases for
      schema-specific versions.
    * `BoxTurtle.Schema.Pagination` - limit/offset paging.
    * `BoxTurtle.Schema.Ecto.Ksuid` - a KSUID `Ecto.Type`.

  See the Schema guide for a complete walkthrough.
  """
end
