defmodule BoxTurtle.Schema.Change do
  defmacro __using__(options) do
    repo = Keyword.get(options, :repo, nil)
    create_opts = Keyword.get(options, :create_opts, [])

    quote do
      alias BoxTurtle.Schema.Change
      use BoxTurtle.Debug.PipeDebug

      @schema __MODULE__ |> Module.split() |> List.delete_at(-1) |> Module.concat()

      @behaviour Change.API

      @impl true
      def delete!(id) when is_binary(id) or is_integer(id) do
        @schema.Query.get!(id)
        |> delete!()
      end

      @impl true
      def delete!(%@schema{} = item) do
        item
        |> unquote(repo).delete!()
      end

      @impl true
      def delete!(nil), do: nil

      @impl true
      def delete(id) when is_binary(id) or is_integer(id) do
        case @schema.Query.get(id) do
          {:ok, %@schema{} = item} -> delete(item)
          bollox -> bollox
        end
      end

      @impl true
      def delete(%@schema{} = item) do
        item
        |> unquote(repo).delete()
      end

      @impl true
      def delete(%Ecto.Changeset{} = item) do
        item
        |> Map.put(:action, :delete)
        |> unquote(repo).delete()
      end

      @impl true
      def update!(%Ecto.Changeset{} = mods) do
        mods
        |> Map.put(:action, :update)
        |> unquote(repo).update!()
      end

      @impl true
      def update!(%@schema{} = source, %{} = changes) do
        source
        |> @schema.update_changeset(changes)
        |> Map.put(:action, :update)
        |> unquote(repo).update!()
      end

      @impl true
      def update(%Ecto.Changeset{} = mods) do
        mods
        |> Map.put(:action, :update)
        |> unquote(repo).update()
      end

      @impl true
      def update(%@schema{} = source, %{} = changes) do
        source
        |> @schema.update_changeset(changes)
        |> Map.put(:action, :update)
        |> unquote(repo).update()
      end

      @impl true
      def create!(%Ecto.Changeset{} = nube) do
        nube
        |> Map.put(:action, :insert)
        |> unquote(repo).insert!(unquote(create_opts))
      end

      @impl true
      def create!(%{} = nube) do
        @schema.new_changeset()
        |> @schema.changeset(
          nube
          |> from_struct()
        )
        |> Map.put(:action, :insert)
        |> unquote(repo).insert!(unquote(create_opts))
      end

      @impl true
      def create(%Ecto.Changeset{} = nube) do
        nube
        |> Map.put(:action, :insert)
        |> unquote(repo).insert(unquote(create_opts))
      end

      @impl true
      def create(%{} = nube) do
        @schema.new_changeset()
        |> @schema.changeset(nube |> from_struct())
        |> Map.put(:action, :insert)
        |> unquote(repo).insert(unquote(create_opts))
      end

      # TODO: This is a very convenient function which should be available system wide at some point.
      # Perhaps as part of Ecto.Schema. There are tons of instances of wanting a Changeset map from an Echo.Schema struct.
      defp from_struct(nube) when is_struct(nube) do
        nube
        |> Map.from_struct()
        |> Enum.reject(fn
          {k, %Ecto.Association.NotLoaded{}} -> true
          {k, v} -> false
        end)
        |> Map.new()
      end

      defp from_struct(nube), do: nube
    end
  end
end
