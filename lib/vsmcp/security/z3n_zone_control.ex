defmodule Vsmcp.Security.Z3nZoneControl do
  @moduledoc """
  Z3N Zone-based Access Control System
  
  Implements hierarchical zone-based security with:
  - Zone definitions and boundaries
  - Access control policies per zone
  - JWT token generation with zone claims
  - Zone transition validation
  """
  
  use GenServer
  require Logger
  
  @type zone :: :public | :operational | :management | :environment | :viability
  @type permission :: :read | :write | :execute | :delegate
  @type zone_config :: %{
    zone: zone(),
    permissions: [permission()],
    parent: zone() | nil,
    children: [zone()],
    policies: map()
  }
  
  # Zone hierarchy based on VSM model
  @zone_hierarchy %{
    public: %{
      level: 0,
      parent: nil,
      children: [:operational],
      default_permissions: [:read]
    },
    operational: %{
      level: 1,
      parent: :public,
      children: [:management],
      default_permissions: [:read, :execute]
    },
    management: %{
      level: 2,
      parent: :operational,
      children: [:environment],
      default_permissions: [:read, :write, :execute]
    },
    environment: %{
      level: 3,
      parent: :management,
      children: [:viability],
      default_permissions: [:read, :write, :execute]
    },
    viability: %{
      level: 4,
      parent: :environment,
      children: [],
      default_permissions: [:read, :write, :execute, :delegate]
    }
  }
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def validate_access(token, zone, permission) do
    GenServer.call(__MODULE__, {:validate_access, token, zone, permission})
  end
  
  def generate_zone_token(user_id, zones, permissions \\ []) do
    GenServer.call(__MODULE__, {:generate_token, user_id, zones, permissions})
  end
  
  def transition_zone(token, from_zone, to_zone) do
    GenServer.call(__MODULE__, {:transition_zone, token, from_zone, to_zone})
  end
  
  def get_zone_hierarchy do
    @zone_hierarchy
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    # Initialize JWT secret from config or generate
    secret = Application.get_env(:vsmcp, :z3n_secret) || generate_secret()
    
    {:ok, %{
      secret: secret,
      active_tokens: %{},
      zone_policies: initialize_zone_policies(),
      transition_log: []
    }}
  end
  
  @impl true
  def handle_call({:validate_access, token, zone, permission}, _from, state) do
    case validate_token(token, state.secret) do
      {:ok, claims} ->
        result = check_zone_permission(claims, zone, permission)
        {:reply, result, state}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:generate_token, user_id, zones, permissions}, _from, state) do
    # Validate requested zones
    validated_zones = validate_zone_request(zones)
    
    claims = %{
      "sub" => user_id,
      "zones" => validated_zones,
      "permissions" => permissions ++ get_default_permissions(validated_zones),
      "iat" => System.system_time(:second),
      "exp" => System.system_time(:second) + 3600, # 1 hour
      "zone_transitions" => []
    }
    
    token = generate_jwt(claims, state.secret)
    
    # Track active token
    new_state = put_in(state.active_tokens[token], %{
      user_id: user_id,
      created_at: DateTime.utc_now(),
      zones: validated_zones
    })
    
    {:reply, {:ok, token}, new_state}
  end
  
  @impl true
  def handle_call({:transition_zone, token, from_zone, to_zone}, _from, state) do
    case validate_token(token, state.secret) do
      {:ok, claims} ->
        if valid_transition?(from_zone, to_zone, claims) do
          # Update token with transition
          updated_claims = Map.update(claims, "zone_transitions", [], fn transitions ->
            transitions ++ [%{
              "from" => from_zone,
              "to" => to_zone,
              "at" => System.system_time(:second)
            }]
          end)
          
          new_token = generate_jwt(updated_claims, state.secret)
          
          # Log transition
          new_state = update_in(state.transition_log, fn log ->
            log ++ [%{
              user_id: claims["sub"],
              from: from_zone,
              to: to_zone,
              timestamp: DateTime.utc_now()
            }]
          end)
          
          {:reply, {:ok, new_token}, new_state}
        else
          {:reply, {:error, :invalid_transition}, state}
        end
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  # Private Functions
  
  defp generate_secret do
    :crypto.strong_rand_bytes(32) |> Base.encode64()
  end
  
  defp initialize_zone_policies do
    # Define specific policies for each zone
    %{
      public: %{
        max_requests_per_minute: 60,
        allowed_operations: [:read],
        data_access: :limited
      },
      operational: %{
        max_requests_per_minute: 300,
        allowed_operations: [:read, :execute],
        data_access: :operational
      },
      management: %{
        max_requests_per_minute: 600,
        allowed_operations: [:read, :write, :execute],
        data_access: :full
      },
      environment: %{
        max_requests_per_minute: 1000,
        allowed_operations: [:read, :write, :execute, :monitor],
        data_access: :full
      },
      viability: %{
        max_requests_per_minute: :unlimited,
        allowed_operations: [:all],
        data_access: :full
      }
    }
  end
  
  defp validate_zone_request(zones) do
    zones
    |> Enum.filter(fn zone -> Map.has_key?(@zone_hierarchy, zone) end)
    |> Enum.uniq()
  end
  
  defp get_default_permissions(zones) do
    zones
    |> Enum.flat_map(fn zone ->
      @zone_hierarchy[zone][:default_permissions] || []
    end)
    |> Enum.uniq()
  end
  
  defp check_zone_permission(claims, requested_zone, requested_permission) do
    user_zones = claims["zones"] || []
    user_permissions = claims["permissions"] || []
    
    # Check if user has access to the zone
    has_zone_access = Enum.any?(user_zones, fn user_zone ->
      user_zone == requested_zone || zone_includes?(user_zone, requested_zone)
    end)
    
    # Check if user has the permission
    has_permission = requested_permission in user_permissions
    
    if has_zone_access && has_permission do
      {:ok, :granted}
    else
      {:error, :access_denied}
    end
  end
  
  defp zone_includes?(parent_zone, child_zone) do
    # Check if parent zone includes child zone in hierarchy
    case @zone_hierarchy[parent_zone] do
      nil -> false
      zone_info ->
        child_zone in zone_info.children || 
        Enum.any?(zone_info.children, fn child ->
          zone_includes?(child, child_zone)
        end)
    end
  end
  
  defp valid_transition?(from_zone, to_zone, claims) do
    user_zones = claims["zones"] || []
    
    # User must have access to both zones
    has_from = from_zone in user_zones
    has_to = to_zone in user_zones
    
    # Check if transition follows hierarchy rules
    from_level = @zone_hierarchy[from_zone][:level]
    to_level = @zone_hierarchy[to_zone][:level]
    
    # Can only transition to adjacent levels or same level
    level_diff = abs(from_level - to_level)
    
    has_from && has_to && level_diff <= 1
  end
  
  defp generate_jwt(claims, secret) do
    # In production, use proper JWT library like Joken
    # This is simplified for demonstration
    header = %{"alg" => "HS256", "typ" => "JWT"}
    
    header_json = Jason.encode!(header)
    claims_json = Jason.encode!(claims)
    
    payload = "#{Base.url_encode64(header_json, padding: false)}.#{Base.url_encode64(claims_json, padding: false)}"
    signature = :crypto.mac(:hmac, :sha256, secret, payload) |> Base.url_encode64(padding: false)
    
    "#{payload}.#{signature}"
  end
  
  defp validate_token(token, secret) do
    # Simplified JWT validation
    case String.split(token, ".") do
      [header_b64, claims_b64, signature_b64] ->
        payload = "#{header_b64}.#{claims_b64}"
        expected_signature = :crypto.mac(:hmac, :sha256, secret, payload) |> Base.url_encode64(padding: false)
        
        if signature_b64 == expected_signature do
          claims = claims_b64 |> Base.url_decode64!(padding: false) |> Jason.decode!()
          
          # Check expiration
          if claims["exp"] > System.system_time(:second) do
            {:ok, claims}
          else
            {:error, :token_expired}
          end
        else
          {:error, :invalid_signature}
        end
        
      _ ->
        {:error, :invalid_token_format}
    end
  end
end