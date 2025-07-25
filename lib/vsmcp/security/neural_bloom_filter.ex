defmodule Vsmcp.Security.NeuralBloomFilter do
  @moduledoc """
  Neural Bloom Filter for intelligent threat detection.
  
  Combines traditional Bloom filter efficiency with neural pattern recognition
  to detect and prevent security threats with adaptive learning capabilities.
  """
  
  use GenServer
  require Logger
  
  @type threat_type :: :injection | :overflow | :dos | :unauthorized | :anomaly
  @type threat_level :: :low | :medium | :high | :critical
  
  # Bloom filter parameters
  @filter_size 100_000  # bits
  @hash_functions 7     # optimal for ~0.01 false positive rate
  @learning_rate 0.01
  @decay_factor 0.995   # Pattern decay over time
  
  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def check_threat(data) when is_binary(data) do
    GenServer.call(__MODULE__, {:check_threat, data})
  end
  
  def check_threat(data) when is_map(data) do
    check_threat(Jason.encode!(data))
  end
  
  def report_threat(data, threat_type, confirmed \\ true) do
    GenServer.cast(__MODULE__, {:report_threat, data, threat_type, confirmed})
  end
  
  def get_statistics do
    GenServer.call(__MODULE__, :get_statistics)
  end
  
  def train_pattern(pattern, threat_type) do
    GenServer.cast(__MODULE__, {:train_pattern, pattern, threat_type})
  end
  
  # Server Callbacks
  
  @impl true
  def init(_opts) do
    # Initialize bloom filter bit array
    filter = :atomics.new(@filter_size, signed: false)
    
    # Initialize neural weights for pattern recognition
    neural_weights = initialize_neural_weights()
    
    # Schedule periodic filter optimization
    :timer.send_interval(300_000, :optimize_filter) # Every 5 minutes
    
    {:ok, %{
      filter: filter,
      neural_weights: neural_weights,
      threat_patterns: %{},
      statistics: %{
        checks: 0,
        threats_detected: 0,
        false_positives: 0,
        true_positives: 0
      },
      recent_threats: :queue.new(),
      pattern_memory: []
    }}
  end
  
  @impl true
  def handle_call({:check_threat, data}, _from, state) do
    # First check: Bloom filter for known threats
    bloom_result = check_bloom_filter(data, state.filter)
    
    # Second check: Neural pattern analysis
    neural_result = analyze_neural_patterns(data, state.neural_weights, state.threat_patterns)
    
    # Combine results with weighted decision
    {is_threat, confidence, threat_info} = combine_detection_results(bloom_result, neural_result)
    
    # Update statistics
    new_state = update_in(state.statistics.checks, &(&1 + 1))
    
    if is_threat do
      new_state = update_in(new_state.statistics.threats_detected, &(&1 + 1))
      Logger.warn("Threat detected: #{inspect(threat_info)} with confidence #{confidence}")
      
      # Add to recent threats queue
      new_state = update_in(new_state.recent_threats, fn queue ->
        :queue.in({data, threat_info, DateTime.utc_now()}, queue)
      end)
    end
    
    {:reply, {is_threat, confidence, threat_info}, new_state}
  end
  
  @impl true
  def handle_call(:get_statistics, _from, state) do
    stats = Map.merge(state.statistics, %{
      filter_saturation: calculate_filter_saturation(state.filter),
      pattern_count: map_size(state.threat_patterns),
      neural_accuracy: calculate_neural_accuracy(state)
    })
    
    {:reply, stats, state}
  end
  
  @impl true
  def handle_cast({:report_threat, data, threat_type, confirmed}, state) do
    # Add to bloom filter
    add_to_bloom_filter(data, state.filter)
    
    # Update neural patterns
    new_state = if confirmed do
      update_in(state.threat_patterns, fn patterns ->
        Map.update(patterns, threat_type, [data], &[data | &1])
      end)
    else
      # False positive - adjust weights
      update_in(state.statistics.false_positives, &(&1 + 1))
    end
    
    # Train neural network on this pattern
    new_weights = train_neural_network(data, threat_type, confirmed, new_state.neural_weights)
    
    {:noreply, %{new_state | neural_weights: new_weights}}
  end
  
  @impl true
  def handle_cast({:train_pattern, pattern, threat_type}, state) do
    # Extract features from pattern
    features = extract_threat_features(pattern)
    
    # Update neural weights
    new_weights = update_neural_weights(features, threat_type, state.neural_weights)
    
    # Store pattern for future reference
    new_patterns = Map.update(state.threat_patterns, threat_type, [pattern], &[pattern | &1])
    
    {:noreply, %{state | 
      neural_weights: new_weights,
      threat_patterns: new_patterns
    }}
  end
  
  @impl true
  def handle_info(:optimize_filter, state) do
    Logger.info("Optimizing neural bloom filter...")
    
    # Decay old patterns
    new_weights = decay_neural_weights(state.neural_weights)
    
    # Clean up old threats from queue
    new_queue = clean_threat_queue(state.recent_threats)
    
    # Analyze pattern effectiveness
    pattern_stats = analyze_pattern_effectiveness(state)
    
    Logger.info("Filter optimization complete. Pattern effectiveness: #{inspect(pattern_stats)}")
    
    {:noreply, %{state | 
      neural_weights: new_weights,
      recent_threats: new_queue
    }}
  end
  
  # Private Functions - Bloom Filter Operations
  
  defp check_bloom_filter(data, filter) do
    hashes = generate_hashes(data)
    
    # Check if all hash positions are set
    is_present = Enum.all?(hashes, fn hash ->
      pos = rem(hash, @filter_size) + 1
      :atomics.get(filter, pos) == 1
    end)
    
    {is_present, if(is_present, 0.8, 0.0)}
  end
  
  defp add_to_bloom_filter(data, filter) do
    hashes = generate_hashes(data)
    
    Enum.each(hashes, fn hash ->
      pos = rem(hash, @filter_size) + 1
      :atomics.put(filter, pos, 1)
    end)
  end
  
  defp generate_hashes(data) do
    # Generate k independent hash values
    1..@hash_functions
    |> Enum.map(fn i ->
      :crypto.hash(:sha256, "#{data}:#{i}")
      |> :binary.decode_unsigned()
    end)
  end
  
  # Private Functions - Neural Pattern Analysis
  
  defp initialize_neural_weights do
    # Initialize weights for different threat features
    %{
      injection_patterns: :rand.uniform_real() * 0.1,
      overflow_patterns: :rand.uniform_real() * 0.1,
      dos_patterns: :rand.uniform_real() * 0.1,
      unauthorized_patterns: :rand.uniform_real() * 0.1,
      anomaly_patterns: :rand.uniform_real() * 0.1,
      
      # Feature weights
      length_weight: :rand.uniform_real() * 0.1,
      entropy_weight: :rand.uniform_real() * 0.1,
      special_chars_weight: :rand.uniform_real() * 0.1,
      pattern_frequency_weight: :rand.uniform_real() * 0.1
    }
  end
  
  defp analyze_neural_patterns(data, weights, known_patterns) do
    features = extract_threat_features(data)
    
    # Calculate threat scores for each type
    threat_scores = %{
      injection: calculate_injection_score(features, weights),
      overflow: calculate_overflow_score(features, weights),
      dos: calculate_dos_score(features, weights),
      unauthorized: calculate_unauthorized_score(features, weights),
      anomaly: calculate_anomaly_score(features, weights, known_patterns)
    }
    
    # Find highest scoring threat
    {threat_type, max_score} = Enum.max_by(threat_scores, fn {_, score} -> score end)
    
    if max_score > 0.5 do
      {true, max_score, %{type: threat_type, features: features}}
    else
      {false, max_score, nil}
    end
  end
  
  defp extract_threat_features(data) when is_binary(data) do
    %{
      length: byte_size(data),
      entropy: calculate_entropy(data),
      special_chars: count_special_chars(data),
      sql_keywords: detect_sql_keywords(data),
      script_tags: detect_script_patterns(data),
      repeated_patterns: detect_repeated_patterns(data),
      encoding_anomalies: detect_encoding_anomalies(data)
    }
  end
  
  defp calculate_entropy(data) do
    # Shannon entropy calculation
    freq_map = data
    |> String.graphemes()
    |> Enum.frequencies()
    
    total = String.length(data)
    
    freq_map
    |> Enum.reduce(0, fn {_, count}, entropy ->
      probability = count / total
      entropy - (probability * :math.log2(probability))
    end)
  end
  
  defp count_special_chars(data) do
    data
    |> String.graphemes()
    |> Enum.count(&(&1 =~ ~r/[^a-zA-Z0-9\s]/))
  end
  
  defp detect_sql_keywords(data) do
    sql_keywords = ~w(select insert update delete drop union where from join)
    downcased = String.downcase(data)
    
    Enum.count(sql_keywords, &String.contains?(downcased, &1))
  end
  
  defp detect_script_patterns(data) do
    patterns = [~r/<script/i, ~r/javascript:/i, ~r/onerror=/i, ~r/onclick=/i]
    Enum.count(patterns, &Regex.match?(&1, data))
  end
  
  defp detect_repeated_patterns(data) do
    # Simple pattern detection - count repeated substrings
    chunks = for i <- 0..(String.length(data) - 3), 
                 do: String.slice(data, i, 3)
    
    chunks
    |> Enum.frequencies()
    |> Enum.count(fn {_, freq} -> freq > 2 end)
  end
  
  defp detect_encoding_anomalies(data) do
    # Check for unusual encoding patterns
    anomalies = [
      String.contains?(data, "%00"),  # Null byte
      String.contains?(data, "\\x"),   # Hex encoding
      String.contains?(data, "\\u"),   # Unicode escape
      data =~ ~r/(%[0-9a-fA-F]{2}){3,}/  # Excessive URL encoding
    ]
    
    Enum.count(anomalies, & &1)
  end
  
  # Scoring functions for different threat types
  
  defp calculate_injection_score(features, weights) do
    base_score = (features.sql_keywords * 0.3 + 
                  features.script_tags * 0.3 +
                  features.special_chars * 0.001) * weights.injection_patterns
    
    # Adjust based on entropy - high entropy might indicate obfuscation
    entropy_factor = if features.entropy > 4.5, do: 1.2, else: 1.0
    
    min(base_score * entropy_factor, 1.0)
  end
  
  defp calculate_overflow_score(features, weights) do
    length_factor = if features.length > 1000, do: features.length / 10000, else: 0
    pattern_factor = features.repeated_patterns * 0.05
    
    (length_factor + pattern_factor) * weights.overflow_patterns
  end
  
  defp calculate_dos_score(features, _weights) do
    # DOS patterns often involve repeated requests or resource-intensive patterns
    if features.length > 10000 || features.repeated_patterns > 50 do
      0.8
    else
      0.2
    end
  end
  
  defp calculate_unauthorized_score(features, weights) do
    # Look for authentication bypass attempts
    auth_patterns = [
      features.special_chars > 20,
      features.encoding_anomalies > 2,
      String.contains?(to_string(features), "admin"),
      String.contains?(to_string(features), "bypass")
    ]
    
    Enum.count(auth_patterns, & &1) * 0.25 * weights.unauthorized_patterns
  end
  
  defp calculate_anomaly_score(features, weights, known_patterns) do
    # Use statistical analysis against known good patterns
    baseline_entropy = 3.5
    entropy_deviation = abs(features.entropy - baseline_entropy)
    
    anomaly_score = entropy_deviation * 0.2 * weights.anomaly_patterns
    
    # Check against known patterns
    if Enum.any?(known_patterns, fn {_, patterns} -> 
      Enum.any?(patterns, &similar?(&1, features))
    end) do
      anomaly_score * 0.5  # Reduce score if similar to known pattern
    else
      anomaly_score * 1.5  # Increase score for unknown pattern
    end
  end
  
  defp similar?(pattern1, pattern2) when is_map(pattern1) and is_map(pattern2) do
    # Simple similarity check based on feature vectors
    Enum.all?([:length, :entropy, :special_chars], fn key ->
      abs(Map.get(pattern1, key, 0) - Map.get(pattern2, key, 0)) < 0.2
    end)
  end
  
  defp similar?(_, _), do: false
  
  defp combine_detection_results({bloom_hit, bloom_conf}, {neural_hit, neural_conf, threat_info}) do
    # Weighted combination of bloom filter and neural results
    combined_confidence = (bloom_conf * 0.4 + neural_conf * 0.6)
    is_threat = bloom_hit || (neural_hit && neural_conf > 0.7)
    
    {is_threat, combined_confidence, threat_info}
  end
  
  defp train_neural_network(data, threat_type, confirmed, weights) do
    features = extract_threat_features(data)
    
    # Simple gradient update based on confirmation
    learning_factor = if confirmed, do: @learning_rate, else: -@learning_rate * 0.5
    
    Map.new(weights, fn {key, weight} ->
      if key == :"#{threat_type}_patterns" do
        {key, weight + learning_factor}
      else
        {key, weight}
      end
    end)
  end
  
  defp update_neural_weights(features, threat_type, weights) do
    # Update weights based on feature importance for this threat type
    weights
    |> Map.update(:"#{threat_type}_patterns", 0.5, &(&1 + @learning_rate))
    |> Map.update(:entropy_weight, 0.1, fn w ->
      w + @learning_rate * (features.entropy / 5.0)
    end)
  end
  
  defp decay_neural_weights(weights) do
    # Apply decay to prevent overfitting to old patterns
    Map.new(weights, fn {key, weight} ->
      {key, weight * @decay_factor}
    end)
  end
  
  defp calculate_filter_saturation(filter) do
    # Sample random positions to estimate saturation
    sample_size = 1000
    set_bits = Enum.count(1..sample_size, fn _ ->
      pos = :rand.uniform(@filter_size)
      :atomics.get(filter, pos) == 1
    end)
    
    set_bits / sample_size * 100
  end
  
  defp calculate_neural_accuracy(state) do
    total = state.statistics.threats_detected
    if total > 0 do
      true_positives = state.statistics.true_positives
      (true_positives / total * 100)
    else
      0.0
    end
  end
  
  defp clean_threat_queue(queue) do
    # Remove threats older than 1 hour
    cutoff = DateTime.add(DateTime.utc_now(), -3600, :second)
    
    queue
    |> :queue.to_list()
    |> Enum.filter(fn {_, _, timestamp} ->
      DateTime.compare(timestamp, cutoff) == :gt
    end)
    |> :queue.from_list()
  end
  
  defp analyze_pattern_effectiveness(state) do
    # Analyze which patterns are most effective
    %{
      total_patterns: map_size(state.threat_patterns),
      pattern_distribution: state.threat_patterns
        |> Enum.map(fn {type, patterns} -> {type, length(patterns)} end)
        |> Map.new(),
      detection_rate: if(state.statistics.checks > 0,
        do: state.statistics.threats_detected / state.statistics.checks,
        else: 0)
    }
  end
end