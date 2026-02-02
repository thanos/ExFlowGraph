defmodule ExFlowGraph.MixProject do
  use Mix.Project

  alias ExFlow.Commands.CreateEdgeCommand
  alias ExFlow.Commands.CreateNodeCommand
  alias ExFlow.Commands.DeleteEdgeCommand
  alias ExFlow.Commands.DeleteNodeCommand
  alias ExFlow.Commands.MoveNodeCommand
  alias ExFlow.Core.Graph
  alias ExFlow.Storage.InMemory
  alias ExFlowGraphWeb.ExFlow.Canvas
  alias ExFlowGraphWeb.ExFlow.Edge

  def project do
    [
      app: :ex_flow_graph,
      version: "0.1.0",
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: "Interactive flow graph component library for Phoenix LiveView",

      # Docs
      name: "ExFlowGraph",
      source_url: "https://github.com/thanos/ExFlowGraph",
      homepage_url: "https://github.com/thanos/ExFlowGraph",
      docs: docs(),

      # Test coverage
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ],

      # Dialyzer
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:ex_unit, :mix],
        flags: [:error_handling, :underspecs, :unmatched_returns]
      ]
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
      {:gettext, "~> 1.0.2"},
      # for dev
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.14.1", only: [:dev, :test]},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:quokka, "~> 2.11", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      files:
        ~w(lib priv assets .formatter.exs mix.exs README* LICENSE INSTALLATION.md CHANGELOG.md guides),
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/thanos/ExFlowGraph",
        "Changelog" => "https://github.com/thanos/ExFlowGraph/blob/main/CHANGELOG.md"
      },
      maintainers: ["Thanos Vassilakis"]
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
        Reference: ~r/guides\/events-and-callbacks/,
        Features: ~r/guides\/(labels-and-metadata|option-click-events|undo-redo)/,
        Advanced: ~r/guides\/customization/
      ],
      groups_for_modules: [
        Core: [
          Graph,
          ExFlow.HistoryManager
        ],
        Commands: [
          ExFlow.Command,
          CreateNodeCommand,
          CreateEdgeCommand,
          DeleteNodeCommand,
          DeleteEdgeCommand,
          MoveNodeCommand
        ],
        Storage: [
          ExFlow.Storage,
          InMemory
        ],
        Components: [
          Canvas,
          ExFlowGraphWeb.ExFlow.Node,
          Edge
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
