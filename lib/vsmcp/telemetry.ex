# Path: lib/vsmcp/telemetry.ex
defmodule Vsmcp.Telemetry do
  @moduledoc """
  Telemetry setup for VSMCP system monitoring.
  """
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # VSM System Metrics
      counter("vsmcp.system1.operations.count"),
      counter("vsmcp.system1.operations.success"),
      counter("vsmcp.system1.operations.failure"),
      
      counter("vsmcp.system2.coordinations.count"),
      counter("vsmcp.system2.conflicts.resolved"),
      
      counter("vsmcp.system3.optimizations.count"),
      counter("vsmcp.system3.audits.count"),
      
      counter("vsmcp.system4.scans.count"),
      counter("vsmcp.system4.predictions.count"),
      counter("vsmcp.system4.adaptations.suggested"),
      
      counter("vsmcp.system5.decisions.count"),
      counter("vsmcp.system5.policies.updated"),
      
      # Variety Metrics
      last_value("vsmcp.variety.operational"),
      last_value("vsmcp.variety.environmental"),
      last_value("vsmcp.variety.gap"),
      
      # MCP Metrics
      counter("vsmcp.mcp.discoveries.count"),
      counter("vsmcp.mcp.integrations.success"),
      counter("vsmcp.mcp.integrations.failure"),
      
      # Consciousness Metrics
      counter("vsmcp.consciousness.reflections.count"),
      counter("vsmcp.consciousness.learnings.count"),
      
      # System Metrics
      last_value("vm.memory.total", unit: :byte),
      last_value("vm.total_run_queue_lengths.total"),
      last_value("vm.total_run_queue_lengths.cpu"),
      last_value("vm.total_run_queue_lengths.io")
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must return a list of Telemetry events.
      {Vsmcp.Telemetry, :emit_variety_metrics, []},
      {Vsmcp.Telemetry, :emit_system_metrics, []}
    ]
  end

  def emit_variety_metrics do
    case Vsmcp.Core.VarietyCalculator.current_state() do
      %{operational_variety: op, environmental_variety: env} ->
        :telemetry.execute(
          [:vsmcp, :variety],
          %{
            operational: op,
            environmental: env,
            gap: env - op
          },
          %{}
        )
      _ ->
        :ok
    end
  end

  def emit_system_metrics do
    # Emit VM metrics
    memory = :erlang.memory()
    
    :telemetry.execute(
      [:vm, :memory],
      %{total: memory[:total]},
      %{}
    )
    
    :telemetry.execute(
      [:vm, :total_run_queue_lengths],
      %{
        total: :erlang.statistics(:run_queue_lengths) |> Enum.sum(),
        cpu: :erlang.statistics(:run_queue_lengths) |> Enum.sum(),
        io: 0
      },
      %{}
    )
  end
end