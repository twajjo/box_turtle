defmodule BoxTurtle.Schema.Change do
  @moduledoc """
  Generates the write functions of `BoxTurtle.Schema.Change.API` for an Ecto schema.

  Attribute maps go through the schema's changeset functions, so the schema must define them:
  `changeset/2` by default, for both inserts and updates.

      defmodule MyApp.Blog.Post do
        use Ecto.Schema
        import Ecto.Changeset

        schema "posts" do
          field :title, :string
          timestamps()
        end

        def changeset(post, attrs), do: post |> cast(attrs, [:title]) |> validate_required([:title])
      end

      # delete/1 by primary key looks rows up through the sibling Query module.
      defmodule MyApp.Blog.Post.Query do
        use BoxTurtle.Schema.Query, repo: MyApp.Repo
      end

      defmodule MyApp.Blog.Post.Change do
        use BoxTurtle.Schema.Change, repo: MyApp.Repo
      end

      alias MyApp.Blog.Post

      {:ok, post} = Post.Change.create(%{title: "Hello"})
      {:error, %Ecto.Changeset{}} = Post.Change.create(%{title: nil})
      {:ok, post} = Post.Change.update(post, %{title: "Hello again"})
      {:ok, _deleted} = Post.Change.delete(post.id)
      {:error, :not_found} = Post.Change.delete(post.id)

  ## Options

    * `:repo` - the `Ecto.Repo` to write to. Required.
    * `:schema` - the schema module. Defaults to the parent of the using module (`MyApp.Blog.Post` above).
    * `:query` - the `BoxTurtle.Schema.Query` module used to look rows up by key in `delete/1`.
      Defaults to `<schema>.Query`.
    * `:create_changeset` - name of the schema's `fun(struct, attrs)` used by `create`. Defaults to `:changeset`.
    * `:update_changeset` - name of the schema's `fun(struct, attrs)` used by `update`. Defaults to `:changeset`.
    * `:create_opts` - options passed to `c:Ecto.Repo.insert/2`, e.g. `[on_conflict: :nothing]`.
  """

  alias BoxTurtle.Schema.Query

  defmacro __using__(options) do
    env = __CALLER__

    options =
      Keyword.validate!(options, [
        :repo,
        :schema,
        :query,
        create_changeset: :changeset,
        update_changeset: :changeset,
        create_opts: []
      ])

    repo =
      Macro.expand(
        options[:repo] ||
          raise(ArgumentError, "use BoxTurtle.Schema.Change requires the :repo option"),
        env
      )

    schema =
      Macro.expand(options[:schema] || Query.parent_module(env.module), env)

    query = Macro.expand(options[:query] || Module.concat(schema, "Query"), env)
    create_changeset = options[:create_changeset]
    update_changeset = options[:update_changeset]
    create_opts = options[:create_opts]

    quote do
      @behaviour BoxTurtle.Schema.Change.API

      @impl BoxTurtle.Schema.Change.API
      def create(%Ecto.Changeset{} = changeset),
        do: unquote(repo).insert(changeset, unquote(create_opts))

      def create(%{} = attrs), do: attrs |> new_changeset() |> create()

      @impl BoxTurtle.Schema.Change.API
      def create!(%Ecto.Changeset{} = changeset),
        do: unquote(repo).insert!(changeset, unquote(create_opts))

      def create!(%{} = attrs), do: attrs |> new_changeset() |> create!()

      @impl BoxTurtle.Schema.Change.API
      def update(%Ecto.Changeset{} = changeset), do: unquote(repo).update(changeset)

      @impl BoxTurtle.Schema.Change.API
      def update(%unquote(schema){} = item, %{} = changes),
        do: item |> update_changeset(changes) |> update()

      @impl BoxTurtle.Schema.Change.API
      def update!(%Ecto.Changeset{} = changeset), do: unquote(repo).update!(changeset)

      @impl BoxTurtle.Schema.Change.API
      def update!(%unquote(schema){} = item, %{} = changes),
        do: item |> update_changeset(changes) |> update!()

      @impl BoxTurtle.Schema.Change.API
      def delete(%Ecto.Changeset{} = changeset), do: unquote(repo).delete(changeset)
      def delete(%unquote(schema){} = item), do: unquote(repo).delete(item)

      def delete(key) do
        with {:ok, item} <- unquote(query).get(key), do: delete(item)
      end

      @impl BoxTurtle.Schema.Change.API
      def delete!(%Ecto.Changeset{} = changeset), do: unquote(repo).delete!(changeset)
      def delete!(%unquote(schema){} = item), do: unquote(repo).delete!(item)

      def delete!(key) do
        case unquote(query).get!(key) do
          nil -> raise Ecto.NoResultsError, queryable: unquote(schema)
          item -> delete!(item)
        end
      end

      defp new_changeset(attrs) do
        apply(unquote(schema), unquote(create_changeset), [
          struct(unquote(schema)),
          changeable_attrs(attrs)
        ])
      end

      defp update_changeset(item, changes) do
        apply(unquote(schema), unquote(update_changeset), [item, changeable_attrs(changes)])
      end

      # A struct given as attributes is turned into a map, minus its unloaded associations.
      defp changeable_attrs(attrs) when is_struct(attrs) do
        attrs
        |> Map.from_struct()
        |> Map.reject(fn {_key, value} -> match?(%Ecto.Association.NotLoaded{}, value) end)
      end

      defp changeable_attrs(attrs), do: attrs

      defoverridable BoxTurtle.Schema.Change.API
    end
  end
end
