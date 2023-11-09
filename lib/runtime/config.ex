defmodule BoxTurtle.Runtime.Config do
  @moduledoc """
  Uses Config.Helper to get properly typed Elixir values.

  Leverages [BradleyD's external config loader](https://github.com/bradleyd/external_config)

  Add `external_config` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:external_config, "~> 0.1.0"}]
    end
    ```

  After calling load_runtime_config(application), runtime settings will be available using Application module functions, just as
  though the values were set during compile time, although they are runtime values read from the ENV values.

  Usage:

    1. Make a runtime.exs file appropriate to your application according to the syntax specified in
      Runtime.Config.Helper's documentation.

    2. Make sure that in your various compile-time config files you set runtime file locations.
      prod.exs
      ```
      config :my_app,
        # Path may be absolute or relative
        runtime_config_file: "/etc/runtime.exs"
      ```
      dev.exs
      ```
      config :my_app,
        # Path may be absolute or relative
        runtime_config_file: "config/runtime.exs"
      ```
      test.exs
      ```
      config :my_app,
        # Path may be absolute or relative
        runtime_config_file: "test/support/runtime.exs"
      ```
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
    |> ExternalConfig.read!()
    |> debug("Runtime configuration")
    |> overwrite_application_settings()
  end

  defp overwrite_application_settings([]) do
    :ok
  end
  defp overwrite_application_settings([{application, settings} | app_settings]) do
    # Only replace compile-time Application config with non-nil values.
    settings
    |> Enum.each(fn {key, value} -> is_nil(value) || Application.put_env(application, key, value) end)
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
  defp config_path(config_file) when is_binary(config_file) and binary_part(config_file, 0, 1) == "/", do: config_file
  defp config_path(config_file) when is_binary(config_file) do
    File.cwd!()
    |> debug("Current Working Directory")
    |> Path.join(config_file)
    |> Path.expand()
    |> debug("#{config_file} full path")
  end
  defp config_path(_), do: nil

end
