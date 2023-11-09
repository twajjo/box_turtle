defmodule BoxTurtle.Runtime.Application.Helper do
  @moduledoc """
  Utilities to support Application start up and define conditional child startup.

  ## Usage:

    ```
    import BoxTurtle.Runtime.Application.Helper  # For native defp-like usage of Helper functions.
    ```

  Or

    ```
    alias BoxTurtle.Runtime.Application.Helper  # For function usage ase Helper.<Helper function>.
    ```



  """

  @doc """
  Conditionally append a set of children to an existing list for starting the application supervisor based on a
  boolean condition.

  Written because the ternary method of accomplishing the same thing was UGLY.

  ## Parameters

    current - the original list of children to start with the application supervisor.
    test - a value that evaluates to true or false, taking the form of in-line statements
      OR a function that can be called that will evaluate to true or false.
      See the "args" parameter if the test is a function for passing arguments.
    conditional - the new children to add to the child worker list if the test evaluates to true.
    args - the arguments to pass to the test function if it is a function expressed as an array (like Kernel.apply()).
      By default no arguments will be passed.

  ## Returns

    The original list of children with the conditional children appended if the test passes

  ## Example
    import BoxTurtle.Runtime.Application.Helper

  """
  def conditional_applications(current, boolean, to_add_if_true) do
    conditional_applications(current, boolean, to_add_if_true, [])
  end

  def conditional_applications(current, boolean, to_add_if_true, args) do
    conditional_append(current, boolean, to_add_if_true, args)
  end

  def conditional_modules(current, boolean, to_add_if_true) do
    conditional_modules(current, boolean, to_add_if_true, [])
  end

  def conditional_modules(current, funk, conditional, args) do
    conditional_append(current, funk, conditional, args)
  end

  def conditional_children(current, boolean, to_add_if_true) do
    conditional_children(current, boolean, to_add_if_true, [])
  end

  def conditional_children(current, funk, conditional, args) do
    conditional_append(current, funk, conditional, args)
  end

  def conditional_append(current, boolean, conditional) do
    conditional_append(current, boolean, conditional, [])
  end

  def conditional_append(current, false, _conditional, _args) when is_list(current) do
    current
  end

  def conditional_append(current, true, conditional, _args) do
    List.wrap(current) ++ List.wrap(conditional)
  end

  def conditional_append(current, funk, conditional, args)
      when is_function(funk) and is_list(args) do
    conditional_append(current, Kernel.apply(funk, args), conditional)
  end
end
