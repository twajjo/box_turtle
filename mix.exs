defmodule BoxTurtle.Mixfile do
  use Mix.Project

  def project do
    [
      app: :box_turtle,
      version: get_version(),
      vsn: get_version(),
      elixir: "~> 1.15.0",
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [
      extra_applications: [
        :logger,
        :external_config,
        :hackney
      ]
    ]
  end

  defp deps do
    [
      {:external_config, "~> 0.1.0"},
      {:atomic_map, "~> 0.8"},
      {:jason, "~> 1.2.2"},
      {:ksuid, "~> 0.1.2"},
      {:mox, "~> 1.0.0", only: :test, runtime: false},
      {:ex_doc, "~> 0.23", only: :dev, runtime: false},
      {:earmark, "~> 1.4", only: :dev, runtime: false},
      {:excoveralls, "~> 0.7", only: :test, runtime: false},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ecto_sql, "~> 3.1"},
      {:poison, "~> 3.1"},
      {:hackney, "~> 1.18", override: true},
      {:sweet_xml, "~> 0.6"},
      {:cloak_ecto, "~> 1.2"}
    ]
  end

  defp get_version() do
    case File.read("./VERSION.txt") do
      {:ok, file} -> String.trim(file)
      {:error, _} -> "0.0.0"
    end
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
