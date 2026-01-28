defmodule ExFlow.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_flow,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "A library for building and managing flow-based graphs.",
      package: package(),
      # Test coverage
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      # Dialyzer
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix, :ex_unit],
        flags: [:error_handling, :underspecs]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]


  defp deps do
    [
      {:libgraph, "~> 0.16"},
      {:ecto_sql, "~> 3.13"},
      {:jason, "~> 1.2"},
      {:postgrex, ">= 0.0.0", only: [:dev, :test]},
      # Dev/Test tools
      {:mox, "~> 1.0", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      name: "ex_flow",
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Your Name"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/your-repo/ExFlowGraph"}
    ]
  end
end
