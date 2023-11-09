
# List all modules that can be mocked in a test.  All modules MUST have ".API" module defined.
# .Mock modules will be created for each module listed below but must also be listed in config/test.exs
external_modules_to_mock = [
  Ecto.Repo,
  GenServer
]

for module <- external_modules_to_mock do
  {:module, _module} = Code.ensure_compiled(module)

  module
  |> Module.concat(Mock)
  |> Mox.defmock(for: module)
end

internal_modules_to_mock = [
]

for module <- internal_modules_to_mock do
  {:module, _module} = Code.ensure_compiled(module)
  {:module, _api} = Code.ensure_compiled(Module.concat(module, API))

  module
  |> Module.concat(Mock)
  |> Mox.defmock(for: Module.concat(module, API))
end
