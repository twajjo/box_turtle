defmodule BoxTurtle.Schema.Query do
  @moduledoc """
  A macro module for creating standard queries for id-based (string or integer) primary-key tables.

  See BoxTurtle.Schema.Query.API for complete details and callback/function documentation.

  Options
    repo: module(), REQUIRED
    schema: module(), REQUIRED
      The schema module to implement Query methods for.
    default_sort: [atom()] | [{:asc | :desc, atom()}], default: [{:asc, :id}]
      When given, specifies the default sort order for list queries.
    default_preloads: [atom()], default: []
      When given, preloads the specified associated tables.
    filter_module: module(), default: BoxTurtle.Schema.Filters
      When specified, provides a module that implements filter_with implementations
      of BoxTurtle.Schema.Filters.API.
    sorting_module: module(), default: BoxTurtle.Schema.Sort
      When specified, provides a module that implements sort_by functions
      specific to the schema and that implement BoxTurtle.Schema.Sort.API.
    primary_key: atom(), default: :id
  """

  defmacro __using__(options) do
    default_schema =
      __MODULE__
      |> Module.split()
      |> List.delete_at(-1)
      |> Module.concat()

    options = options
      |> Keyword.put_new(:schema, default_schema)

    # Process options
    delegates = options
#     |> IO.inspect(label: "Raw options")
      |> Keyword.get(:delegates, [])
    scope = options
      |> Keyword.get(:ownership_scope, nil)
    schema = options
      |> Keyword.get(:schema, nil)

    # Make module-wide global settings available to extension/delegation macros
    Module.register_attribute(__CALLER__.module, :__extensions_delegates, persist: true)
    Module.put_attribute(__CALLER__.module, :__extensions_delegates, delegates)
    Module.register_attribute(__CALLER__.module, :__extensions_schema, persist: true)
    Module.put_attribute(__CALLER__.module, :__extensions_schema, schema)
    Module.register_attribute(__CALLER__.module, :__extensions_ownership_scope, persist: true)
    Module.put_attribute(__CALLER__.module, :__extensions_ownership_scope, scope)

    # Inject header requirements for extension generation
    quote do
      use BoxTurtle.Debug.PipeDebug

      use BoxTurtle.Schema.Query.Options, unquote(options)
      import Ecto.Query
      import BoxTurtle.Schema.Pagination
      import BoxTurtle.Common.ReturnOkOr
      import BoxTurtle.Schema.Query
      import BoxTurtle.Schema.Query.Helpers

      @behaviour BoxTurtle.Schema.Query.API

      @supported_aggregates ~w(count)a

      @impl true
      def count(opts \\ []) do
        {:ok, count!(opts)}
      end

      @impl true
      def count!(opts \\ [])
      def count!(opts) do
        schema()
        |> pipe_query!(opts |> Keyword.put(:aggregate, :count))
        |> aggregate_result!(:count, grouping(opts), repo(opts), opts)
      end

      @impl true
      def get!(id, opts \\ [])
      def get!(nil, opts), do: nil
      def get!(%{} = id, opts) do
        schema()
        |> build_query!(filter_module(opts), opts)
        |> multi_key_where(id, opts)
        |> preloads(joining(default_preloads(opts), opts))
        |> debug("Before")
        |> repo(opts).one()
        |> debug("After")
      end
      def get!(id, opts) do
        schema()
        |> build_query!(filter_module(), opts)
        |> where([q], ^[{primary_key(), id}])
        |> preloads(joining(default_preloads(opts), opts))
        |> debug("Before")
        |> repo(opts).one()
        |> debug("After")
      end

      def multi_key_where(query, %{} = ids, _opts) do
        primary =
          ids
          |> Enum.map(fn id -> id end)

        query
        |> where([q], ^primary)
      end

      @impl true
      def get(id, opts \\ []) do
        get!(id, opts)
        |> return_ok_or(%{reason: "No #{schema() |> Module.split() |> List.last()} found", id: id})
      end

      @impl true
      def list(opts \\ []) do
        opts |> debug("list")
        {:ok, list!(opts)}
      end

      @impl true
      def list!(opts \\ []) do
        distinct = opts
          |> query_distinction(default_distinct(opts))

        query_opts = Keyword.get(opts, :query_opts, [])

        opts
        |> debug("list!")
        |> query!()
        |> unique(distinct)
        |> debug("Before")
        |> repo(opts).all(query_opts)
        |> debug("After")
      end

      @impl true
      def pipe_query!(query, opts \\ []) do
        if is_aggregate?(opts) do
          # Have to convert distinct option here-- default_distinct is not callable from Helper module.
          distinct = opts
            |> aggregate_distinction(default_distinct(opts))
          options = opts
            |> Keyword.put(:distinct, distinct)

          query
          |> aggregate_query!(aggregation(options), filter_module(options), options)
          |> debug("Aggregate query")
        else
          query
          |> build_listings!(sorting_module(opts), default_sort(opts), opts)
          |> build_query!(filter_module(opts), opts)
          |> preloads(joining(default_preloads(opts), opts))
        end
      end

      @impl true
      def query!(opts \\ []) do
        schema(opts)
        |> pipe_query!(opts)
      end

      @impl true
      def count_by(_pattern, _opts), do: {:error, :not_implemented}
      @impl true
      def get_by(_pattern, _opts), do: {:error, :not_implemented}
      @impl true
      def list_by(_pattern, _opts), do: {:error, :not_implemented}
      @impl true
      def count_by!(_pattern, _opts), do: 0
      @impl true
      def get_by!(_pattern, _opts), do: nil
      @impl true
      def list_by!(_pattern, _opts), do: []
      @impl true
      def query_by!(_pattern, _opts), do: nil

      defoverridable BoxTurtle.Schema.Query.API
    end
  end

  defmacro delegate(extensions \\ []) do
    # Get global macro options
    extensions
    |> List.wrap()
    |> Enum.reduce([], fn(extension, delegates) ->
      [
        quote do
          @impl true
          def unquote(extension)(pattern, opts \\ [])
        end
      ]
      # Delegate patterns to "common" modules that implement BoxTurtle.Schema.Query.API (e.g., BySite and/or ByClient)
      ++ get_delegates(extension, __CALLER__)
      ++ get_nil_handler(extension, __CALLER__)
      ++ delegates
    # ++ get_catchall_handler(extension, __CALLER__) ...?  Can also be in the block above ^^^^
    end)
  end

  defmacro extend(extension, do: block) do
    [
      quote do
        @impl true
        def unquote(extension)(pattern, opts \\ [])
      end
    ]
    # Delegate patterns to "common" modules that implement BoxTurtle.Schema.Query.API (e.g., BySite and/or ByClient)
    ++ get_delegates(extension, __CALLER__)
    ++ get_nil_handler(extension, __CALLER__)
    # Custom query extensions
    ++ [
      quote do
        unquote(block)
      end
    ]
    # ++ get_catchall_handler(extension, __CALLER__) ...?  Can also be in the block above ^^^^
  end

  defp get_nil_handler(extension, caller) do
    %{
      count_by: :count,
      count_by!: :count!,
      list_by: :list,
      list_by!: :list!
    }
    |> Enum.reduce([],
      fn
        {^extension, remap}, acc ->
          [
            quote do
              @impl true
              def unquote(extension)(nil, opts) do
                unquote(caller.module).unquote(remap)(opts)
              end
            end
          ] ++ acc
        {_, _}, acc -> [] ++ acc
      end
    )
  end

  defp get_delegates(extension, caller) do
    # Get the common options buried in the module when __using__ macro executed
    schema = Module.get_attribute(caller.module, :__extensions_schema)
      |> extract_schema(caller)
    scope = Module.get_attribute(caller.module, :__extensions_ownership_scope)
      |> extract_scope(caller)
