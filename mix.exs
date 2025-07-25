defmodule Vsmcp.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :vsmcp,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      
      # Documentation
      name: "VSMCP",
      source_url: "https://github.com/viable-systems/vsmcp",
      homepage_url: "https://vsmcp.org",
      docs: [
        main: "readme",
        extras: [
          "README.md",
          "ARCHITECTURE.md",
          "CONTRIBUTING.md",
          "CHANGELOG.md": [title: "Changelog"],
          "LICENSE.md": [title: "License"]
        ],
        groups_for_modules: [
          "Core Systems": [
            Vsmcp,
            Vsmcp.Application,
            Vsmcp.Core.VarietyCalculator
          ],
          "VSM Systems": [
            Vsmcp.Systems.System1,
            Vsmcp.Systems.System2,
            Vsmcp.Systems.System3,
            Vsmcp.Systems.System4,
            Vsmcp.Systems.System5
          ],
          "Consciousness": [
            Vsmcp.Consciousness.Interface
          ],
          "MCP Integration": [
            Vsmcp.MCP.Server,
            Vsmcp.MCP.Client,
            Vsmcp.MCP.Protocol,
            Vsmcp.MCP.CapabilityRegistry,
            Vsmcp.MCP.ToolRegistry
          ],
          "AMQP Nervous System": [
            Vsmcp.AMQP.NervousSystem,
            Vsmcp.AMQP.ConnectionPool,
            Vsmcp.AMQP.ChannelManager
          ],
          "CRDT Support": [
            Vsmcp.CRDT.ContextStore,
            Vsmcp.CRDT.Types.ORSet,
            Vsmcp.CRDT.Types.GCounter,
            Vsmcp.CRDT.Types.PNCounter
          ],
          "Security": [
            Vsmcp.Security.NeuralBloomFilter,
            Vsmcp.Security.Z3nZoneControl
          ],
          "Variety Management": [
            Vsmcp.Variety.AutonomousManager
          ],
          "Integration": [
            Vsmcp.Integration.Manager
          ]
        ],
        groups_for_extras: [
          "Documentation": ["README.md", "ARCHITECTURE.md"],
          "Guides": ["CONTRIBUTING.md"],
          "Meta": ["CHANGELOG.md", "LICENSE.md"]
        ],
        api_reference: true,
        source_ref: "v#{@version}",
        formatters: ["html"]
      ],
      
      # Package information
      package: [
        description: "Viable System Model with Model Context Protocol - A cybernetic control system",
        licenses: ["MIT"],
        links: %{
          "GitHub" => "https://github.com/viable-systems/vsmcp",
          "Docs" => "https://hexdocs.pm/vsmcp"
        },
        files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Vsmcp.Application, []},
      extra_applications: [:logger, :runtime_tools, :crypto, :ssl, :inets, :mnesia]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Core dependencies
      {:amqp, "~> 3.3"},
      {:phoenix_pubsub, "~> 2.1"},
      {:gen_stage, "~> 1.2"},
      {:poolboy, "~> 1.5"},
      
      # Phoenix Framework
      {:phoenix, "~> 1.7.10"},
      {:phoenix_html, "~> 3.3"},
      {:phoenix_live_reload, "~> 1.4", only: :dev},
      {:phoenix_live_view, "~> 0.20.1"},
      {:phoenix_live_dashboard, "~> 0.8.2"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2.0", runtime: Mix.env() == :dev},
      {:gettext, "~> 0.20"},
      
      # Networking and protocols
      {:ranch, "~> 2.1"},
      {:cowboy, "~> 2.10"},
      {:plug, "~> 1.15"},
      {:plug_cowboy, "~> 2.6"},
      {:websockex, "~> 0.4.3"},
      {:httpoison, "~> 2.2"},
      
      # Data serialization
      {:jason, "~> 1.4"},
      {:protobuf, "~> 0.11"},
      
      # Telegram integration
      {:ex_gram, "~> 0.40"},
      {:finch, "~> 0.16"},
      
      # Telemetry and monitoring
      {:telemetry, "~> 1.2"},
      {:telemetry_poller, "~> 1.0"},
      {:telemetry_metrics, "~> 1.0"},
      
      # Database
      {:ecto, "~> 3.11"},
      {:ecto_sql, "~> 3.11"},
      {:postgrex, "~> 0.17"},
      
      # Release management
      {:distillery, "~> 2.1"},
      
      # Development and testing
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:mock, "~> 0.3", only: :test},
      {:stream_data, "~> 0.6", only: [:dev, :test]}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build", "compile"],
      test: ["test"],
      quality: ["format", "credo --strict", "dialyzer"],
      docs: ["docs --formatter html", "docs.open"],
      "docs.open": ["docs", "cmd open doc/index.html"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"],
      
      # Release tasks
      "release.init": ["distillery.init"],
      "release.build": ["compile", "distillery.release"],
      "release.upgrade": ["compile", "distillery.release --upgrade"],
      "release.clean": ["distillery.release.clean"],
      
      # Database tasks
      "db.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "db.reset": ["ecto.drop", "db.setup"]
    ]
  end
end
