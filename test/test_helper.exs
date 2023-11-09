defmodule BoxTurtle.TestHelper do
  def start_applications() do
    # https://virviil.github.io/2016/10/26/elixir-testing-without-starting-supervision-tree/
    # Starting the full app for tests had always been a problem.
    # The App was running while also trying to run tests independent of the app.
    # Thanks to the above linked tip, the tests can run without the app.

    # (1)
    Application.load(:box_turtle)

    # (2)
    for app <- Application.spec(:box_turtle, :applications) do
      Application.ensure_all_started(app)
    end
  end

  @repos Application.compile_env(:box_turtle, :ecto_repos, [])

  def start_ecto() do
    Enum.each(@repos, & &1.start_link(pool_size: 2))
    Enum.each(@repos, &Ecto.Adapters.SQL.Sandbox.mode(&1, :manual))
    Logger.remove_backend(:console)
    :ok
  end

  def stop_ecto() do
    Logger.add_backend(:console, flush: true)
    :ok
  end

  @doc """
  A helper that transform changeset errors to a map of messages.

      assert {:error, changeset} = Accounts.insert(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end

BoxTurtle.TestHelper.start_applications()
Application.ensure_all_started(:mox)
ExUnit.start()
