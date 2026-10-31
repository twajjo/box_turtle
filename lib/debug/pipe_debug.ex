defmodule BoxTurtle.Debug.PipeDebug do
  @moduledoc """
  Injects a `debug/3` function that can be dropped into the middle of a pipe to log a value, returning it unchanged.

  Logging is off by default and enabled per module through application configuration, so debug calls can stay in
  the code without flooding the logs:

      config :my_app, debug_enabled_modules: [MyApp.Accounts, MyApp.Billing]

  ## Usage

      use BoxTurtle.Debug.PipeDebug

  Or

      use BoxTurtle.Debug.PipeDebug, application: :my_app, logger_module: MyLogger, logger_macro: :info

  ## Options

    * `:application` - the application whose `:debug_enabled_modules` setting is consulted. Defaults to the
      application the using module belongs to, falling back to `:box_turtle`. Useful in tests, where modules
      may not belong to a loaded application.
    * `:logger_module` - defaults to `Logger`. Any module exposing `debug/1` and `info/1` (functions or macros)
      will do; mostly used for testing PipeDebug itself.
    * `:logger_macro` - `:debug` (default) or `:info`, the level messages are logged at.
  """

  defmacro __using__(options) do
    application = Keyword.get(options, :application)
    logger_module = Keyword.get(options, :logger_module, quote(do: Logger))
    logger_macro = Keyword.get(options, :logger_macro, :debug)

    if logger_macro not in [:debug, :info] do
      raise ArgumentError, "PipeDebug :logger_macro must be :debug or :info, got: #{inspect(logger_macro)}"
    end

    quote location: :keep do
      # In case this module gets "use"d more than once (used in another used module or imported)
      if !Module.defines?(__MODULE__, {:debug, 3}) do
        require Logger

        @doc """
        Logs an inspection of the given value, optionally preceded by a message, and returns the value unchanged.
        Used to place inspections in the midst of a chain of piped calls.

        Nothing is logged unless this module is listed in the application's `:debug_enabled_modules` setting.

        ## Options

          * `:condition` - a function/1 receiving the value; the message is only logged when it returns true.
            Useful for throttling messages in highly repetitive code (log only a given id, a matching name, etc.).

        ## Examples

            %{jazz: "Art", messenger: "Blakey"}
            |> Map.values()
            |> debug("Jazz Message")
            |> Enum.reverse()

        """
        @spec debug(any(), String.t() | nil, keyword()) :: any()
        def debug(val, message \\ nil, opts \\ []) do
          if module_debugging?() and condition_met?(opts[:condition], val) do
            log_inspection(val, message)
          end

          val
        end

        @doc false
        def module_mask do
          pipe_debug_application()
          |> Application.get_env(:debug_enabled_modules, [])
          |> List.wrap()
        end

        defoverridable module_mask: 0

        defp module_debugging?, do: __MODULE__ in module_mask()

        defp condition_met?(nil, _val), do: true
        defp condition_met?(condition, val) when is_function(condition, 1), do: condition.(val) == true

        defp pipe_debug_application do
          unquote(application) || Application.get_application(__MODULE__) || :box_turtle
        end

        defp log_inspection(val, message) do
          unquote(logger_module).unquote(logger_macro)(format_inspection(val, message))
        end

        defp format_inspection(val, nil), do: inspect_value(val)
        defp format_inspection(val, message) when is_binary(message), do: "#{message}: #{inspect_value(val)}"
        defp format_inspection(val, message), do: format_inspection(val, inspect(message))

        defp inspect_value(val), do: inspect(val, pretty: true, limit: :infinity, printable_limit: :infinity)
      end
    end
  end
end
