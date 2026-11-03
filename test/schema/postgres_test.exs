defmodule BoxTurtle.Test.Pg.Post.Query do
  use BoxTurtle.Schema.Query,
    repo: BoxTurtle.Test.PgRepo,
    schema: BoxTurtle.Test.Post,
    default_distinct: [:status],
    default_sort: [:status, :id]
end

defmodule BoxTurtle.Schema.PostgresTest do
  # PostgreSQL-only behaviour, run when BOX_TURTLE_PG_URL is set (see test_helper.exs).
  use ExUnit.Case

  @moduletag :postgres

  alias BoxTurtle.Test.{Author, PgRepo, Post}
  alias BoxTurtle.Test.Pg.Post.Query, as: DistinctQuery
  alias Ecto.Adapters.SQL.Sandbox

  setup do
    pid = Sandbox.start_owner!(PgRepo)
    on_exit(fn -> Sandbox.stop_owner(pid) end)
    :ok
  end

  defp author!(name), do: PgRepo.insert!(%Author{name: name})

  defp post!(title, status, author \\ nil) do
    PgRepo.insert!(%Post{title: title, status: status, author_id: author && author.id})
  end

  defp list(opts), do: Post.Query.list!(Keyword.put(opts, :repo, PgRepo))

  describe "distinct" do
    setup do
      ann = author!("Ann")
      post!("a", "draft", ann)
      post!("b", "published", ann)
      post!("c", "published")
      %{ann: ann}
    end

    test "returns one row per distinct value" do
      assert list(distinct: [:status], sort: [:status, :id]) |> Enum.map(&{&1.status, &1.title}) ==
               [{"draft", "a"}, {"published", "b"}]
    end

    test "works with a single column and with filters" do
      assert list(distinct: :status, filters: [author_id: nil]) |> Enum.map(& &1.title) == ~w(c)
    end

    test "default_distinct applies unless ignored" do
      assert DistinctQuery.list!() |> Enum.map(& &1.title) == ~w(a b)
      assert DistinctQuery.list!(ignore_defaults: true) |> length() == 3
      assert DistinctQuery.list!(distinct: []) |> length() == 3
    end

    test "counts with distinct use COUNT(DISTINCT column)" do
      assert Post.Query.count!(repo: PgRepo, distinct: [:status]) == 2
      assert DistinctQuery.count!() == 2
    end

    test "combined with a to-many preload, distinct picks parents, not joined child rows", %{
      ann: ann
    } do
      other_ann = author!("Ann")
      post!("d", "draft", other_ann)
      author!("Bob")

      authors =
        Author.Query.list!(
          repo: PgRepo,
          distinct: [:name],
          sort: [:name, :id],
          preloads: [:posts]
        )

      assert Enum.map(authors, & &1.name) == ~w(Ann Bob)
      assert [%Author{id: id, posts: posts}, %Author{posts: []}] = authors
      assert id == ann.id
      assert posts |> Enum.map(& &1.title) |> Enum.sort() == ~w(a b)
    end
  end

  test "join preloads, paging and grouped counts run on PostgreSQL" do
    ann = author!("Ann")
    for t <- ~w(a1 a2 a3), do: post!(t, "draft", ann)
    bob = author!("Bob")
    post!("b1", "published", bob)

    page =
      Author.Query.list!(
        repo: PgRepo,
        preloads: [:posts],
        sort: [:name],
        page: [number: 1, size: 1]
      )

    assert [%Author{name: "Ann", posts: posts}] = page
    assert length(posts) == 3

    assert [%Post{author: %Author{name: "Bob"}}] =
             list(filters: [status: "published"], preloads: [author: :posts])

    counts = Post.Query.count!(repo: PgRepo, group_by: [:status]) |> Enum.sort_by(& &1.status)
    assert counts == [%{status: "draft", count: 3}, %{status: "published", count: 1}]
  end
end
