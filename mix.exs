defmodule Vsmcp.MixProject do
  use Mix.Project

  def project do
    [
      app: :vsmcp,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Vsmcp.Application, []},
      extra_applications: [:logger, :runtime_tools, :crypto, :ssl, :inets]
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
      
      # Telemetry and monitoring
      {:telemetry, "~> 1.2"},
      {:telemetry_poller, "~> 1.0"},
      {:telemetry_metrics, "~> 1.0"},
      
      # Database
      {:ecto, "~> 3.11"},
      {:ecto_sql, "~> 3.11"},
      {:postgrex, "~> 0.17"},
      
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
      setup: ["deps.get", "compile"],
      test: ["test"],
      quality: ["format", "credo --strict", "dialyzer"],
      docs: ["docs --formatter html"]
    ]
  end
end
