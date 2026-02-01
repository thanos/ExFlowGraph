defmodule ExFlowGraph.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_flow_graph,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: "Interactive flow graph component library for Phoenix LiveView"
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {ExFlowGraph.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.8"},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_html, "~> 4.0"},
      {:libgraph, "~> 0.16"},
      {:jason, "~> 1.2"},
      {:gettext, "~> 0.26"}
    ]
  end

  defp package do
    [
      files: ~w(lib priv assets .formatter.exs mix.exs README* LICENSE*),
      licenses: ["MIT"],
      links: %{}
    ]
  end
end
