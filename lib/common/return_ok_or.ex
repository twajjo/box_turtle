defmodule BoxTurtle.Common.ReturnOkOr do
  @moduledoc """
  Normalizes loosely-shaped results (`nil`, bare values, `:error`, `{:error, _}`) into `{:ok, value}` /
  `{:error, reason}` tuples, plus macros that log a message together with the caller's stack trace.

      defmodule MyApp.Blog do
        import BoxTurtle.Common.ReturnOkOr

        alias MyApp.Blog.Post
        alias MyApp.Repo

        # Repo.get/2 returns a struct or nil; callers get {:ok, post} or {:error, :not_found}.
        def fetch_post(id), do: Post |> Repo.get(id) |> return_ok_or(:not_found)

        # Map.fetch/2 returns {:ok, value} or :error; normalize :error to a reason.
        def fetch_setting(settings, key), do: settings |> Map.fetch(key) |> return_ok_or(:missing_setting)

        def publish(id) do
          with {:ok, post} <- fetch_post(id) do
            post |> Post.changeset(%{status: "published"}) |> Repo.update()
          end
        end
      end

      MyApp.Blog.fetch_post(42)                       #=> {:ok, %MyApp.Blog.Post{id: 42}}
      MyApp.Blog.fetch_post(-1)                       #=> {:error, :not_found}
      MyApp.Blog.fetch_setting(%{theme: "dark"}, :lang) #=> {:error, :missing_setting}
  """

  @doc """
  Logs `message` at `:error` level with the current stack trace. A macro, so the trace starts at the caller.
  """
  defmacro error_with_stack(message) do
    quote do
      require Logger
      Logger.error(unquote(__MODULE__).with_stack(unquote(message)))
    end
  end

  @doc """
  Logs `message` at `:warning` level with the current stack trace. A macro, so the trace starts at the caller.
  """
  defmacro warn_with_stack(message) do
    quote do
      require Logger
      Logger.warning(unquote(__MODULE__).with_stack(unquote(message)))
    end
  end

  @doc false
  def with_stack(message) do
    {:current_stacktrace, stack} = Process.info(self(), :current_stacktrace)
    "#{inspect(message)}: #{inspect(stack, pretty: true, limit: :infinity)}"
  end

  @doc "Wraps `reason` in an error tuple."
  @spec return_error(reason) :: {:error, reason} when reason: term()
  def return_error(reason), do: {:error, reason}

  @doc """
  Returns `{:ok, value}` for a value or an `{:ok, _}` tuple, and `{:error, reason}` for `nil`, `:error` or an
  `{:error, _}` tuple (whose own reason is replaced by `reason`).
  """
  @spec return_ok_or(term(), reason) :: {:ok, term()} | {:error, reason} when reason: term()
  def return_ok_or(nil, reason), do: {:error, reason}
  def return_ok_or({:ok, _value} = ok, _reason), do: ok
  def return_ok_or({:error, _details}, reason), do: {:error, reason}
  def return_ok_or(:error, reason), do: {:error, reason}
  def return_ok_or(value, _reason), do: {:ok, value}

  @doc "Passes `{:ok, _}`, `{:error, _}` and `:error` through unchanged."
  @spec return_ok_or({:ok, term()} | {:error, term()} | :error) ::
          {:ok, term()} | {:error, term()} | :error
  def return_ok_or({:ok, _content} = ok), do: ok
  def return_ok_or({:error, _content} = error), do: error
  def return_ok_or(:error), do: :error
end
