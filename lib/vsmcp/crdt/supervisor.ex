defmodule Vsmcp.CRDT.Supervisor do
  @moduledoc """
  Supervisor for CRDT subsystem components.
  Manages ContextStore, PubSub synchronization, and storage tiers.
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Phoenix.PubSub is already started in Application supervisor
      # so we don't need to start it here
      
      # Start the main ContextStore
      {Vsmcp.CRDT.ContextStore, 
        node_id: node(),
        storage_opts: [
          ets_name: :vsmcp_crdt_ets,
          dets_name: :vsmcp_crdt_dets,
          dets_file: "data/crdt_storage.dets"
        ]
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end