defmodule BoxTurtle.Schema.BuildingBlocksTest do
  use ExUnit.Case, async: true

  import Ecto.Query

  alias BoxTurtle.Schema.Ecto.Ksuid
  alias BoxTurtle.Schema.{Filters, Pagination, Sort}
  alias BoxTurtle.Test.Post

  describe "Sort.sort_by/2" do
    test "builds order_by clauses" do
      query = Sort.sort_by(Post, [:title, desc_nulls_last: :likes, asc: [:status, :id]])
      assert inspect(query) =~ "order_by: [asc: p0.title], order_by: [desc_nulls_last: p0.likes]"
      assert inspect(query) =~ "order_by: [asc: p0.status], order_by: [asc: p0.id]"
    end

    test "rejects invalid specifications" do
      assert_raise ArgumentError, ~r/invalid sort specification: {:sideways, :id}/, fn ->
        Sort.sort_by(Post, sideways: :id)
      end

      assert_raise ArgumentError, fn -> Sort.sort_by(Post, ["title"]) end
    end
  end

  describe "Filters.filter_with/2" do
    test "an empty list leaves the query unchanged" do
      assert Filters.filter_with(Post, []) == Post
    end

    test "unknown string columns are not turned into atoms" do
      assert_raise ArgumentError, fn -> Filters.filter_with(Post, [{"no_such_column_zz9", 1}]) end
    end
  end

  describe "Pagination.page/3" do
    test "nil leaves the query unchanged" do
      assert Pagination.page(Post, nil) == Post
    end

    test "limit and offset" do
      %Ecto.Query{limit: limit, offset: offset} =
        Pagination.page(from(p in Post), number: 3, size: 10)

      assert limit.params == [{10, :integer}]
      assert offset.params == [{20, :integer}]
    end

    test "default size" do
      %Ecto.Query{limit: limit} = Pagination.page(from(p in Post), 1)
      assert limit.params == [{Pagination.default_page_size(), :integer}]
    end
  end

  describe "Ksuid" do
    test "casts valid KSUIDs only" do
      ksuid = Ksuid.autogenerate()
      assert {:ok, ^ksuid} = Ksuid.cast(ksuid)
      assert :error = Ksuid.cast("too-short")
      assert :error = Ksuid.cast(String.duplicate("!", 27))
      assert :error = Ksuid.cast(42)
    end

    test "loads and dumps strings" do
      assert {:ok, "x"} = Ksuid.load("x")
      assert {:ok, "x"} = Ksuid.dump("x")
      assert :error = Ksuid.dump(1)
    end
  end
end
