defmodule BoxTurtle.Test.Options.PostWithAuthor do
  use BoxTurtle.Schema.Query,
    repo: BoxTurtle.Test.Repo,
    schema: BoxTurtle.Test.Post,
    default_preloads: [:author]
end

# Reports the :row_module it receives, to check :ownership_scope.
defmodule BoxTurtle.Test.Options.RowModuleProbe do
  use BoxTurtle.Schema.Query, repo: BoxTurtle.Test.Repo, schema: BoxTurtle.Test.Author

  extend :list_by do
    def list_by(%BoxTurtle.Test.Author{}, opts), do: {:ok, Keyword.fetch!(opts, :row_module)}
  end
end

defmodule BoxTurtle.Test.Options.Scoped do
  use BoxTurtle.Schema.Query,
    repo: BoxTurtle.Test.Repo,
    schema: BoxTurtle.Test.Post,
    delegates: [{BoxTurtle.Test.Options.RowModuleProbe, %BoxTurtle.Test.Author{}}],
    ownership_scope: BoxTurtle.Test.Author

  delegate([:list_by, :list_by!, :count_by!, :query_by!])

  extend :get_by do
    def get_by(title, opts) when is_binary(title) do
      case get!(%{title: title}, opts) do
        nil -> {:error, :not_found}
        post -> {:ok, post}
      end
    end
  end
end

defmodule BoxTurtle.Test.Options.Unscoped do
  use BoxTurtle.Schema.Query,
    repo: BoxTurtle.Test.Repo,
    schema: BoxTurtle.Test.Post,
    delegates: [{BoxTurtle.Test.Options.RowModuleProbe, %BoxTurtle.Test.Author{}}]

  delegate(:list_by)
end

# Lives outside the schema's namespace, so :schema and :query must be explicit.
defmodule BoxTurtle.Test.Options.Writer do
  use BoxTurtle.Schema.Change,
    repo: BoxTurtle.Test.Repo,
    schema: BoxTurtle.Test.Code,
    query: BoxTurtle.Test.Code.Query,
    create_opts: [on_conflict: :nothing]
end

