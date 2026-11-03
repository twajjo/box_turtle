defmodule BoxTurtle.Schema.CustomSortTest do
  @moduledoc """
  Custom sort modules, using the reference implementations in test/support/examples/schema.ex.
  """
  use BoxTurtle.DataCase

  alias BoxTurtle.Examples.ParamPost.Query, as: ParamPosts
  alias BoxTurtle.Examples.Post.Query, as: Posts

  defp titles(posts), do: Enum.map(posts, & &1.title)

  setup do
    ann = author_fixture(%{name: "Ann"})
    bob = author_fixture(%{name: "Bob"})

    for {title, likes, author} <- [{"b", 5, bob}, {"a", 9, ann}, {"c", 5, ann}, {"d", 1, nil}] do
      post_fixture(%{title: title, likes: likes, author_id: author && author.id})
    end

    :ok
  end

  describe "open sort modules (use BoxTurtle.Schema.Sort)" do
    test "a named sort with a stable tie-breaker" do
      # b and c tie on likes; the primary key keeps them in insertion order.
      assert Posts.list!(sort: [:popularity]) |> titles() == ~w(a b c d)
    end

    test "named and plain sorts combine in any order" do
      assert Posts.list!(sort: [desc: :likes, desc: :title]) |> titles() == ~w(a c b d)
      assert Posts.list!(sort: [:title, :popularity]) |> titles() == ~w(a b c d)
    end

    test "a sort on a joined column, in either direction" do
      assert Posts.list!(sort: [{:asc_nulls_last, :author_name}, :title]) |> titles() ==
               ~w(a c b d)

      assert Posts.list!(sort: [{:desc_nulls_last, :author_name}, :title]) |> titles() ==
               ~w(b a c d)

      assert Posts.list!(sort: [:author_name, :title]) |> titles() |> Enum.take(-3) == ~w(a c b)
    end

    test "the sort and a filter share one join" do
      query = Posts.query!(sort: [:author_name], filters: [author_name: "Ann"])
      assert length(query.joins) == 1
      assert query |> Repo.all() |> titles() == ~w(a c)
    end

    test "custom sorts work with paging and preloads" do
      page = Posts.list!(sort: [:popularity], page: [number: 1, size: 2], preloads: [:author])
      assert [%Post{title: "a", author: %Author{name: "Ann"}}, %Post{title: "b"}] = page
    end

    test "unknown specs still raise" do
      assert_raise ArgumentError, ~r/invalid sort specification/, fn ->
        Posts.list!(sort: [{:up, :title}])
      end
    end
  end

  describe "closed sort modules (implementing the behaviour directly)" do
    test "a ?sort=-likes,title style parameter" do
      sort = String.split("-likes,title", ",")
      assert ParamPosts.list!(sort: sort) |> titles() == ~w(a b c d)
    end

    test "the default sort uses the module's own format" do
      assert ParamPosts.list!() |> titles() == ~w(b a c d)
    end

    test "columns that aren't listed are rejected" do
      assert_raise ArgumentError, ~r/unsupported post sort "status"/, fn ->
        ParamPosts.list!(sort: ["status"])
      end

      assert_raise ArgumentError, fn -> ParamPosts.list!(sort: [desc: :likes]) end
    end
  end
end
