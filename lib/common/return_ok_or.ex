defmodule BoxTurtle.Common.ReturnOkOr do
  @moduledoc """
  Recommended use:

  import BoxTurtle.Common.ReturnOkOr

  Now with stack dump logging.
  """
  require Logger

  # There is a secret to making Process.info(self(), :current_stacktrace) work in a macro, but I've surrendered to impatience...
  #
  # Requesting a stack should be macro instead of a function (don't want to pollute the stack with another function call)
  #
  # There should be a configuration also with enabled modules and whether warnings should be stack dumped...
  # We need something more comprehensive than provided here anyway.
  defmacro error_with_stack(message) do
#    Logger.error("#{inspect(message)}")
    # Don't want to turn this on without a means of turning it off.  Thinking of creating a stack dump a part of PipeDebug.
    quote do
      Logger.error("#{inspect(unquote(message))}: #{Process.info(self(), :current_stacktrace) |> inspect(pretty: true, limit: :infinity)}")
    end
  end
  defmacro warn_with_stack(message) do
#    Logger.warn("#{inspect(message)}")
    # Don't want to turn this on without a means of turning it off.  Thinking of creating a stack dump a part of PipeDebug.
    quote do
      Logger.warn("#{inspect(unquote(message))}: #{Process.info(self(), :current_stacktrace) |> inspect(pretty: true, limit: :infinity)}")
    end
  end

  @spec return_error(message :: any()) :: {:error, message :: any()}
  def return_error(message) do
    {:error, message}
  end

  @spec return_ok_or(nil | any() | {:ok, any()} | {:error, any()} | :error, message :: any()) :: {:error, any()} | {:ok, any()}
  def return_ok_or(nil, message) do
    # This is very nice, but who the HEck called this to generate the message?  Callstack?
    # warn_with_stack(message)
    {:error, message}
  end
  def return_ok_or({:ok, _thang} = item, _message) do
    item
  end
  # Start dealing with error map responses ahead of __struct__ured ones...
  def return_ok_or({:error, _details}, message) do
    # error_with_stack("#{inspect(message)}<==>#{inspect(details)}")
    {:error, message}
  end
  def return_ok_or(:error, message) do
    # error_with_stack(message)
    {:error, message}
  end
  # Loosest lastest...
  def return_ok_or(item, _message) do
    {:ok, item}
  end

  @spec return_ok_or({:ok, any()} | {:error, any()}) :: {:error, any()} | {:ok, any()}
  def return_ok_or({:ok, _content} = goodness) do
    goodness
  end
  def return_ok_or(:error) do
    # error_with_stack(:error)
    :error
  end
  def return_ok_or({:error, _content} = error) do
    # warn_with_stack(error)
    error
  end

end
