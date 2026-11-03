defmodule BoxTurtle.Schema.JoinPreloadsTest do
  use BoxTurtle.DataCase

  @query_event [:box_turtle, :test, :repo, :query]

  setup do
    test_pid = self()
    handler = "join-preloads-#{inspect(test_pid)}"

    :telemetry.attach(
      handler,
      @query_event,
      fn _event, _measurements, meta, _config ->
        send(test_pid, {:query, meta.query})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler) end)
  end

  # Runs fun and returns {result, number of SQL queries it issued}.
  defp counting_queries(fun) do
    flush_queries()
    result = fun.()
    {result, flush_queries()}
  end

  defp flush_queries(count \\ 0) do
    receive do
      {:query, _sql} -> flush_queries(count + 1)
    after
      0 -> count
    end
  end

  defp author_with_posts(name, titles) do
    author = author_fixture(%{name: name})
    for title <- titles, do: post_fixture(%{title: title, author_id: author.id})
    author
  end

  describe "belongs_to" do
    test "list! loads the association in the same query" do
      author = author_with_posts("Ursula", ~w(a b))
      post_fixture(%{title: "orphan"})

      {posts, queries} = counting_queries(fn -> Post.Query.list!(preloads: [:author]) end)

      assert queries == 1

      assert [%Post{author: %Author{id: id}}, %Post{author: %Author{id: id}}, %Post{author: nil}] =
               posts

      assert id == author.id
    end

    test "get! loads the association in the same query" do
      author = author_with_posts("Ursula", ~w(a))
      [post] = Post.Query.list!()

      {found, queries} = counting_queries(fn -> Post.Query.get!(post.id, preloads: :author) end)

      assert queries == 1
      assert found.author.id == author.id
    end
  end

  describe "has_many" do
    test "list! returns each parent once with all of its children" do
      author_with_posts("Ann", ~w(a1 a2 a3))
      author_with_posts("Bob", ~w(b1))
      author_fixture(%{name: "Cy"})

      {authors, queries} =
        counting_queries(fn -> Author.Query.list!(preloads: [:posts], sort: [:name]) end)

      assert queries == 1
      assert Enum.map(authors, & &1.name) == ~w(Ann Bob Cy)
      assert authors |> Enum.map(&length(&1.posts)) == [3, 1, 0]
    end

    test "pages count parents, not joined child rows" do
      author_with_posts("Ann", ~w(a1 a2 a3))
      author_with_posts("Bob", ~w(b1 b2))
      author_with_posts("Cy", ~w(c1))

      {page1, queries} =
        counting_queries(fn ->
          Author.Query.list!(preloads: [:posts], sort: [:name], page: [number: 1, size: 2])
        end)

      assert queries == 1
      assert Enum.map(page1, &{&1.name, length(&1.posts)}) == [{"Ann", 3}, {"Bob", 2}]

      page2 = Author.Query.list!(preloads: [:posts], sort: [:name], page: [number: 2, size: 2])
      assert Enum.map(page2, &{&1.name, length(&1.posts)}) == [{"Cy", 1}]
    end

    test "get! with a to-many preload" do
      author = author_with_posts("Ann", ~w(a1 a2))

      {found, queries} =
        counting_queries(fn -> Author.Query.get!(author.id, preloads: [:posts]) end)

      assert queries == 1
      assert found.posts |> Enum.map(& &1.title) |> Enum.sort() == ~w(a1 a2)
    end
  end

  test "nested preloads are joined to any depth in one query" do
    author_with_posts("Ann", ~w(a1 a2))

    {posts, queries} =
      counting_queries(fn -> Post.Query.list!(preloads: [author: [posts: :author]]) end)

    assert queries == 1
    assert [%Post{author: %Author{posts: siblings}} | _] = posts
    assert length(siblings) == 2
    assert Enum.all?(siblings, &match?(%Post{author: %Author{name: "Ann"}}, &1))
  end

  test "duplicate preloads are merged" do
    author_with_posts("Ann", ~w(a1))
    query = Post.Query.query!(preloads: [:author, :author, author: :posts])
    assert length(query.joins) == 2
  end

  test "unknown associations raise" do
    assert_raise ArgumentError, ~r/has no association :nope/, fn ->
      Post.Query.query!(preloads: [:nope])
    end
  end

  test "preload queries and functions are rejected" do
    assert_raise ArgumentError, ~r/must be association names/, fn ->
      Post.Query.query!(preloads: [author: Ecto.Queryable.to_query(Author)])
    end
  end
end
