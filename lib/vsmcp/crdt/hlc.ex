defmodule Vsmcp.CRDT.HLC do
  @moduledoc """
  Hybrid Logical Clock implementation for causality tracking in distributed systems.
  Combines physical timestamps with logical counters to ensure monotonicity and causality.
  """

  defstruct [:timestamp, :counter, :node_id]

  @type t :: %__MODULE__{
    timestamp: integer(),
    counter: non_neg_integer(),
    node_id: term()
  }

  @doc """
  Create a new HLC with the current time.
  """
  def new(node_id) do
    %__MODULE__{
      timestamp: System.system_time(:millisecond),
      counter: 0,
      node_id: node_id
    }
  end

  @doc """
  Update the HLC with a new event, ensuring monotonicity.
  """
  def tick(%__MODULE__{timestamp: last_ts, counter: last_counter, node_id: node_id}) do
    current_ts = System.system_time(:millisecond)
    
    {new_ts, new_counter} = 
      if current_ts > last_ts do
        {current_ts, 0}
      else
        {last_ts, last_counter + 1}
      end
    
    %__MODULE__{
      timestamp: new_ts,
      counter: new_counter,
      node_id: node_id
    }
  end

  @doc """
  Update the HLC upon receiving a message with another HLC.
  Ensures the new HLC is greater than both the local and remote HLCs.
  """
  def receive_event(%__MODULE__{} = local, %__MODULE__{} = remote) do
    current_ts = System.system_time(:millisecond)
    max_ts = Enum.max([current_ts, local.timestamp, remote.timestamp])
    
    new_counter = 
      cond do
        max_ts > local.timestamp and max_ts > remote.timestamp ->
          0
        max_ts == local.timestamp and max_ts == remote.timestamp ->
          max(local.counter, remote.counter) + 1
        max_ts == local.timestamp ->
          local.counter + 1
        max_ts == remote.timestamp ->
          remote.counter + 1
        true ->
          0
      end
    
    %__MODULE__{
      timestamp: max_ts,
      counter: new_counter,
      node_id: local.node_id
    }
  end

  @doc """
  Compare two HLCs. Returns :lt, :eq, or :gt.
  """
  def compare(%__MODULE__{} = hlc1, %__MODULE__{} = hlc2) do
    cond do
      hlc1.timestamp < hlc2.timestamp -> :lt
      hlc1.timestamp > hlc2.timestamp -> :gt
      hlc1.counter < hlc2.counter -> :lt
      hlc1.counter > hlc2.counter -> :gt
      hlc1.node_id < hlc2.node_id -> :lt
      hlc1.node_id > hlc2.node_id -> :gt
      true -> :eq
    end
  end

  @doc """
  Check if hlc1 happened before hlc2.
  """
  def before?(hlc1, hlc2) do
    compare(hlc1, hlc2) == :lt
  end

  @doc """
  Check if hlc1 happened after hlc2.
  """
  def after?(hlc1, hlc2) do
    compare(hlc1, hlc2) == :gt
  end

  @doc """
  Check if two HLCs are concurrent (neither happened before the other).
  This is only possible if they have the same timestamp and counter but different node_ids.
  """
  def concurrent?(hlc1, hlc2) do
    hlc1.timestamp == hlc2.timestamp and 
    hlc1.counter == hlc2.counter and 
    hlc1.node_id != hlc2.node_id
  end

  @doc """
  Convert HLC to a compact string representation.
  """
  def to_string(%__MODULE__{timestamp: ts, counter: c, node_id: node}) do
    "#{ts}:#{c}@#{inspect(node)}"
  end

  @doc """
  Parse HLC from string representation.
  """
  def from_string(str) do
    case String.split(str, [":", "@"]) do
      [ts_str, c_str, node_str] ->
        with {ts, ""} <- Integer.parse(ts_str),
             {c, ""} <- Integer.parse(c_str),
             {node, _} <- Code.eval_string(node_str) do
          {:ok, %__MODULE__{timestamp: ts, counter: c, node_id: node}}
        else
          _ -> {:error, :invalid_format}
        end
      _ ->
        {:error, :invalid_format}
    end
  end
end