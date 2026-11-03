defmodule BoxTurtle.MixProject do
  use Mix.Project

  @source_url "https://github.com/twajjo/box_turtle"

  def project do
    [
      app: :box_turtle,
      version: get_version(),
      elixir: "~> 1.20",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      name: "BoxTurtle",
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      dialyzer: [
        plt_add_apps: [:mix, :ex_unit],
        plt_core_path: "priv/plts",
        plt_local_path: "priv/plts"
      ]
    ]
  end

  def cli do
    [preferred_envs: [coveralls: :test, "coveralls.html": :test]]
  end

  def application do
    [extra_applications: [:logger, :crypto]]
  end

  defp deps do
    [
      {:ecto, "~> 3.12"},
      {:ksuid, "~> 0.1.2"},
      {:ecto_sql, "~> 3.12", only: :test},
      {:ecto_sqlite3, "~> 0.17", only: :test},
      {:mox, "~> 1.2", only: :test},
      {:excoveralls, "~> 0.18", only: :test},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    "A toolkit of Elixir building blocks: a convention-driven Ecto query/change layer, " <>
      "typed runtime configuration from environment variables, pipe-friendly debugging and small utilities."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib mix.exs VERSION.txt README.md LICENSE CHANGELOG.md .formatter.exs)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{get_version()}",
      extras: ["README.md", "CHANGELOG.md", "guides/schema.md"],
      groups_for_modules: [
        Schema: ~r/^BoxTurtle\.Schema/,
        Runtime: ~r/^BoxTurtle\.Runtime/,
        Debug: ~r/^BoxTurtle\.Debug/,
        Common: ~r/^BoxTurtle\.Common/,
        Security: ~r/^BoxTurtle\.Security/
      ]
    ]
  end

  defp get_version do
    case File.read(Path.join(__DIR__, "VERSION.txt")) do
      {:ok, file} -> String.trim(file)
      {:error, _} -> "0.0.0"
    end
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