defmodule BoxTurtle.Schema.OptionsTest do
  use BoxTurtle.DataCase

  alias BoxTurtle.Test.{Code, Options}

  defp titles(posts), do: Enum.map(posts, & &1.title)

  defp posts_fixture do
    author = author_fixture()

    for {title, status, likes, author_id} <- [
          {"a", "draft", 5, author.id},
          {"b", "published", 5, nil},
          {"c", "published", 9, author.id}
        ] do
      post_fixture(%{title: title, status: status, likes: likes, author_id: author_id})
    end

    author
  end

  describe "filters" do
    setup do
      %{author: posts_fixture()}
    end

    test "an empty list matches nothing" do
      assert Post.Query.list!(filters: [status: []]) == []
      assert Post.Query.count!(filters: [status: []]) == 0
    end

    test "several filters are combined with AND" do
      assert Post.Query.list!(filters: [status: "published", likes: 9]) |> titles() == ~w(c)
      assert Post.Query.list!(filters: [status: "published", likes: 1]) == []
    end

    test "a column the schema doesn't have raises when the query runs" do
      assert_raise Ecto.QueryError, fn -> Post.Query.list!(filters: [no_such_column: 1]) end
    end

    test "filters apply to grouped counts", %{author: author} do
      counts = Post.Query.count!(group_by: [:status], filters: [author_id: author.id])

      assert Enum.sort_by(counts, & &1.status) == [
               %{status: "draft", count: 1},
               %{status: "published", count: 1}
             ]
    end

    test "scoped queries merge call-time filters with the scope's filter", %{author: author} do
      assert {:ok, [%Post{title: "c"}]} =
               Post.Query.list_by(author, filters: [status: "published"])

      assert {:ok, 0} = Post.Query.count_by(author, filters: [title: "b"])
    end
  end

  describe "sort" do
    test "custom sorts combine with plain columns" do
      for {title, likes} <- [{"y", 3}, {"x", 3}, {"z", 7}],
          do: post_fixture(%{title: title, likes: likes})

      # :popularity is desc likes then asc id; the trailing :title never decides here.
      assert Post.Query.list!(sort: [:popularity, :title]) |> titles() == ~w(z y x)
      assert Post.Query.list!(sort: [desc: :likes, asc: :title]) |> titles() == ~w(z x y)
    end
  end

  describe "group_by" do
    setup do
      posts_fixture()
      :ok
    end

    test "several columns" do
      counts =
        Post.Query.count!(group_by: [:status, :likes]) |> Enum.sort_by(&{&1.status, &1.likes})

      assert counts == [
               %{status: "draft", likes: 5, count: 1},
               %{status: "published", likes: 5, count: 1},
               %{status: "published", likes: 9, count: 1}
             ]
    end

    test "string column names, which must already exist as atoms" do
      assert Post.Query.count!(group_by: ["status"]) |> length() == 2
      assert_raise ArgumentError, fn -> Post.Query.count!(group_by: ["no_such_column_zz9"]) end
    end
  end

  describe "default_preloads and ignore_defaults" do
    test "default preloads apply unless overridden or ignored" do
      author = author_fixture()
      post_fixture(%{author_id: author.id})

      assert [%Post{author: %Author{}}] = Options.PostWithAuthor.list!()
      assert %Post{author: %Author{}} = Options.PostWithAuthor.get!(%{title: "A post"})

      assert [%Post{author: %Ecto.Association.NotLoaded{}}] =
               Options.PostWithAuthor.list!(preloads: [])

      assert [%Post{author: %Ecto.Association.NotLoaded{}}] =
               Options.PostWithAuthor.list!(ignore_defaults: true)
    end
  end

  describe "query_opts" do
    test "are passed to Repo.all/2" do
      post_fixture()
      test_pid = self()
      handler = "query-opts-#{inspect(test_pid)}"

      :telemetry.attach(
        handler,
        [:box_turtle, :test, :repo, :query],
        fn _event, _measurements, meta, _config -> send(test_pid, {:options, meta.options}) end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler) end)

      Post.Query.list!(query_opts: [telemetry_options: [marker: :seen]])
      assert_received {:options, [marker: :seen]}
    end
  end

  describe "primary_key" do
    test "get, the default sort and delete use the configured key" do
      {:ok, _} = Code.Change.create(%{code: "b2", label: "second"})
      {:ok, _} = Code.Change.create(%{code: "a1", label: "first"})

      assert {:ok, %Code{label: "first"}} = Code.Query.get("A1")
      assert Code.Query.list!() |> Enum.map(& &1.code) == ~w(A1 B2)
      assert {:ok, %Code{code: "B2"}} = Code.Change.delete("B2")
      assert {:error, :not_found} = Code.Change.delete("B2")
    end
  end

  describe "Change options" do
    test ":create_changeset is used for inserts only" do
      {:ok, code} = Code.Change.create(%{code: "abc"})
      assert code.code == "ABC"

      assert {:ok, %Code{label: "relabelled", code: "ABC"}} =
               Code.Change.update(code, %{label: "relabelled"})
    end

    test "explicit :schema, :query and :create_opts" do
      assert {:ok, %Code{code: "x"}} = Options.Writer.create(%{code: "x", label: "one"})
      # on_conflict: :nothing makes the duplicate a no-op instead of a constraint error.
      assert {:ok, _} = Options.Writer.create(%{code: "x", label: "two"})
      assert {:ok, %Code{label: "one"}} = Code.Query.get("x")

      assert {:ok, %Code{code: "x"}} = Options.Writer.delete("x")
      assert {:error, :not_found} = Options.Writer.delete("x")
    end

    test "without :create_opts a duplicate key raises" do
      {:ok, _} = Code.Change.create(%{code: "dup"})
      assert_raise Ecto.ConstraintError, fn -> Code.Change.create(%{code: "dup"}) end
    end
  end

  describe "extensions" do
    test "nil patterns fall back to the unscoped functions for every variant" do
      posts_fixture()

      assert Options.Scoped.list_by!(nil) |> length() == 3
      assert Options.Scoped.count_by!(nil, filters: [status: "published"]) == 2
      assert %Ecto.Query{} = query = Options.Scoped.query_by!(nil, filters: [title: "a"])
      assert Repo.all(query) |> titles() == ~w(a)
    end

    test "patterns no clause matches raise FunctionClauseError" do
      assert_raise FunctionClauseError, fn -> Options.Scoped.list_by!(%Post{}) end
      assert_raise FunctionClauseError, fn -> Options.Scoped.get_by(:not_a_title) end
    end

    test "extend/2 can define the tuple-returning get_by" do
      post_fixture(%{title: "Findable"})
      assert {:ok, %Post{title: "Findable"}} = Options.Scoped.get_by("Findable")
      assert {:error, :not_found} = Options.Scoped.get_by("Missing")
    end

    test ":ownership_scope is passed to delegates as :row_module, defaulting to the delegate" do
      author = author_fixture()
      assert Options.Scoped.list_by(author) == {:ok, Author}
      assert Options.Unscoped.list_by(author) == {:ok, Options.RowModuleProbe}
    end

    test "delegate/1 skips delegates that don't implement the function" do
      # RowModuleProbe has no list_by!/2, so only the nil clause exists.
      refute function_exported?(Options.RowModuleProbe, :list_by!, 2)
      assert_raise FunctionClauseError, fn -> Options.Scoped.list_by!(author_fixture()) end
    end
  end
end
