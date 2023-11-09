defmodule BoxTurtle.Debug.PipeDebug do
  @moduledoc """
  Support the injection of a debug message into a pipe.

  ## Usage

    use BoxTurtle.Debug.PipeDebug

  Or

    use BoxTurtle.Debug.PipeDebug[, logger_module: <module> | logger_macro: [:debug | :info], application: <application>
      application: <atom>, default: :box_turtle, since unit tests do not have a defined application,
        this option allows you to specify one when testing so that the debug_enabled_modules value
        can be found in the appropriate application the unit tests are testing.
      logger_module: <module>, default: Logger, must implement Logger macros/functions.
        Mostly used for testing PipeDebug itself.
      logger_macro: <macro>, default: :debug, supported macros: [:debug, :info]
        I added this option as a workaround for the unconditional Logger.debug() messages
        already in the system.
  """

  defmacro __using__(options) do
    application = options |> Keyword.get(:application, nil)
    logger_module = options |> Keyword.get(:logger_module, Logger)
    logger_macro = options |> Keyword.get(:logger_macro, :debug)
    quote location: :keep do
      # In case this module gets "use"d more than once (used in another used module or imported)
      unless Module.defines?(__MODULE__, {:debug, 3}) do
        use BoxTurtle.Runtime.Application.Environment
        require Logger

        # By default, use Logger module, although any module that supports its interface will do.
        @logger_module unquote(logger_module)
        # By default, use Logger.debug(), info() is also supported
        @logger_macro unquote(logger_macro)

        @doc """
        Writes an inspection dump of the given object to standard output, optionally preceded by a message.  Used to place
        inspections in the midst of a chain of piped calls.

        ## Parameters

          - val: Value to be inspected.
          - message: optional message to precede the value inspection.
          - opts: options
            - :condition an anonymous function/1 used to check conditions on the debug message.
              Allows the user to throttle log messages for highly repetitive tasks difficult to
              comb through in the log.  This option allows debug messages to be logged only if,
              say, an id is in a specified set, the name matches a given regex pattern, etc.
              The condition function will be passed first argument to debug (value) and must
              return a boolean.

        ## Returns

          - The value dumped to the log in the inspection, unchanged.

        ## Examples

            %{jazz: "Art", messenger: "Blakey"}
            |> Map.values()
            |> debug("Jazz Message")
            |> Enum.reverse()

        """
        @spec debug(any(), binary() | nil, keyword() | []) :: any()
        def debug(val, message \\ nil, opts \\ [])
        def debug(val, message, opts) do
          condition = opts[:condition] || fn _val -> true end
          do_debug(module_debugging?(), condition, val, message)
          val
        end

        # This seems to be unused and is causing all sorts of Dialyzer issues
        # Such as `overlapping_contract`. It seems to create duplicates of the debug function.
        # defoverridable debug: 3

        defp module_debugging?() do
          __MODULE__ in module_mask()
#          |> IO.inspect(label: "#{__MODULE__} Debugging")
        end
        defoverridable module_debugging?: 0

        def module_mask() do
#          @logger_module.level() |> IO.inspect(label: "Logging Level")
#          __MODULE__ |> IO.inspect(label: "Module")
          Application.get_env(pipe_debug_application(), :debug_enabled_modules, []) |> List.wrap()
#          |> IO.inspect(label: "#{pipe_debug_application()} enabled modules")
        end
        defoverridable module_mask: 0

        defp pipe_debug_application() do
          unquote(application) || Application.get_application(__MODULE__) || :box_turtle
        end
        defoverridable pipe_debug_application: 0

        defp do_debug(true, condition, val, message) when is_function(condition) do
          do_debug(true, condition.(val), val, message)
        end
        defp do_debug(true, true, val, message) do
          dbg(val, message, @logger_macro)
        end
        defp do_debug(_, _, _, _) do
          :ok
        end
        defoverridable do_debug: 4

        defp dbg(val, nil, :debug) do
          if test_mode?(pipe_debug_application()) do
            IO.inspect(val, pretty: true, limit: :infinity, printable_limit: :infinity)
          else
            @logger_module.debug(inspect(val, pretty: true, limit: :infinity, printable_limit: :infinity))
          end
          :ok
        end
        defp dbg(val, message, :debug) when is_binary(message) do
          if test_mode?(pipe_debug_application()) do
            IO.inspect(val, pretty: true, limit: :infinity, printable_limit: :infinity, label: message)
          else
            @logger_module.debug("#{message}: #{inspect(val, pretty: true, limit: :infinity, printable_limit: :infinity)}")
          end
          :ok
        end
        defp dbg(val, nil, :info) do
          @logger_module.info(inspect(val, pretty: true, limit: :infinity, printable_limit: :infinity))
        end
        defp dbg(val, message, :info) when is_binary(message) do
          @logger_module.info("#{message}: #{inspect(val, pretty: true, limit: :infinity, printable_limit: :infinity)}")
        end
        defp dbg(val, message, macro) do
          dbg(val, inspect(message), macro)
        end
        defoverridable dbg: 3
      end
    end
  end
end
