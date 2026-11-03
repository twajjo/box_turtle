defmodule BoxTurtle.Runtime.Config do
  @moduledoc """
  Loads a runtime configuration script (standard `import Config` syntax, read with `Config.Reader`) into the
  application environment. Combine with `BoxTurtle.Runtime.Config.Helper` to get properly typed values from
  environment variables.

  After `load_runtime_config/1` runs, the script's settings are read with the usual `Application`
  functions, just like compile-time config. Unlike Mix's own `config/runtime.exs`, the script can live
  anywhere (for example `/etc/my_app/settings.exs` beside a release) and can be loaded again later.

  ## Usage

  1. Write the settings script. Give it a name other than `config/runtime.exs`, which Mix and releases
     already load by themselves:

         # config/settings.exs
         import Config
         alias BoxTurtle.Runtime.Config.Helper

         config :my_app,
           pool_size: Helper.get_env("POOL_SIZE", type: :integer, default: 10),
           feature_flags: Helper.get_env("FEATURE_FLAGS", type: :list, subtype: :atom, default: [])

  2. Point each build at its script. Relative paths are resolved from the current working directory:

         # config/dev.exs
         config :my_app, runtime_config_file: "config/settings.exs"

         # config/test.exs
         config :my_app, runtime_config_file: "test/support/settings.exs"

         # config/prod.exs
         config :my_app, runtime_config_file: "/etc/my_app/settings.exs"

  3. Load it before starting anything that reads those settings:

         defmodule MyApp.Application do
           use Application

           @impl true
           def start(_type, _args) do
             :ok = BoxTurtle.Runtime.Config.load_runtime_config(:my_app)

             children = [{MyApp.Pool, size: Application.fetch_env!(:my_app, :pool_size)}]
             Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
           end
         end

  Only non-nil values replace existing settings, so an unset environment variable without a
  `:default` keeps the compile-time value.

  To load a specific file instead, pass its path: `load_runtime_config("/etc/my_app/settings.exs")`.
  """
  require Logger

  use BoxTurtle.Debug.PipeDebug

  @config_runtime_var_name :runtime_config_file

  @doc """
  Load runtime config from environment variables and express them as Application-accessible values.

  Loading a runtime config will replace existing values set during compile time if given the same names.

  ## Parameters

    - application - the Application atom whose runtime configuration is to be set.
    OR
    - config_path - the path to a runtime script file to parse and load.

  ## Returns

    :ok

  """
  @spec load_runtime_config(atom() | String.t()) :: :ok
  def load_runtime_config(nil), do: :ok

  def load_runtime_config(application) when is_atom(application) do
    config_path(application)
    |> debug("Config path")
    |> load_runtime_config()
  end

  def load_runtime_config(config_path) when is_binary(config_path) do
    config_path
    |> debug("Loading runtime config from")
    |> Config.Reader.read!()
    |> debug("Runtime configuration")
    |> overwrite_application_settings()
  end

  defp overwrite_application_settings([]) do
    :ok
  end

  defp overwrite_application_settings([{application, settings} | app_settings]) do
    # Only replace compile-time Application config with non-nil values.
    settings
    |> Enum.each(fn {key, value} ->
      is_nil(value) || Application.put_env(application, key, value)
    end)

    overwrite_application_settings(app_settings)
  end

  defp config_path(nil), do: nil

  defp config_path(application) when is_atom(application) do
    # Support both absolute and relative paths in the configuration.
    Application.get_env(application, @config_runtime_var_name, nil)
    |> debug("Base path")
    |> config_path()
    |> debug("Path expanded to")
  end

  defp config_path(config_file)
       when is_binary(config_file) and binary_part(config_file, 0, 1) == "/", do: config_file

  defp config_path(config_file) when is_binary(config_file) do
    File.cwd!()
    |> debug("Current Working Directory")
    |> Path.join(config_file)
    |> Path.expand()
    |> debug("#{config_file} full path")
  end

  defp config_path(_), do: nil
end
