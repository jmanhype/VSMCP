# Path: lib/vsmcp/integration/manager.ex
defmodule Vsmcp.Integration.Manager do
  @moduledoc """
  Manages integration of external capabilities into the VSM system.
  """
  use GenServer
  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def integrate_capability(capability) do
    GenServer.call(__MODULE__, {:integrate, capability})
  end

  def list_integrations do
    GenServer.call(__MODULE__, :list_integrations)
  end

  @impl true
  def init(_opts) do
    {:ok, %{
      integrations: [],
      active_capabilities: %{}
    }}
  end

  @impl true
  def handle_call({:integrate, capability}, _from, state) do
    Logger.info("Integration Manager: Integrating capability #{inspect(capability)}")
    
    # Add to integrations
    new_integrations = [capability | state.integrations]
    new_state = %{state | integrations: new_integrations}
    
    {:reply, {:ok, capability}, new_state}
  end

  @impl true
  def handle_call(:list_integrations, _from, state) do
    {:reply, state.integrations, state}
  end
end