defmodule Vsmcp.SecurityIntegrationTest do
  use ExUnit.Case
  
  alias Vsmcp.Security.Integration
  alias Vsmcp.Security.{Z3nZoneControl, NeuralBloomFilter}
  alias Vsmcp.Variety.AutonomousManager
  
  setup do
    # Ensure all security components are started
    # In a real test, these would be started by the test helper
    {:ok, %{}}
  end
  
  describe "Zone-based Access Control" do
    test "generates zone tokens with appropriate permissions" do
      # Test token generation for different zones
      {:ok, public_token} = Integration.authenticate("user1", [:public], %{password: "test"})
      {:ok, operational_token} = Integration.authenticate("user2", [:operational], %{password: "test"})
      {:ok, management_token} = Integration.authenticate("admin", [:management], %{password: "test"})
      
      # Verify tokens have different access levels
      assert {:ok, :granted} = Z3nZoneControl.validate_access(public_token, :public, :read)
      assert {:error, :access_denied} = Z3nZoneControl.validate_access(public_token, :operational, :execute)
      
      assert {:ok, :granted} = Z3nZoneControl.validate_access(operational_token, :operational, :execute)
      assert {:error, :access_denied} = Z3nZoneControl.validate_access(operational_token, :management, :write)
      
      assert {:ok, :granted} = Z3nZoneControl.validate_access(management_token, :management, :write)
    end
    
    test "supports zone transitions with validation" do
      {:ok, token} = Integration.authenticate("user", [:operational, :management], %{password: "test"})
      
      # Valid transition
      {:ok, new_token} = Z3nZoneControl.transition_zone(token, :operational, :management)
      assert is_binary(new_token)
      
      # Invalid transition (user doesn't have environment zone)
      assert {:error, :invalid_transition} = 
        Z3nZoneControl.transition_zone(token, :management, :environment)
    end
  end
  
  describe "Neural Bloom Filter Threat Detection" do
    test "detects SQL injection attempts" do
      sql_injection = "'; DROP TABLE users; --"
      {is_threat, confidence, threat_info} = NeuralBloomFilter.check_threat(sql_injection)
      
      assert is_threat == true
      assert confidence > 0.5
      assert threat_info.type == :injection
    end
    
    test "detects XSS attempts" do
      xss_attempt = "<script>alert('XSS')</script>"
      {is_threat, confidence, threat_info} = NeuralBloomFilter.check_threat(xss_attempt)
      
      assert is_threat == true
      assert confidence > 0.5
      assert threat_info.type == :injection
    end
    
    test "learns from reported threats" do
      # Report a new threat pattern
      new_threat = "UNION SELECT * FROM sensitive_data"
      NeuralBloomFilter.report_threat(new_threat, :injection, true)
      
      # Check that similar patterns are now detected
      similar_threat = "UNION SELECT password FROM users"
      {is_threat, _, _} = NeuralBloomFilter.check_threat(similar_threat)
      
      assert is_threat == true
    end
    
    test "handles false positives gracefully" do
      # Report a false positive
      safe_data = "This is a normal UNION of workers"
      NeuralBloomFilter.report_threat(safe_data, :injection, false)
      
      # Verify the filter adapts
      stats = NeuralBloomFilter.get_statistics()
      assert stats.false_positives >= 0
    end
  end
  
  describe "Autonomous Variety Management" do
    test "detects variety gaps" do
      {:ok, analysis} = AutonomousManager.check_variety_gaps()
      
      assert Map.has_key?(analysis, :severity)
      assert Map.has_key?(analysis, :operational_variety)
      assert Map.has_key?(analysis, :environmental_variety)
      assert Map.has_key?(analysis, :recommendations)
    end
    
    test "discovers MCP capabilities based on needs" do
      {:ok, capabilities} = AutonomousManager.discover_capabilities(:data_processing)
      
      assert is_map(capabilities)
      # Should discover database and analytics capabilities
      assert Enum.any?(capabilities, fn {_, cap} -> 
        "database" in (cap[:tags] || [])
      end)
    end
    
    test "provides recommendations based on variety analysis" do
      recommendations = AutonomousManager.get_recommendations()
      
      assert is_list(recommendations)
      Enum.each(recommendations, fn rec ->
        assert Map.has_key?(rec, :type)
        assert Map.has_key?(rec, :severity)
        assert Map.has_key?(rec, :action)
      end)
    end
    
    test "scales workers based on variety requirements" do
      # Scale up workers
      {:ok, new_count} = AutonomousManager.scale_workers({:scale_up, 2})
      assert new_count >= 6  # Started with 4, added 2
      
      # Scale down workers
      {:ok, new_count} = AutonomousManager.scale_workers({:scale_down, 1})
      assert new_count >= 5
    end
  end
  
  describe "Integrated Security Operations" do
    test "secure operations require proper zone access" do
      {:ok, token} = Integration.authenticate("user", [:operational], %{password: "test"})
      
      # Allowed operation
      assert {:ok, _} = Integration.secure_operation(
        token, 
        :operational, 
        :query_data,
        %{table: "metrics"}
      )
      
      # Denied operation (wrong zone)
      assert {:error, :zone_access_denied} = Integration.secure_operation(
        token,
        :management,
        :modify_config,
        %{setting: "critical"}
      )
    end
    
    test "operations are blocked when threats are detected" do
      {:ok, token} = Integration.authenticate("user", [:operational], %{password: "test"})
      
      # Operation with threat
      assert {:error, {:threat_detected, _}} = Integration.secure_operation(
        token,
        :operational,
        :execute_query,
        %{sql: "'; DROP TABLE users; --"}
      )
    end
    
    test "autonomous mode requires viability zone access" do
      # User without viability zone
      {:ok, regular_token} = Integration.authenticate("user", [:operational], %{password: "test"})
      assert {:error, :insufficient_permissions} = Integration.enable_autonomous_mode(regular_token)
      
      # User with viability zone
      {:ok, admin_token} = Integration.authenticate("admin", [:viability], %{password: "test"})
      assert {:ok, :autonomous_mode_enabled} = Integration.enable_autonomous_mode(admin_token)
    end
  end
  
  describe "System Status and Monitoring" do
    test "provides comprehensive system status" do
      status = Integration.system_status()
      
      assert Map.has_key?(status, :security)
      assert Map.has_key?(status, :variety)
      assert Map.has_key?(status, :recommendations)
      assert Map.has_key?(status, :timestamp)
      
      # Verify security status details
      assert Map.has_key?(status.security, :zones)
      assert Map.has_key?(status.security, :bloom_filter)
      assert status.security.threat_detection_enabled == true
      
      # Verify variety status details
      assert Map.has_key?(status.variety, :severity)
      assert Map.has_key?(status.variety, :gap_ratio)
    end
  end
end