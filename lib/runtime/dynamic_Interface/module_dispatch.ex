
defmodule BoxTurtle.Runtime.DynamicInterface.ModuleDispatch do
	@moduledoc """
	Module for handling dynamic interface module hooks.
	"""
  defmacro __using__(opts) do
    behaviour_module = opts |> Keyword.get(:behaviour, __CALLER__ |> Module.concat("API"))

		impl = Application.compile_env(:module_dispatch, :delegate_module)
    impl_module = opts |> Keyword.get(:impl, __CALLER__ |> Module.concat("Impl"))
    is_stub = opts |> Keyword.get(:generate_stub, false) 
    is_runtime = opts |> Keyword.get(:generate_stub, false) 
    # is_dispatcher = !is_stub

    # Ensure they are expanded (aliases -> real modules)
    behaviour_module = Macro.expand(behaviour_module, __CALLER__)
    impl_module = Macro.expand(impl_module, __CALLER__)

    forwards = behaviour_module.behaviour_info(:callbacks)
			|> Enum.map(fn {fun, arity} ->
				args = 1..arity 
					|> Enum.map(fn num ->
						Macro.var(:"arg#{1}", __MODULE__)
					end)

				case {is_stub, is_runtime} do
					{true, _} ->
						# If it's a stub and runtime, we define the function with no implementation
						# This is useful for testing and development purposes.
						# The actual implementation will be provided in the specified 
						# implementation module.
						quote do
							def unquote(fun)(unquote_splicing(args)) do
								:ok
							end
						end
					{false, true} ->
						# If it's a dispatcher, we forward to the implementation module
  					# If it's a dispatcher, we forward to the implementation module
  					# This allows us to dynamically dispatch to the implementation module
    				quote do
  						def unquote(fun)(unquote_splicing(args)) do
  							impl_module().unquote(fun)(unquote_splicing(args))
  						end
  					end
						:ok
					{false, false} ->
						# If it's a dispatcher, we forward to the implementation module
						:ok
					_ ->
						raise "Invalid combination of options: is_stub=#{is_stub}, is_runtime=#{is_runtime}"
				end
				if is_stub do
					# If it's a stub, we just define the function with no implementation
						# This is a stub implementation that does nothing (haappy path)
						# It is used to allow the module to compile without errors
						# and to provide a placeholder for the implementation.
						# This is useful for testing and development purposes.
						# The actual implementation will be provided in the specified 
						# implementation module.
				elsif is_runtime do
				else
					# If it's a dispatcher, we forward to the implementation module
					# This allows us to dynamically dispatch to the implementation module
  				quote do
						def unquote(fun)(unquote_splicing(args)) do
							unquote(impl_module).unquote(fun)(unquote_splicing(args))
						end
					end
				end
			end)

    quote do
      @behaviour unquote(behaviour_module)

      unquote_splicing(forwards)

			def impl_module() do
				unquote(impl_module)
			end
    end
  end
end
