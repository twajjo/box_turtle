defmodule BoxTurtle.Schema.QueryTest do
  use BoxTurtle.DataCase

  alias BoxTurtle.Test.{Author, Post, Tag}

  defp titles(posts), do: Enum.map(posts, & &1.title)

  describe "get/2 and get!/2" do
    test "fetch by primary key" do
      post = post_fixture()

      assert {:ok, %Post{id: id}} = Post.Query.get(post.id)
      assert id == post.id
      assert %Post{id: ^id} = Post.Query.get!(post.id)
    end

    test "missing rows" do
      assert {:error, :not_found} = Post.Query.get(-1)
      assert Post.Query.get!(-1) == nil
      assert Post.Query.get!(nil) == nil
    end

    test "fetch by a map of columns" do
      post = post_fixture(%{title: "Unique"})
      assert %Post{id: id} = Post.Query.get!(%{title: "Unique"})
      assert id == post.id
    end

    test "honour call-time filters and preloads" do
      author = author_fixture()
      post = post_fixture(%{author_id: author.id, status: "published"})

      assert Post.Query.get!(post.id, filters: [status: "draft"]) == nil

      assert %Post{author: %Author{name: "Ursula"}} =
               Post.Query.get!(post.id, preloads: [:author])
    end

    test "works with KSUID keys" do
      {:ok, tag} = Tag.Change.create(%{name: "elixir"})
      assert {:ok, %Tag{name: "elixir"}} = Tag.Query.get(tag.id)
    end
  end

  describe "list!/1" do
    setup do
      for {title, status, likes} <- [
            {"a", "draft", 5},
            {"b", "published", 1},
            {"c", "published", 9}
          ] do
        post_fixture(%{title: title, status: status, likes: likes})
      end

      :ok
    end

    test "uses the default sort and page size" do
      assert {:ok, posts} = Post.Query.list()
      assert titles(posts) == ~w(a b c)
      assert Post.Query.list!(page: 1) |> titles() == ~w(a b)
      assert Post.Query.list!(page: 2) |> titles() == ~w(c)
    end

    test "page keyword form and out-of-range page numbers" do
      assert Post.Query.list!(page: [number: 2, size: 1]) |> titles() == ~w(b)
      assert Post.Query.list!(page: 0) |> titles() == ~w(a b)
    end

    test "sorts by columns, directions and custom sorts" do
      assert Post.Query.list!(sort: [desc: :title]) |> titles() == ~w(c b a)
      assert Post.Query.list!(sort: [:status, desc: :likes]) |> titles() == ~w(a c b)
      assert Post.Query.list!(sort: [:popularity]) |> titles() == ~w(c a b)
    end

    test "filters by equality, lists, nil and string keys" do
      assert Post.Query.list!(filters: [status: "published"]) |> titles() == ~w(b c)
      assert Post.Query.list!(filters: [title: ["a", "c"]]) |> titles() == ~w(a c)
      assert Post.Query.list!(filters: [author_id: nil]) |> length() == 3
      assert Post.Query.list!(filters: [{"status", "draft"}]) |> titles() == ~w(a)
    end

    test "custom filters fall through to the defaults" do
      assert Post.Query.list!(filters: [min_likes: 5, status: "published"]) |> titles() == ~w(c)
    end

    # SQLite has no DISTINCT ON, so check the query instead of running it.
    test "distinct" do
      assert inspect(Post.Query.query!(distinct: [:status])) =~ "distinct: [asc: p0.status]"
    end

    test "ignore_defaults drops the default sort" do
      refute inspect(Post.Query.query!(ignore_defaults: true)) =~ "order_by"
      assert inspect(Post.Query.query!()) =~ "order_by: [asc: p0.id]"
    end

    test "query!/1 builds without running" do
      assert %Ecto.Query{} = query = Post.Query.query!(filters: [status: "draft"])
      assert BoxTurtle.Test.Repo.all(query) |> titles() == ~w(a)
    end
  end

  describe "count!/1" do
    test "counts rows, honouring filters" do
      post_fixture(%{status: "published"})
      post_fixture(%{status: "published"})
      post_fixture()

      assert Post.Query.count!() == 3
      assert {:ok, 2} = Post.Query.count(filters: [status: "published"])
    end

    test "groups" do
      post_fixture(%{status: "published"})
      post_fixture(%{status: "published"})
      post_fixture()

      counts = Post.Query.count!(group_by: [:status]) |> Enum.sort_by(& &1.status)
      assert counts == [%{status: "draft", count: 1}, %{status: "published", count: 2}]
    end

    test "counts distinct values" do
      post_fixture(%{status: "published"})
      post_fixture(%{status: "published"})
      assert Post.Query.count!(distinct: [:status]) == 1
    end

    test "works for schemas without timestamps" do
      {:ok, _} = Tag.Change.create(%{name: "one"})
      assert Tag.Query.count!() == 1
    end
  end

  describe "extensions" do
    test "delegate/1 forwards %Author{} patterns to the scope module" do
      ursula = author_fixture()
      other = author_fixture(%{name: "Octavia"})
      post_fixture(%{title: "mine", author_id: ursula.id})
      post_fixture(%{title: "theirs", author_id: other.id})

      assert {:ok, [%Post{title: "mine"}]} = Post.Query.list_by(ursula)
      assert {:ok, 1} = Post.Query.count_by(ursula, filters: [title: "mine"])
    end

    test "nil patterns fall back to the unscoped query" do
      post_fixture()
      post_fixture()
      assert {:ok, 2} = Post.Query.count_by(nil)
      assert {:ok, [_, _]} = Post.Query.list_by(nil)
    end

    test "extend/2 adds custom clauses" do
      post_fixture(%{title: "Findable"})
      assert %Post{title: "Findable"} = Post.Query.get_by!("Findable")
    end
  end

  describe "use options" do
    test "the schema defaults to the parent module" do
      assert Post.Query.schema() == Post
      assert Post.Query.default_sort() == [asc: :id]
      assert Tag.Query.primary_key() == :id
    end

    test "call-time options override use-time settings" do
      assert Post.Query.schema(schema: Author) == Author
      assert Post.Query.inject_query_options(page_size: 7)[:page_size] == 7
    end

    test ":repo is required" do
      assert_raise ArgumentError, ~r/requires the :repo option/, fn ->
        Code.compile_string("defmodule BadQuery.Query do use BoxTurtle.Schema.Query end")
      end
    end

    test "unknown options are rejected" do
      assert_raise ArgumentError, ~r/unknown keys \[:default_order\]/, fn ->
        Code.compile_string("""
        defmodule BadQuery2.Query do
          use BoxTurtle.Schema.Query, repo: BoxTurtle.Test.Repo, default_order: [:id]
        end
        """)
      end
    end

    test "unknown extensions are rejected" do
      assert_raise ArgumentError, ~r/unknown Query extension :find_by/, fn ->
        Code.compile_string("""
        defmodule BadQuery3.Query do
          use BoxTurtle.Schema.Query, repo: BoxTurtle.Test.Repo
          delegate [:find_by]
        end
        """)
      end
    end
  end
end
