
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


# List all modules that can be mocked in a test.  All modules MUST have ".API" module defined.
# .Mock modules will be created for each module listed below but must also be listed in config/test.exs
_modules_to_mock =
  [
    PurpleEngine.CommandPublisher,
    PurpleEngine.Domains.BeaconMaintenance,
    PurpleEngine.Domains.BeaconManufacturing,
    PurpleEngine.Domains.HexFirmware,
    PurpleEngine.Domains.Location,
    PurpleEngine.Domains.MaintenanceSession,
    PurpleEngine.Domains.Network,
    PurpleEngine.Domains.Node,
    PurpleEngine.Domains.PurchaseOrder,
    PurpleEngine.NodeDataProcessor,
    PurpleEngine.Domains.Site,
    PurpleEngine.Metrics.HealthzChecks,
    {PurpleAccounts.Accounts.PurchaseOrder.Query, [PurpleBase.Schema.Query.Options.API, PurpleBase.Schema.Query.API]},
    {PurpleAccounts.Accounts.Node.Query, [PurpleBase.Schema.Query.Options.API, PurpleBase.Schema.Query.API]},
    {PurpleAnalytics.Analytics.NodeAssetLocationHistory.Query,
     [PurpleBase.Schema.Query.Options.API, PurpleBase.Schema.Query.API]},
    {PurpleAccounts.Accounts.Site.Query, [PurpleBase.Schema.Query.Options.API, PurpleBase.Schema.Query.API]}
  ]
  |> Enum.each(fn
    # If the API implemented cannot be derived from the implementation name.
    {module, api} ->
      Code.ensure_compiled(module)

      api
      |> List.wrap()
      |> Enum.each(fn a -> Code.ensure_compiled(a) end)

      module
      |> Module.concat(Mock)
      |> Mox.defmock(for: api)

    module ->
      Code.ensure_compiled(module)
      Code.ensure_compiled(Module.concat(module, API))

      module
      |> Module.concat(Mock)
      |> Mox.defmock(for: Module.concat(module, API))
  end) 