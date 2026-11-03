defmodule BoxTurtle.Schema.CustomFiltersTest do
  @moduledoc """
  Custom filter modules, using the reference implementations in test/support/examples/schema.ex.
  """
  use BoxTurtle.DataCase

  import Ecto.Query, only: [where: 3]

  alias BoxTurtle.Examples
  alias BoxTurtle.Examples.Post.Query, as: Posts

  defp titles(posts), do: posts |> Enum.map(& &1.title) |> Enum.sort()

  setup do
    ann = author_fixture(%{name: "Ann"})
    bob = author_fixture(%{name: "Bob"})

    for {title, status, likes, author} <- [
          {"Elixir tips", "published", 10, ann},
          {"Ecto deep dive", "draft", 3, ann},
          {"100% coverage", "published", 7, bob},
          {"Unattributed", "archived", 1, nil}
        ] do
      post_fixture(%{title: title, status: status, likes: likes, author_id: author && author.id})
    end

    %{ann: ann, bob: bob}
  end

  describe "open filter modules (use BoxTurtle.Schema.Filters)" do
    test "a named filter" do
      assert Posts.list!(filters: [min_likes: 7]) |> titles() == ["100% coverage", "Elixir tips"]
    end

    test "custom and plain filters combine in any order" do
      expected = ["Elixir tips"]

      assert Posts.list!(filters: [min_likes: 5, author_id: author_id("Ann")]) |> titles() ==
               expected

      assert Posts.list!(filters: [author_id: author_id("Ann"), min_likes: 5]) |> titles() ==
               expected
    end

    test "several custom filters, including the same one twice" do
      assert Posts.list!(filters: [min_likes: 2, search: "tips", published: true]) |> titles() ==
               [
                 "Elixir tips"
               ]

      # Both apply, so the stricter one decides.
      assert Posts.list!(filters: [min_likes: 2, min_likes: 8]) |> titles() == ["Elixir tips"]
    end

    test "search escapes LIKE wildcards in the term" do
      assert Posts.list!(filters: [search: "100%"]) |> titles() == ["100% coverage"]
      # An unescaped "%" would match every title.
      assert Posts.list!(filters: [search: "%"]) |> titles() == ["100% coverage"]
      assert Posts.list!(filters: [search: "_"]) == []
    end

    test "a custom clause can override a real column for specific values" do
      # status: "any" is handled by the custom clause...
      assert Posts.count!(filters: [status: "any"]) == 4
      # ...other statuses fall through to the default equality filter.
      assert Posts.list!(filters: [status: "draft"]) |> titles() == ["Ecto deep dive"]

      assert Posts.list!(filters: [status: ["draft", "archived"]]) |> titles() == [
               "Ecto deep dive",
               "Unattributed"
             ]
    end

    test "a convenience flag expands to other filters" do
      assert Posts.list!(filters: [published: true]) |> titles() == [
               "100% coverage",
               "Elixir tips"
             ]

      assert Posts.list!(filters: [published: false]) |> titles() == [
               "Ecto deep dive",
               "Unattributed"
             ]
    end

    test "a filter on a joined association" do
      assert Posts.list!(filters: [author_name: "Bob"]) |> titles() == ["100% coverage"]

      assert Posts.list!(filters: [author_name: "Ann", published: true]) |> titles() == [
               "Elixir tips"
             ]
    end

    test "a joined filter works alongside join preloads" do
      assert [%Post{title: "100% coverage", author: %Author{name: "Bob"}}] =
               Posts.list!(filters: [author_name: "Bob"], preloads: [:author])
    end

    test "string keys reach custom clauses as given, so only plain column names work as strings" do
      assert Posts.list!(filters: [{"status", "draft"}]) |> titles() == ["Ecto deep dive"]
      # "min_likes" is not matched by the atom clause, so the default looks for a column.
      assert_raise Ecto.QueryError, fn -> Posts.list!(filters: [{"min_likes", 5}]) end
    end
  end

  describe "custom filters in every Query function" do
    test "count and grouped count" do
      assert Posts.count!(filters: [min_likes: 5]) == 2

      counts =
        Posts.count!(filters: [min_likes: 2], group_by: [:status]) |> Enum.sort_by(& &1.status)

      assert counts == [%{status: "draft", count: 1}, %{status: "published", count: 2}]
    end

    test "get! and get" do
      assert %Post{title: "Elixir tips"} =
               Posts.get!(%{title: "Elixir tips"}, filters: [published: true])

      assert {:error, :not_found} =
               Posts.get(%{title: "Elixir tips"}, filters: [published: false])
    end

    test "query! returns a query that can be composed further" do
      query = Posts.query!(filters: [author_name: "Ann"])
      assert query |> where([p], p.likes > 5) |> Repo.all() |> titles() == ["Elixir tips"]
    end

    test "paging applies after filtering" do
      page = Posts.list!(filters: [min_likes: 2], sort: [:popularity], page: [number: 2, size: 2])
      assert Enum.map(page, & &1.title) == ["Ecto deep dive"]
    end

    test "delegated scopes use this module's filters", %{ann: ann} do
      # ByAuthor.list_by/2 runs with Examples.Post.Query's settings, including its filter module.
      assert {:ok, posts} = Posts.list_by(ann, filters: [min_likes: 5])
      assert titles(posts) == ["Elixir tips"]
      assert {:ok, 1} = Posts.count_by(ann, filters: [search: "Ecto"])
    end
  end

  describe "filtering parents by their children" do
    test "a subquery keeps each parent once" do
      authors =
        Examples.Author.Query.list!(filters: [has_post_with_status: "published"], sort: [:name])

      assert Enum.map(authors, & &1.name) == ["Ann", "Bob"]

      assert Examples.Author.Query.count!(filters: [has_post_with_status: "draft"]) == 1
    end

    test "combined with a to-many preload" do
      [ann] =
        Examples.Author.Query.list!(filters: [has_post_with_status: "draft"], preloads: [:posts])

      assert length(ann.posts) == 2
    end
  end

  describe "closed filter modules (implementing the behaviour directly)" do
    alias BoxTurtle.Examples.ParamPost.Query, as: ParamPosts

    test "accept the listed string-keyed params" do
      params = %{"status" => "published", "min_likes" => "8"}
      assert ParamPosts.list!(filters: Map.to_list(params)) |> titles() == ["Elixir tips"]
    end

    test "reject anything else, including real columns that aren't listed" do
      assert_raise ArgumentError, ~r/unsupported post filter "title"/, fn ->
        ParamPosts.list!(filters: [{"title", "Elixir tips"}])
      end

      assert_raise ArgumentError, ~r/unsupported post filter "status"/, fn ->
        ParamPosts.list!(filters: [{"status", "deleted"}])
      end

      assert_raise ArgumentError, ~r/min_likes must be an integer/, fn ->
        ParamPosts.list!(filters: [{"min_likes", "lots"}])
      end
    end

    test "there is no fall-through, even for atom keys" do
      assert_raise ArgumentError, fn -> ParamPosts.list!(filters: [status: "draft"]) end
    end
  end

  defp author_id(name), do: Repo.get_by!(Author, name: name).id
end
