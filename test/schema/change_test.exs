defmodule BoxTurtle.Schema.ChangeTest do
  use BoxTurtle.DataCase

  alias BoxTurtle.Test.Post

  describe "create/1 and create!/1" do
    test "insert from a map" do
      assert {:ok, %Post{id: id, title: "Hello"}} = Post.Change.create(%{title: "Hello"})
      assert Post.Query.get!(id)
    end

    test "insert from a changeset" do
      changeset = Post.changeset(%Post{}, %{title: "From changeset"})
      assert %Post{title: "From changeset"} = Post.Change.create!(changeset)
    end

    test "insert from a struct, ignoring unloaded associations" do
      assert {:ok, %Post{title: "Struct"}} = Post.Change.create(%Post{title: "Struct"})
    end

    test "invalid attributes" do
      assert {:error, changeset} = Post.Change.create(%{})
      assert %{title: ["can't be blank"]} = errors_on(changeset)
      assert_raise Ecto.InvalidChangesetError, fn -> Post.Change.create!(%{}) end
    end
  end

  describe "update/2 and update!/2" do
    test "use the configured update changeset" do
      post = post_fixture()

      assert {:ok, %Post{status: "published", title: "A post"}} =
               Post.Change.update(post, %{status: "published", title: "ignored"})

      assert %Post{status: "archived"} = Post.Change.update!(post, %{status: "archived"})
    end

    test "invalid changes" do
      post = post_fixture()
      assert {:error, changeset} = Post.Change.update(post, %{status: "bogus"})
      assert %{status: ["is invalid"]} = errors_on(changeset)
      assert_raise Ecto.InvalidChangesetError, fn -> Post.Change.update!(post, %{status: "bogus"}) end
    end

    test "update/1 takes a changeset" do
      post = post_fixture()
      assert {:ok, %Post{likes: 3}} = post |> Ecto.Changeset.change(likes: 3) |> Post.Change.update()
    end
  end

  describe "delete/1 and delete!/1" do
    test "by struct, changeset or id" do
      p1 = post_fixture()
      p2 = post_fixture()
      p3 = post_fixture()

      assert {:ok, _} = Post.Change.delete(p1)
      assert {:ok, _} = p2 |> Ecto.Changeset.change() |> Post.Change.delete()
      assert %Post{} = Post.Change.delete!(p3.id)
      assert Post.Query.count!() == 0
    end

    test "missing rows" do
      assert {:error, :not_found} = Post.Change.delete(-1)
      assert_raise Ecto.NoResultsError, fn -> Post.Change.delete!(-1) end
    end
  end

  test ":repo is required" do
    assert_raise ArgumentError, ~r/requires the :repo option/, fn ->
      Code.compile_string("defmodule BadChange.Change do use BoxTurtle.Schema.Change end")
    end
  end
end
