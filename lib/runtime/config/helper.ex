defmodule BoxTurtle.Runtime.Config.Helper do
  @moduledoc """
  ## Helper

  A utility for fetching environment variable values from System and parsing them into the correct types ready for
  use in elixir without having to do all the parsing and validation yourself.

  Helper.get_env("ENV_VAR_NAME", <options>)

  ## Valid options:

    type:
      :atom - The string read from the environment is converted to an atom.
      :boolean - The string read from the environment must be in the Elixir set [true, false]
      :charlist - The environment variable is converted to an erlang-compatible character list.
      :float - The env variable is converted to a float.
      :integer - The env variable is converted to an integer.
      :module - The env variable is interpreted as an existing (loaded) module name.
      :string - The env variable is left as a raw string (elixir binary()).
      :list - The env variable is interpreted as a comma-separated list of values of the specified subtype (default: :string)
      :tuple - The env variable is interpreted as a comma-separated tuple of values of the specified subtype (default: :string)
      :map - The env variable is decoded as a JSON object (with `JSON.decode/1`) into a map with string keys.
    subtype: For lists and tuples, a subtype may be specified indicating the type(s) of elements they are expected to contain.
      :atom - the resulting list/tuple will be a set of atoms.
      :boolean - the resulting list/tuple will be a set of boolean values.
      :charlist - the resulting list/tuple will be a set of charlist elements (list of lists).
      :float - the resulting list/tuple will be a set of floating point values.
      :integer - the resulting list/tuple will be a set of integers.
      :module - the resulting list/tuple will be a set of loaded modules.
      :string - the resulting list/tuple will be a set of strings.
      :map - the resulting list/tuple will be a set of map() objects.
      tuple() - valid only for a type of tuple, the subtype of each element in the tuple can be expressed separately for
        each element in the tuple.  Note that the size of the subtype tuple must be the same as the number of elements
        expressed in the comma-separated values of the environment variable parsed.
      list() - the subtype of each element in the tuple or list can be expressed separately for each element in the
        list or tuple.  Note that the size of the subtype list must be the same as the number of elements
        expressed in the comma-separated values of the environment variable parsed.
    default: any() The default value returned when the specified variable is not provided in the system environment.
    in_set: list() The value parsed from the environment variable must be in the specified list of values of the same
      type.
    in_range: range() The value parsed from the environment must be within the specified range of values.
    regex: /regex/ pattern the (type: :string) variable must match.
    custom: (tuple(): {Module, validator/2})  A module and function that takes a value and helper options for custom
      validation of the value.
    required: (boolean()), when true a value must be provided in the environment.  A nil generates an {:error, msg} result.
    unsafe_atoms: (boolean()), :atom and :module values must name existing atoms unless this is true.  Atoms are never
      garbage collected, so only enable it for trusted environments.

  """

  require Logger

  use BoxTurtle.Debug.PipeDebug

  @valid_types [
    :atom,
    :boolean,
    :charlist,
    :float,
    :integer,
    :module,
    :string,
    :list,
    :tuple,
    :map
  ]
  @valid_subtypes [
    :atom,
    :boolean,
    :charlist,
    :float,
    :integer,
    :module,
    :string,
    :map
  ]

  # Testing hooks
  defmodule Wrapper do
    defmodule API do
      @callback get_env(String.t(), String.t() | nil) :: String.t() | nil
    end

    @behaviour API

    @impl true
    def get_env(varname, default \\ nil) do
      System.get_env(varname, default)
    end
  end

  @system_module Application.compile_env(:box_turtle, :helper_system, Wrapper)

  @doc """
  Reads the environment variable `var_name`, parses it into the requested type and validates it.

  Returns the parsed value, the `:default` (or `nil`) when the variable is unset, or
  `{:error, message}` when parsing or validation fails. See the module documentation for the options.

      Helper.get_env("POOL_SIZE", type: :integer, default: 10, in_range: 1..100)
  """
  @spec get_env(binary(), keyword()) :: {:error, binary()} | any()
  def get_env(var_name, opts \\ []) when is_binary(var_name) do
    opts_map = Map.new(opts) |> Map.put_new(:_env_var, var_name)

    @system_module.get_env(var_name, nil)
    |> parse(determine_type(opts), opts_map)
    |> validity_check(opts_map)
  end

  defp determine_type(opts) do
    # Use the explicitly defined type if provided.
    # Unspecified type: try to determine from the data type of the default.
    # No default type: try to determine from the data type of the set (if :in_set specified).
    # TODO: (Maybe deterine from "in-range"?)
    # Must be a string, then...
    opts[:type] ||
      type_of(opts[:default]) ||
      (is_list(opts[:in_set]) && type_of(opts[:in_set] |> List.first())) ||
      :string
  end

  ## Error reporting

  defp error(msg, _opts) do
    # Logger.error("#{opts._env_var}: #{msg}")
    {:error, msg}
  end

  # Determine type from value.
  defp type_of(nil) do
    nil
  end

  defp type_of(value)
       when is_boolean(value) do
    :boolean
  end

  defp type_of(value)
       when is_integer(value) do
    :integer
  end

  defp type_of(value)
       when is_float(value) do
    :float
  end

  defp type_of(value)
       when is_atom(value) do
    if Code.ensure_loaded?(value), do: :module, else: :atom
  end

  defp type_of(value)
       when is_tuple(value) do
    :tuple
  end

  defp type_of(value)
       when is_list(value) do
    :list
  end

  defp type_of(value) when is_map(value), do: :map

  defp type_of(_value) do
    nil
  end

  defp safe_type_of(value) do
    type_of(value) || :string
  end

  ## Parse based on determined type

  defp parse(nil, _type, %{default: default} = _opts) do
    default
  end

  defp parse(value, nil, opts) do
    parse(value, :string, opts)
  end

  defp parse(value, :string, _opts) do
    value
  end

  defp parse(value, :charlist, _opts) do
    value |> String.to_charlist()
  end

  defp parse(value, :boolean, opts) do
    value
    |> String.downcase()
    |> String.to_existing_atom()
    |> validity_check(Map.put_new(opts, :in_set, [true, false]))
  end

  defp parse(value, :integer, _opts) do
    value
    |> String.to_integer()
  end

  defp parse(value, :float, _opts) do
    value
    |> String.to_float()
  end

  defp parse(value, :tuple, opts) do
    value
    |> parse(:list, opts)
    |> List.to_tuple()
  end

  defp parse(value, :list, opts) do
    value
    |> String.split(",")
    |> Enum.map(fn elem -> String.trim(elem) end)
    |> parse_subtypes(opts)
  end

  defp parse(value, :module, opts) do
    case value do
      "Elixir." <> _ -> to_atom(value, opts)
      _ -> to_atom("Elixir." <> value, opts)
    end
  end

  defp parse(value, :atom, opts) do
    to_atom(value, opts)
  end

  defp parse(value, :map, opts) do
    case JSON.decode(value) do
      {:ok, map} when is_map(map) -> map
      {:ok, other} -> error("Expected a JSON object, got: #{inspect(other)}", opts)
      {:error, reason} -> error("Invalid JSON (#{inspect(reason)}): #{inspect(value)}", opts)
    end
  end

  defp parse(_value, type, opts) do
    error("Unrecognized type (#{inspect(type)}), supported types: #{inspect(@valid_types)}", opts)
  end

  # Atoms are never garbage collected, so only existing atoms are accepted unless unsafe_atoms: true.
  defp to_atom(value, %{unsafe_atoms: true}), do: String.to_atom(value)

  defp to_atom(value, opts) do
    String.to_existing_atom(value)
  rescue
    ArgumentError ->
      error(
        "#{inspect(value)} is not an existing atom (pass unsafe_atoms: true to allow new atoms)",
        opts
      )
  end

  # Parse list and tuple elements

  defp parse_subtypes(list, opts) do
    parse_subtypes(list, Map.put_new(opts, :subtype, :string), [])
  end

  defp parse_subtypes([], %{}, acc) do
    Enum.reverse(acc)
  end

  defp parse_subtypes(values, %{subtype: subtype} = opts, acc)
       when subtype in @valid_subtypes and is_list(values) do
    parse_subtypes(values, %{opts | subtype: List.duplicate(subtype, length(values))}, acc)
  end

  defp parse_subtypes(values, %{subtype: subtypes} = opts, acc) when is_tuple(subtypes) do
    parse_subtypes(values, %{opts | subtype: Tuple.to_list(subtypes)}, acc)
  end

  defp parse_subtypes([hv | tv] = values, %{subtype: [hs | ts] = subtypes} = opts, acc)
       when length(values) == length(subtypes) do
    parse_subtypes(tv, %{opts | subtype: ts}, [parse(hv, hs, %{opts | type: hs})] ++ acc)
  end

  defp parse_subtypes(values, %{subtype: subtypes} = opts, _acc)
       when is_list(subtypes) and is_list(values) do
    error(
      "value list (#{inspect(values)}) length #{length(values)} to " <>
        "type list (#{inspect(subtypes)}) length #{length(subtypes)}",
      opts
    )
  end

  # Second, run built-in validators [:in_set, :in_range, :regex] and customs...

  defp validity_check(value, opts) when is_map(opts) do
    value
    |> check_type(opts)
    |> check_set(opts)
    |> check_range(opts)
    |> check_regex(opts)
    |> check_custom(opts)
    |> check_required(opts)
  end

  # Required checks
  defp check_required(nil, %{required: true} = opts) do
    error("value is required and no default was provided", opts)
  end

  defp check_required({:error, _} = error, _opts) do
    error
  end

  defp check_required(value, _opts) do
    value
  end

  # Final result type checks
  defp check_type(nil, _opts) do
    nil
  end

  defp check_type({:error, _} = error, _opts) do
    error
  end

  defp check_type([], _opts) do
    []
  end

  defp check_type(list, %{subtype: subtype} = opts)
       when is_list(list) and subtype in @valid_subtypes do
    check_type(list, %{opts | subtype: List.duplicate(subtype, length(list))})
  end

  defp check_type([hv | tv], %{subtype: [hs | ts], type: type} = opts)
       when length(ts) == length(tv) do
    hv |> debug("Type of")
    type_of(hv) |> debug("Is type")
    hs |> debug("Expected")

    if safe_type_of(hv) == hs do
      case check_type(tv, %{opts | subtype: ts}) do
        list when is_list(list) -> [hv] ++ list
        error -> error
      end
    else
      error("value (#{inspect(hv)}) subtype (#{inspect(hs)}) mismatch in #{inspect(type)}", opts)
    end
  end

  defp check_type(values, %{subtype: types} = opts) when length(types) != length(values) do
    error(
      "value list (#{inspect(values)}) length to " <>
        "type list (#{inspect(types)}) length mismatch in #{inspect(types)}",
      opts
    )
  end

  defp check_type(value, %{subtype: subtypes, type: :tuple} = opts) when is_tuple(value) do
    subtypes = if is_tuple(subtypes), do: Tuple.to_list(subtypes), else: subtypes

    case value |> Tuple.to_list() |> check_type(%{opts | subtype: subtypes}) do
      list when is_list(list) -> List.to_tuple(list)
      error -> error
    end
  end

  defp check_type(value, %{type: type} = opts) when type in @valid_types do
    value |> debug("Validating type of")
    checked_type = safe_type_of(value)

    if checked_type == type || (checked_type == :list && type == :charlist) do
      value
    else
      error(
        "value (#{inspect(value)}) type (#{inspect(checked_type)}) is not type specified (#{inspect(type)})",
        opts
      )
    end
  end

  defp check_type(value, _opts) do
    value
  end

  # Run custom validators

  defp check_custom(nil, _opts) do
    nil
  end

  defp check_custom({:error, _} = error, _opts) do
    error
  end

  defp check_custom(value, %{custom: custom_validators} = opts)
       when is_list(custom_validators) do
    iterate_customs(value, opts, custom_validators)
  end

  defp check_custom(value, %{custom: {module, function}} = opts)
       when is_atom(module) and
              is_atom(function) do
    {:module, module} = Code.ensure_compiled(module)

    ({function, 2} in module.__info__(:functions) &&
       Kernel.apply(module, function, [value, opts])) ||
      error("custom validator module #{module} or function #{function} missing", opts)
  end

  defp check_custom(value, _opts) do
    value
  end

  defp iterate_customs(value, _opts, []) do
    value
  end

  defp iterate_customs(value, opts, [custom | the_rest]) do
    value
    |> check_custom(%{opts | custom: custom})
    |> iterate_customs(opts, the_rest)
  end

  ## Check must-be-in-a-set validators for sets of atoms, numbers, strings, etc.

  defp check_set({:error, _} = error, _opts) do
    error
  end

  defp check_set(value, %{in_set: set} = opts) when is_list(set) do
    if Enum.member?(set, value) do
      value
    else
      error("value #{value} not in options #{inspect(set)}", opts)
    end
  end

  defp check_set(value, _opts) do
    value
  end

  ## Check ordinal range validators...

  defp check_range({:error, _} = error, _opts) do
    error
  end

  defp check_range(value, %{in_range: range} = opts) do
    if Enum.member?(range, value) do
      value
    else
      error("value #{value} not in specified range #{inspect(range)}", opts)
    end
  end

  defp check_range(value, _opts) do
    value
  end

  ## Check regex validators...

  defp check_regex({:error, _} = error, _opts) do
    error
  end

  defp check_regex(value, %{regex: regex} = opts) do
    if Regex.match?(regex, to_string(value)) do
      value
    else
      error("value #{value} does not match regex #{inspect(opts[:regex])}", opts)
    end
  end

  defp check_regex(value, _opts) do
    value
  end
end
