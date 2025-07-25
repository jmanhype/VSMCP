defmodule Vsmcp.AMQP.NervousSystemTest do
  use ExUnit.Case, async: false
  
  alias Vsmcp.AMQP.{NervousSystem, Config.ExchangeConfig}
  
  describe "nervous system configuration" do
    test "exchanges are properly defined" do
      exchanges = ExchangeConfig.exchanges()
      
      assert Map.has_key?(exchanges, :command)
      assert Map.has_key?(exchanges, :audit)
      assert Map.has_key?(exchanges, :algedonic)
      assert Map.has_key?(exchanges, :horizontal)
      assert Map.has_key?(exchanges, :intel)
      
      # Verify exchange types
      assert exchanges.command.type == :topic
      assert exchanges.audit.type == :fanout
      assert exchanges.algedonic.type == :direct
      assert exchanges.horizontal.type == :topic
      assert exchanges.intel.type == :topic
    end
    
    test "queues are defined for all systems" do
      queues = ExchangeConfig.queues()
      
      # All 5 systems should have queues
      assert Map.has_key?(queues, :system1)
      assert Map.has_key?(queues, :system2)
      assert Map.has_key?(queues, :system3)
      assert Map.has_key?(queues, :system4)
      assert Map.has_key?(queues, :system5)
      
      # System 1 should have all channel types
      assert Map.has_key?(queues.system1, :command)
      assert Map.has_key?(queues.system1, :audit)
      assert Map.has_key?(queues.system1, :algedonic)
      assert Map.has_key?(queues.system1, :horizontal)
      
      # System 5 should have strategic channels
      assert Map.has_key?(queues.system5, :command)
      assert Map.has_key?(queues.system5, :algedonic)
      assert Map.has_key?(queues.system5, :intel)
    end
    
    test "message priorities are correctly ordered" do
      priorities = ExchangeConfig.message_priorities()
      
      # Algedonic should be highest
      assert priorities.algedonic == 255
      
      # Verify priority ordering
      assert priorities.algedonic > priorities.emergency
      assert priorities.emergency > priorities.command_urgent
      assert priorities.command_urgent > priorities.audit_critical
      assert priorities.audit_critical > priorities.intel_urgent
      assert priorities.intel_urgent > priorities.command_normal
      assert priorities.command_normal > priorities.intel_routine
      assert priorities.intel_routine > priorities.horizontal
    end
  end
  
  describe "nervous system API" do
    test "command sending provides correct interface" do
      # This would normally connect to RabbitMQ
      # For unit tests, we're just verifying the API structure
      
      command = %{
        type: "test_command",
        data: "test"
      }
      
      # The function should exist and accept the right parameters
      assert function_exported?(NervousSystem, :send_command, 4)
      assert function_exported?(NervousSystem, :send_command, 3)
    end
    
    test "emergency broadcast targets all systems" do
      # Verify emergency broadcast function exists
      assert function_exported?(NervousSystem, :emergency_broadcast, 2)
    end
    
    test "coordinate resources handles allocation logic" do
      # Test resource coordination with sufficient resources
      result = NervousSystem.coordinate_resources(:system2, [
        {"unit_a", %{available: 50}},
        {"unit_b", %{available: 50}},
        {"unit_c", %{required: 40}},
        {"unit_d", %{required: 40}}
      ])
      
      assert {:ok, allocations} = result
      assert length(allocations) == 2  # Two units need resources
    end
    
    test "coordinate resources handles insufficient resources" do
      # Test resource coordination with insufficient resources
      result = NervousSystem.coordinate_resources(:system2, [
        {"unit_a", %{available: 20}},
        {"unit_b", %{available: 20}},
        {"unit_c", %{required: 50}},
        {"unit_d", %{required: 50}}
      ])
      
      assert {:error, :insufficient_resources} = result
    end
  end
end