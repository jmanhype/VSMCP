defmodule Vsmcp.AMQP.Consumers.System3Consumer do
  @moduledoc """
  System 3 consumer for audit and monitoring messages.
  
  System 3 is responsible for:
  - Monitoring all operational activities
  - Ensuring compliance with policies
  - Detecting anomalies and deviations
  - Triggering algedonic signals when necessary
  """
  use Vsmcp.AMQP.Consumers.BaseConsumer, system: :system3
  
  alias Vsmcp.AMQP.Producers.BaseProducer
  alias Vsmcp.Systems.System3
  
  @audit_threshold 0.8  # Threshold for triggering algedonic signals
  @compliance_check_interval 60_000  # 1 minute

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)
    
    # Initialize state
    state = %__MODULE__{
      system: :system3,
      subscriptions: opts[:subscriptions] || default_subscriptions(),
      consumer_tags: %{},
      message_handler: opts[:message_handler] || self()
    }
    
    # Schedule periodic compliance checks
    Process.send_after(self(), :compliance_check, @compliance_check_interval)
    
    # Setup consumers
    send(self(), :setup_consumers)
    
    {:ok, state}
  end

  @impl true
  def handle_info(:compliance_check, state) do
    perform_compliance_check()
    Process.send_after(self(), :compliance_check, @compliance_check_interval)
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("System3Consumer received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Queue subscriptions for System 3
  defp default_subscriptions do
    [
      "vsm.system3.command",
      "vsm.system3.audit.all",
      "vsm.system3.algedonic"
    ]
  end

  @impl true
  def handle_command(command, metadata) do
    Logger.info("System 3 processing command: #{command.type}")
    
    case command.type do
      "audit_request" ->
        perform_audit(command.target, command.scope)
      
      "compliance_check" ->
        check_compliance(command.policy, command.target)
      
      "anomaly_investigation" ->
        investigate_anomaly(command.anomaly_data)
      
      _ ->
        Logger.warn("System 3 received unknown command type: #{command.type}")
    end
    
    :ok
  end

  @impl true
  def handle_audit(audit, _metadata) do
    Logger.debug("System 3 received audit data from #{audit.system}")
    
    # Store audit data
    System3.store_audit(audit)
    
    # Analyze for anomalies
    case analyze_audit(audit) do
      {:anomaly, severity} when severity > @audit_threshold ->
        # Trigger algedonic signal
        signal = %{
          type: "audit_anomaly",
          intensity: round(severity * 100),
          source: audit.system,
          details: audit
        }
        
        # Send to System 5 (policy) and System 2 (coordination)
        BaseProducer.send_algedonic(:system3, :system5, signal)
        BaseProducer.send_algedonic(:system3, :system2, signal)
        
      {:warning, details} ->
        # Log warning but don't escalate
        Logger.warn("System 3 audit warning: #{inspect(details)}")
        
      :ok ->
        # Normal audit, no action needed
        :ok
    end
    
    :ok
  end

  @impl true
  def handle_algedonic(signal, _metadata) do
    Logger.warn("System 3 received algedonic signal: #{signal.type} (intensity: #{signal.intensity})")
    
    # System 3 must investigate all algedonic signals
    case signal.type do
      "performance_critical" ->
        # Immediate audit of the source system
        perform_emergency_audit(signal.from, signal.details)
      
      "resource_exhaustion" ->
        # Check resource allocation compliance
        check_resource_compliance(signal.from)
      
      _ ->
        # Log and monitor
        System3.log_algedonic_signal(signal)
    end
    
    :ok
  end

  # Private functions

  defp perform_audit(target, scope) do
    Logger.info("System 3 performing audit on #{target} with scope: #{scope}")
    
    # Collect audit data from target
    audit_data = System3.collect_audit_data(target, scope)
    
    # Generate audit report
    report = %{
      target: target,
      scope: scope,
      findings: audit_data.findings,
      compliance_status: audit_data.compliance_status,
      recommendations: generate_recommendations(audit_data),
      timestamp: DateTime.utc_now()
    }
    
    # Send report to System 2 and System 5
    BaseProducer.send_command(:system3, :system2, %{
      type: "audit_report",
      report: report
    })
    
    BaseProducer.send_command(:system3, :system5, %{
      type: "audit_report",
      report: report
    })
    
    :ok
  end

  defp check_compliance(policy, target) do
    compliance_result = System3.check_policy_compliance(policy, target)
    
    if not compliance_result.compliant do
      # Non-compliance detected, escalate
      BaseProducer.send_algedonic(:system3, :system5, %{
        type: "compliance_violation",
        intensity: compliance_severity(compliance_result),
        policy: policy,
        target: target,
        violations: compliance_result.violations
      })
    end
    
    :ok
  end

  defp investigate_anomaly(anomaly_data) do
    investigation_result = System3.investigate_anomaly(anomaly_data)
    
    case investigation_result.severity do
      :critical ->
        # Immediate escalation
        BaseProducer.send_algedonic(:system3, :system5, %{
          type: "critical_anomaly",
          intensity: 255,
          details: investigation_result
        })
      
      :high ->
        # Report to System 2 for coordination
        BaseProducer.send_command(:system3, :system2, %{
          type: "anomaly_report",
          severity: :high,
          details: investigation_result
        })
      
      _ ->
        # Log and continue monitoring
        Logger.info("System 3 anomaly investigation completed: #{investigation_result.severity}")
    end
    
    :ok
  end

  defp perform_compliance_check do
    # Regular compliance check across all systems
    systems = [:system1, :system2, :system4]
    
    Enum.each(systems, fn system ->
      BaseProducer.send_command(:system3, system, %{
        type: "compliance_status_request",
        check_id: generate_check_id()
      })
    end)
  end

  defp analyze_audit(audit) do
    # Analyze audit data for anomalies
    metrics = audit[:metrics] || %{}
    
    cond do
      metrics[:error_rate] > 0.5 ->
        {:anomaly, metrics[:error_rate]}
      
      metrics[:response_time] > 5000 ->
        {:warning, %{type: :slow_response, value: metrics[:response_time]}}
      
      metrics[:resource_usage] > 0.9 ->
        {:anomaly, metrics[:resource_usage]}
      
      true ->
        :ok
    end
  end

  defp perform_emergency_audit(system, details) do
    Logger.error("System 3 performing emergency audit on #{system}")
    
    BaseProducer.send_command(:system3, system, %{
      type: "emergency_audit",
      priority: :emergency,
      reason: details
    }, :emergency)
  end

  defp check_resource_compliance(system) do
    BaseProducer.send_command(:system3, system, %{
      type: "resource_audit",
      priority: :urgent
    }, :urgent)
  end

  defp generate_recommendations(audit_data) do
    # Generate recommendations based on audit findings
    audit_data.findings
    |> Enum.filter(& &1.severity in [:high, :critical])
    |> Enum.map(fn finding ->
      %{
        issue: finding.issue,
        recommendation: recommendation_for(finding),
        priority: finding.severity
      }
    end)
  end

  defp recommendation_for(finding) do
    case finding.type do
      :performance -> "Optimize resource allocation and review system capacity"
      :compliance -> "Update procedures to align with policy requirements"
      :security -> "Implement additional security controls"
      _ -> "Review and address the identified issue"
    end
  end

  defp compliance_severity(result) do
    violation_count = length(result.violations)
    
    cond do
      violation_count > 10 -> 255
      violation_count > 5 -> 200
      violation_count > 2 -> 150
      true -> 100
    end
  end

  defp generate_check_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16()
  end
end