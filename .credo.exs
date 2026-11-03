%{
  configs: [
    %{
      name: "default",
      strict: true,
      files: %{included: ["lib/", "test/", "mix.exs"], excluded: []},
      checks: %{
        extra: [
          # Test fixtures and helpers don't need module docs.
          {Credo.Check.Readability.ModuleDoc, files: %{excluded: ["test/"]}}
        ]
      }
    }
  ]
}
