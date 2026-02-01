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
      description: "Interactive flow graph component library for Phoenix LiveView",

      # Docs
      name: "ExFlowGraph",
      source_url: "https://github.com/your-org/ex_flow_graph",
      homepage_url: "https://github.com/your-org/ex_flow_graph",
      docs: docs()
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
      {:gettext, "~> 0.26"},
            {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      files: ~w(lib priv assets .formatter.exs mix.exs README* INSTALLATION.md guides),
      licenses: ["MIT"],
      links: %{}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "INSTALLATION.md",
        "guides/getting-started.md",
        "guides/events-and-callbacks.md",
        "guides/labels-and-metadata.md",
        "guides/option-click-events.md",
        "guides/undo-redo.md",
        "guides/customization.md"
      ],
      groups_for_extras: [
        "Getting Started": ~r/(README|INSTALLATION|guides\/getting-started)/,
        "Reference": ~r/guides\/events-and-callbacks/,
        "Features": ~r/guides\/(labels-and-metadata|option-click-events|undo-redo)/,
        "Advanced": ~r/guides\/customization/
      ],
      groups_for_modules: [
        "Core": [
          ExFlow.Core.Graph,
          ExFlow.HistoryManager
        ],
        "Commands": [
          ExFlow.Command,
          ExFlow.Commands.CreateNodeCommand,
          ExFlow.Commands.CreateEdgeCommand,
          ExFlow.Commands.DeleteNodeCommand,
          ExFlow.Commands.DeleteEdgeCommand,
          ExFlow.Commands.MoveNodeCommand
        ],
        "Storage": [
          ExFlow.Storage,
          ExFlow.Storage.InMemory
        ],
        "Components": [
          ExFlowGraphWeb.ExFlow.Canvas,
          ExFlowGraphWeb.ExFlow.Node,
          ExFlowGraphWeb.ExFlow.Edge
        ]
      ],
      before_closing_body_tag: &before_closing_body_tag/1
    ]
  end

  defp before_closing_body_tag(:html) do
    """
    <script>
      // Add any custom JavaScript for docs here
    </script>
    """
  end

  defp before_closing_body_tag(_), do: ""
end