#      |> IO.inspect(label: "#{caller.module}.#{extension} delegate ownership scope")

    # Get delegation modules and patterns to match.
    Module.get_attribute(caller.module, :__extensions_delegates)
    |> List.wrap()
    # |> IO.inspect(label: "starting delegates")  # Don't even think of PipeDebug before compiling!
    |> Enum.map(fn delegate ->
      case extract(delegate, scope, caller) do
        %{delegate: d_mod, scope: s_mod, pattern: pattern} = _delegate_params ->
#          delegate_params |> IO.inspect(label: "#{caller.module}.#{extension}: Delegation params")
          quote do
            @impl true
            def unquote(extension)(%unquote(pattern){} = match, opts) do
              unquote(d_mod).unquote(extension)(match,
                opts
                |> inject_query_options()
                |> Keyword.put(:schema, unquote(schema))
                |> Keyword.put(:row_module, unquote(s_mod))
              )
            end
          end
      end
    end)
  end

  defp extract_schema({:__aliases__, _location, schema}, caller), do: glom(schema, caller)

  defp extract_scope(nil, _caller), do: nil
  defp extract_scope({:__aliases__, _location, caller_module}, caller), do: glom(caller_module, caller)
  defp extract_scope({:__MODULE__, _location, nil}, caller), do: glom(caller.module, caller)

  defp extract({{:__aliases__, _, delegate_module}, {:%, _, [{:__aliases__, _, pattern}, {:%{}, _, _}]}}, nil, caller) do
    %{
      delegate: delegate_module |> glom(caller),
      pattern: pattern |> glom(caller),
      scope: delegate_module |> glom(caller)
    }
  end
  defp extract({{:__aliases__, _, delegate_module}, {:%, _, [{:__aliases__, _, pattern}, {:%{}, _, _}]}}, scope, caller) do
    %{
      delegate: delegate_module |> glom(caller),
      pattern: pattern |> glom(caller),
      scope: scope |> glom(caller)
    }
  end

  defp glom(list, caller) do
    alias = list
    |> List.wrap()
    |> Module.concat()
    caller.aliases
    |> Keyword.get(alias, alias)
  end

end
