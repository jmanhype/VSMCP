defmodule Vsmcp.AMQP.Producers.BaseProducer do
  @moduledoc """
  Base producer module for sending messages through the VSM nervous system.
  
  Provides common functionality for all VSM system producers.
  """
  
  alias Vsmcp.AMQP.{ChannelManager, Config.ExchangeConfig}
  require Logger

  @doc """
  Send a command through the command channel
  """
  def send_command(from_system, to_system, command, priority \\ :normal) do
    routing_key = "#{to_system}.#{level_for_systems(from_system, to_system)}.#{command.type}"
    
    message = %{
      from: from_system,
      to: to_system,
      command: command,
      timestamp: DateTime.utc_now(),
      correlation_id: generate_correlation_id()
    }
    
    options = [
      priority: priority_value(priority),
      headers: [
        {"x-from-system", :longstr, to_string(from_system)},
        {"x-to-system", :longstr, to_string(to_system)},
        {"x-command-type", :longstr, command.type}
      ]
    ]
    
    publish(:command, "vsm.command", routing_key, message, options)
  end

  @doc """
  Send an audit message
  """
  def send_audit(system, audit_data) do
    message = %{
      system: system,
      audit: audit_data,
      timestamp: DateTime.utc_now(),
      correlation_id: generate_correlation_id()
    }
    
    publish(:audit, "vsm.audit", "", message)
  end

  @doc """
  Send an algedonic signal (pain/pleasure)
  """
  def send_algedonic(from_system, to_system, signal) do
    message = %{
      from: from_system,
      to: to_system,
      signal: signal,
      timestamp: DateTime.utc_now(),
      correlation_id: generate_correlation_id()
    }
    
    options = [
      priority: ExchangeConfig.message_priorities().algedonic,
      expiration: "60000",  # 1 minute TTL
      headers: [
        {"x-signal-type", :longstr, signal.type},
        {"x-signal-intensity", :long, signal.intensity}
      ]
    ]
    
    publish(:algedonic, "vsm.algedonic", to_string(to_system), message, options)
  end

  @doc """
  Send a horizontal message between System 1 units
  """
  def send_horizontal(from_unit, region, message_type, data) do
    routing_key = "#{from_unit}.#{region}.#{message_type}"
    
    message = %{
      from_unit: from_unit,
      region: region,
      type: message_type,
      data: data,
      timestamp: DateTime.utc_now(),
      correlation_id: generate_correlation_id()
    }
    
    publish(:horizontal, "vsm.horizontal", routing_key, message)
  end

  @doc """
  Send intelligence data
  """
  def send_intel(source, intel_type, urgency, data) do
    routing_key = "#{source}.#{intel_type}.#{urgency}"
    
    message = %{
      source: source,
      type: intel_type,
      urgency: urgency,
      data: data,
      timestamp: DateTime.utc_now(),
      correlation_id: generate_correlation_id()
    }
    
    options = [
      priority: intel_priority(urgency),
      headers: [
        {"x-intel-source", :longstr, to_string(source)},
        {"x-intel-type", :longstr, to_string(intel_type)}
      ]
    ]
    
    publish(:intel, "vsm.intel", routing_key, message, options)
  end

  # Private functions

  defp publish(channel_type, exchange, routing_key, message, options \\ []) do
    case ChannelManager.publish(channel_type, exchange, routing_key, message, options) do
      :ok ->
        Logger.debug("Published to #{exchange} with key #{routing_key}")
        :ok
      
      error ->
        Logger.error("Failed to publish to #{exchange}: #{inspect(error)}")
        error
    end
  end

  defp generate_correlation_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16()
  end

  defp level_for_systems(from, to) do
    cond do
      # Same level communication
      same_level?(from, to) -> "tactical"
      
      # Upward communication (operational to strategic)
      operational_to_strategic?(from, to) -> "strategic"
      
      # Downward communication (strategic to operational)
      true -> "operational"
    end
  end

  defp same_level?(from, to) do
    {from_level, _} = parse_system(from)
    {to_level, _} = parse_system(to)
    from_level == to_level
  end

  defp operational_to_strategic?(from, to) do
    from_num = system_number(from)
    to_num = system_number(to)
    from_num < to_num
  end

  defp parse_system(system) when is_atom(system) do
    system_str = to_string(system)
    if String.starts_with?(system_str, "system") do
      num = String.replace(system_str, "system", "") |> String.to_integer()
      {:system, num}
    else
      {:unknown, 0}
    end
  end

  defp system_number(system) do
    {_, num} = parse_system(system)
    num
  end

  defp priority_value(priority) do
    priorities = ExchangeConfig.message_priorities()
    
    case priority do
      :algedonic -> priorities.algedonic
      :emergency -> priorities.emergency
      :urgent -> priorities.command_urgent
      :normal -> priorities.command_normal
      :low -> priorities.horizontal
      value when is_integer(value) -> value
      _ -> priorities.command_normal
    end
  end

  defp intel_priority(urgency) do
    priorities = ExchangeConfig.message_priorities()
    
    case urgency do
      :urgent -> priorities.intel_urgent
      :routine -> priorities.intel_routine
      _ -> priorities.intel_routine
    end
  end
end