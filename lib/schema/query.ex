defmodule BoxTurtle.Schema.Query do
  @moduledoc """
  Generates the standard read functions of `BoxTurtle.Schema.Query.API` for an Ecto schema.

  Given an Ecto schema `MyApp.Blog.Post` (with `title`, `status`, timestamps, and
  `belongs_to :author, MyApp.Blog.Author`), define a sibling module:

      defmodule MyApp.Blog.Post.Query do
        use BoxTurtle.Schema.Query,
          repo: MyApp.Repo,
          default_sort: [desc: :inserted_at, desc: :id],
          default_preloads: [:author]
      end

  and call it from your context:

      defmodule MyApp.Blog do
        alias MyApp.Blog.Post

        # Second page of published posts, newest first, each with its author (one query).
        def published_posts(page), do: Post.Query.list!(filters: [status: "published"], page: page)

        # [%{status: "draft", count: 3}, %{status: "published", count: 12}]
        def post_counts_by_status, do: Post.Query.count!(group_by: [:status])

        # {:ok, %Post{}} or {:error, :not_found}
        def fetch_post(id), do: Post.Query.get(id)
      end

  See `BoxTurtle.Schema.Query.API` for the generated functions and their call-time options, and the
  Schema guide for a walkthrough.

  ## Options

    * `:repo` - the `Ecto.Repo` to query. Required.
    * `:schema` - the schema module. Defaults to the parent of the using module (`MyApp.Blog.Post` above).
    * `:primary_key` - defaults to `:id`.
    * `:default_sort` - sort applied to lists unless overridden. Defaults to `[primary_key]`.
    * `:default_preloads` - associations to preload. Defaults to `[]`.
    * `:default_distinct` - columns for `DISTINCT ON` (PostgreSQL only: with other adapters the module
      fails to compile). Defaults to `[]`.
    * `:filter_module` - a `BoxTurtle.Schema.Filters.API` implementation. Defaults to `BoxTurtle.Schema.Filters`.
    * `:sorting_module` - a `BoxTurtle.Schema.Sort.API` implementation. Defaults to `BoxTurtle.Schema.Sort`.
    * `:page_size` - rows per page when `:page` is a number. Defaults to 40.
    * `:delegates` - `[{DelegateModule, %Pattern{}}]`, see `delegate/1`.
    * `:ownership_scope` - module passed to delegates as `:row_module`. Defaults to each delegate module.

  ## Extensions

  `extend/2` and `delegate/1` generate the optional `*_by(pattern, opts \\\\ [])` functions. Each one gets:

    1. a clause per `:delegates` entry whose module implements the function, forwarding `%Pattern{}` arguments
       to it with this module's settings injected into the options, so the delegate queries this schema;
    2. for `count_by`, `list_by` and `query_by!` (and their variants), a `nil` clause that falls back to the
       unscoped `count`, `list` or `query!`;
    3. with `extend/2`, your own clauses.

  A delegate holds a scope shared by several schemas, here "rows belonging to an author". It is an
  ordinary Query module; when called through a delegating module, `list/1` and `count/1` run
  against the delegating module's schema:

      defmodule MyApp.Blog.ByAuthor do
        use BoxTurtle.Schema.Query, repo: MyApp.Repo, schema: MyApp.Blog.Author

        extend :list_by do
          def list_by(%MyApp.Blog.Author{id: id}, opts), do: list(add_filters(opts, author_id: id))
        end

        extend :count_by do
          def count_by(%MyApp.Blog.Author{id: id}, opts), do: count(add_filters(opts, author_id: id))
        end
      end

      defmodule MyApp.Blog.Post.Query do
        use BoxTurtle.Schema.Query,
          repo: MyApp.Repo,
          delegates: [{MyApp.Blog.ByAuthor, %MyApp.Blog.Author{}}]

        # list_by/2 and count_by/2 for %Author{} patterns (and nil), from the delegate.
        delegate [:list_by, :count_by]

        # Your own clauses (posts here have a :slug column).
        extend :get_by! do
          def get_by!(slug, opts) when is_binary(slug), do: get!(%{slug: slug}, opts)
        end
      end

      author = MyApp.Repo.get!(MyApp.Blog.Author, author_id)
      {:ok, posts} = MyApp.Blog.Post.Query.list_by(author, filters: [status: "published"])
      {:ok, all_posts} = MyApp.Blog.Post.Query.list_by(nil)
      post = MyApp.Blog.Post.Query.get_by!("hello-world")
  """

  alias BoxTurtle.Schema.Pagination
  alias BoxTurtle.Schema.Query.Helpers

  @extensions %{
    count_by: :count,
    count_by!: :count!,
    get_by: nil,
    get_by!: nil,
    list_by: :list,
    list_by!: :list!,
    query_by!: :query!
  }

  defmacro __using__(options) do
    env = __CALLER__

    options =
      Keyword.validate!(options, [
        :repo,
        :schema,
        :default_sort,
        delegates: [],
        ownership_scope: nil,
        default_preloads: [],
        default_distinct: [],
        filter_module: BoxTurtle.Schema.Filters,
        sorting_module: BoxTurtle.Schema.Sort,
        primary_key: :id,
        page_size: Pagination.default_page_size()
      ])

    repo =
      options[:repo] ||
        raise ArgumentError, "use BoxTurtle.Schema.Query requires the :repo option"

    primary_key = options[:primary_key]

    settings = [
      repo: expand(repo, env),
      schema: expand(options[:schema] || parent_module(env.module), env),
      primary_key: primary_key,
      default_sort: options[:default_sort] || [primary_key],
      default_preloads: options[:default_preloads],
      default_distinct: options[:default_distinct],
      filter_module: expand(options[:filter_module], env),
      sorting_module: expand(options[:sorting_module], env),
      page_size: options[:page_size]
    ]

    check_default_distinct!(settings[:default_distinct], settings[:repo])

    # Read back by extend/2 and delegate/1 while the using module compiles.
    Module.put_attribute(env.module, :__box_turtle_query__, %{
      scope: expand(options[:ownership_scope], env),
      delegates: options[:delegates] |> List.wrap() |> Enum.map(&normalize_delegate(&1, env))
    })

    quote do
      use BoxTurtle.Schema.Query.Options, unquote(settings)

      import Ecto.Query
      import BoxTurtle.Schema.Query.Helpers
      import BoxTurtle.Schema.Query, only: [extend: 2, delegate: 1]

      @behaviour BoxTurtle.Schema.Query.API

      @impl BoxTurtle.Schema.Query.API
      def count(opts \\ []), do: {:ok, count!(opts)}

      @impl BoxTurtle.Schema.Query.API
      def count!(opts \\ []) do
        opts
        |> schema()
        |> pipe_query!(Keyword.put(opts, :aggregate, :count))
        |> aggregate_result!(:count, grouping(opts), repo(opts), opts)
      end

      @impl BoxTurtle.Schema.Query.API
      def get(key, opts \\ []) do
        case get!(key, opts) do
          nil -> {:error, :not_found}
          item -> {:ok, item}
        end
      end

      @impl BoxTurtle.Schema.Query.API
      def get!(key, opts \\ [])
      def get!(nil, _opts), do: nil

      def get!(key, opts) do
        opts
        |> schema()
        |> build_query!(filter_module(opts), opts)
        |> where_key(key, primary_key(opts))
        |> preloads(joining(default_preloads(opts), opts), primary_key(opts))
        |> repo(opts).one()
      end

      @impl BoxTurtle.Schema.Query.API
      def list(opts \\ []), do: {:ok, list!(opts)}

      @impl BoxTurtle.Schema.Query.API
      def list!(opts \\ []) do
        opts
        |> query!()
        |> repo(opts).all(Keyword.get(opts, :query_opts, []))
      end

      @impl BoxTurtle.Schema.Query.API
      def pipe_query!(query, opts \\ []) do
        if aggregate?(opts) do
          opts = Keyword.put(opts, :distinct, aggregate_distinction(opts, default_distinct(opts)))
          aggregate_query!(query, aggregation(opts), filter_module(opts), opts)
        else
          query
          |> build_listings!(sorting_module(opts), default_sort(opts), opts, page_size(opts))
          |> build_query!(filter_module(opts), opts)
          |> unique(opts |> query_distinction(default_distinct(opts)) |> distinct_on!(repo(opts)))
          |> preloads(joining(default_preloads(opts), opts), primary_key(opts))
        end
      end

      @impl BoxTurtle.Schema.Query.API
      def query!(opts \\ []), do: opts |> schema() |> pipe_query!(opts)

      defoverridable count: 0,
                     count: 1,
                     count!: 0,
                     count!: 1,
                     get: 1,
                     get: 2,
                     get!: 1,
                     get!: 2,
                     list: 0,
                     list: 1,
                     list!: 0,
                     list!: 1,
                     pipe_query!: 1,
                     pipe_query!: 2,
                     query!: 0,
                     query!: 1
    end
  end

  @doc """
  Defines the extension function `extension` (one of `#{inspect(Map.keys(@extensions))}`) with its delegate
  and `nil` clauses, followed by the clauses in `block`.
  """
  defmacro extend(extension, do: block) do
    {:__block__, [], extension_clauses(extension, __CALLER__) ++ [block]}
  end

  @doc """
  Defines each of the given extension functions with only their delegate and `nil` clauses.
  """
  defmacro delegate(extensions) do
    clauses = extensions |> List.wrap() |> Enum.flat_map(&extension_clauses(&1, __CALLER__))
    {:__block__, [], clauses}
  end

  defp extension_clauses(extension, env) do
    if !Map.has_key?(@extensions, extension) do
      raise ArgumentError,
            "unknown Query extension #{inspect(extension)}, expected one of #{inspect(Map.keys(@extensions))}"
    end

    config =
      Module.get_attribute(env.module, :__box_turtle_query__) ||
        raise ArgumentError, "extend/2 and delegate/1 require `use BoxTurtle.Schema.Query` first"

    head =
      quote do
        @impl BoxTurtle.Schema.Query.API
        def unquote(extension)(pattern, opts \\ [])
      end

    [head] ++ nil_clause(extension) ++ delegate_clauses(extension, config)
  end

  defp nil_clause(extension) do
    case Map.fetch!(@extensions, extension) do
      nil ->
        []

      unscoped ->
        [
          quote do
            def unquote(extension)(nil, opts), do: unquote(unscoped)(opts)
          end
        ]
    end
  end

  # Only delegates that implement the extension get a clause.
  defp delegate_clauses(extension, %{delegates: delegates, scope: scope}) do
    for {delegate, pattern} <- delegates,
        delegate |> Code.ensure_compiled!() |> function_exported?(extension, 2) do
      quote do
        def unquote(extension)(%unquote(pattern){} = match, opts) do
          unquote(delegate).unquote(extension)(
            match,
            opts
            |> inject_query_options()
            |> Keyword.put(:row_module, unquote(scope || delegate))
          )
        end
      end
    end
  end

  # Accepts `{Delegate, %Pattern{}}` or `{Delegate, Pattern}`.
  defp normalize_delegate({delegate, {:%, _, [pattern, {:%{}, _, _}]}}, env),
    do: {expand(delegate, env), expand(pattern, env)}

  defp normalize_delegate({delegate, pattern}, env),
    do: {expand(delegate, env), expand(pattern, env)}

  defp normalize_delegate(other, _env) do
    raise ArgumentError,
          "invalid Query delegate #{Macro.to_string(other)}, expected {DelegateModule, %Pattern{}}"
  end

  defp expand(ast, env), do: Macro.expand(ast, env)

  # Catches a :default_distinct the repo can't run at compile time. This makes the using module
  # wait for the repo to compile, so it is only done when :default_distinct is set.
  defp check_default_distinct!(columns, repo) do
    case List.wrap(columns) do
      [] ->
        :ok

      columns ->
        Code.ensure_compiled!(repo)
        Helpers.distinct_on!(columns, repo)
        :ok
    end
  end

  @doc false
  def parent_module(module), do: module |> Module.split() |> Enum.drop(-1) |> Module.concat()
end
