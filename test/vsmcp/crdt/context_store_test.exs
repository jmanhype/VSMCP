defmodule Vsmcp.CRDT.ContextStoreTest do
  use ExUnit.Case, async: false
  
  alias Vsmcp.CRDT.ContextStore
  alias Vsmcp.CRDT.Types.{GCounter, PNCounter, ORSet, LWWRegister}

  setup do
    # Start a ContextStore instance for testing
    {:ok, store} = ContextStore.start_link(
      node_id: :test_node,
      storage_opts: [
        ets_name: :test_crdt_ets,
        dets_name: :test_crdt_dets,
        dets_file: "test_crdt.dets"
      ]
    )
    
    on_exit(fn ->
      # Cleanup DETS file
      File.rm("test_crdt.dets")
    end)
    
    {:ok, store: store}
  end

  describe "G-Counter operations" do
    test "create and increment G-Counter", %{store: store} do
      assert :ok = ContextStore.create(store, :test_gcounter, :g_counter)
      assert {:ok, 0} = ContextStore.get(store, :test_gcounter)
      
      assert {:ok, 1} = ContextStore.increment(store, :test_gcounter)
      assert {:ok, 1} = ContextStore.get(store, :test_gcounter)
      
      assert {:ok, 6} = ContextStore.increment(store, :test_gcounter, 5)
      assert {:ok, 6} = ContextStore.get(store, :test_gcounter)
    end

    test "G-Counter only allows positive increments", %{store: store} do
      assert :ok = ContextStore.create(store, :test_gcounter2, :g_counter)
      
      # Negative increment should be ignored
      assert {:ok, 0} = ContextStore.increment(store, :test_gcounter2, -5)
      assert {:ok, 0} = ContextStore.get(store, :test_gcounter2)
    end
  end

  describe "PN-Counter operations" do
    test "create, increment and decrement PN-Counter", %{store: store} do
      assert :ok = ContextStore.create(store, :test_pncounter, :pn_counter)
      assert {:ok, 0} = ContextStore.get(store, :test_pncounter)
      
      assert {:ok, 10} = ContextStore.increment(store, :test_pncounter, 10)
      assert {:ok, 10} = ContextStore.get(store, :test_pncounter)
      
      assert {:ok, 7} = ContextStore.decrement(store, :test_pncounter, 3)
      assert {:ok, 7} = ContextStore.get(store, :test_pncounter)
      
      assert {:ok, -3} = ContextStore.decrement(store, :test_pncounter, 10)
      assert {:ok, -3} = ContextStore.get(store, :test_pncounter)
    end
  end

  describe "OR-Set operations" do
    test "create, add and remove elements in OR-Set", %{store: store} do
      assert :ok = ContextStore.create(store, :test_orset, :or_set)
      assert {:ok, set} = ContextStore.get(store, :test_orset)
      assert MapSet.size(set) == 0
      
      assert {:ok, _} = ContextStore.add(store, :test_orset, "apple")
      assert {:ok, set} = ContextStore.get(store, :test_orset)
      assert "apple" in set
      
      assert {:ok, _} = ContextStore.add(store, :test_orset, "banana")
      assert {:ok, set} = ContextStore.get(store, :test_orset)
      assert "apple" in set
      assert "banana" in set
      
      assert {:ok, _} = ContextStore.remove(store, :test_orset, "apple")
      assert {:ok, set} = ContextStore.get(store, :test_orset)
      assert "apple" not in set
      assert "banana" in set
    end

    test "OR-Set handles concurrent add/remove correctly", %{store: store} do
      assert :ok = ContextStore.create(store, :test_orset2, :or_set)
      
      # Add same element multiple times
      assert {:ok, _} = ContextStore.add(store, :test_orset2, "item")
      assert {:ok, _} = ContextStore.add(store, :test_orset2, "item")
      
      # Remove once should remove all instances
      assert {:ok, _} = ContextStore.remove(store, :test_orset2, "item")
      assert {:ok, set} = ContextStore.get(store, :test_orset2)
      assert "item" not in set
    end
  end

  describe "LWW-Register operations" do
    test "create and set LWW-Register", %{store: store} do
      assert :ok = ContextStore.create(store, :test_lwwreg, :lww_register)
      assert {:ok, nil} = ContextStore.get(store, :test_lwwreg)
      
      assert {:ok, "hello"} = ContextStore.set(store, :test_lwwreg, "hello")
      assert {:ok, "hello"} = ContextStore.get(store, :test_lwwreg)
      
      assert {:ok, "world"} = ContextStore.set(store, :test_lwwreg, "world")
      assert {:ok, "world"} = ContextStore.get(store, :test_lwwreg)
    end

    test "LWW-Register can store complex data", %{store: store} do
      assert :ok = ContextStore.create(store, :test_lwwreg2, :lww_register)
      
      complex_data = %{
        name: "test",
        value: 42,
        nested: %{data: [1, 2, 3]}
      }
      
      assert {:ok, ^complex_data} = ContextStore.set(store, :test_lwwreg2, complex_data)
      assert {:ok, ^complex_data} = ContextStore.get(store, :test_lwwreg2)
    end
  end

  describe "ContextStore management" do
    test "prevent duplicate CRDT creation", %{store: store} do
      assert :ok = ContextStore.create(store, :duplicate_test, :g_counter)
      assert {:error, :already_exists} = ContextStore.create(store, :duplicate_test, :g_counter)
    end

    test "handle operations on non-existent CRDTs", %{store: store} do
      assert {:error, :not_found} = ContextStore.get(store, :non_existent)
      assert {:error, :not_found} = ContextStore.increment(store, :non_existent)
    end

    test "list all CRDTs", %{store: store} do
      assert [] = ContextStore.list_crdts(store)
      
      assert :ok = ContextStore.create(store, :crdt1, :g_counter)
      assert :ok = ContextStore.create(store, :crdt2, :or_set)
      assert :ok = ContextStore.create(store, :crdt3, :lww_register)
      
      crdts = ContextStore.list_crdts(store)
      assert length(crdts) == 3
      assert :crdt1 in crdts
      assert :crdt2 in crdts
      assert :crdt3 in crdts
    end

    test "get CRDT metadata", %{store: store} do
      assert :ok = ContextStore.create(store, :meta_test, :pn_counter)
      
      assert {:ok, metadata} = ContextStore.get_metadata(store, :meta_test)
      assert metadata.type == :pn_counter
      assert metadata.created_by == :test_node
      assert is_integer(metadata.created_at)
    end
  end

  describe "CRDT convergence" do
    test "G-Counter convergence", %{store: store} do
      # Simulate two nodes
      counter1 = GCounter.new(:node1)
      counter2 = GCounter.new(:node2)
      
      # Node 1 increments by 5
      {counter1, delta1} = GCounter.increment(counter1, 5)
      
      # Node 2 increments by 3
      {counter2, delta2} = GCounter.increment(counter2, 3)
      
      # Merge deltas
      merged1 = GCounter.merge(counter1, delta2)
      merged2 = GCounter.merge(counter2, delta1)
      
      # Both should converge to same value
      assert GCounter.value(merged1) == 8
      assert GCounter.value(merged2) == 8
      assert GCounter.equal?(merged1, merged2)
    end

    test "OR-Set convergence with concurrent add/remove", %{store: store} do
      # Simulate two nodes
      set1 = ORSet.new(:node1)
      set2 = ORSet.new(:node2)
      
      # Both nodes add same element
      {set1, _delta1} = ORSet.add(set1, "item")
      {set2, delta2} = ORSet.add(set2, "item")
      
      # Node 1 removes the element
      {set1_removed, delta_remove} = ORSet.remove(set1, "item")
      
      # Merge operations
      merged1 = ORSet.merge(set1_removed, delta2)
      merged2 = ORSet.merge(set2, delta_remove)
      
      # Both should converge to empty set (remove wins)
      assert MapSet.size(ORSet.value(merged1)) == 0
      assert MapSet.size(ORSet.value(merged2)) == 0
    end
  end
end