# Path: lib/vsmcp/mcp/adapters/system4_adapter.ex
defmodule Vsmcp.MCP.Adapters.System4Adapter do
  @moduledoc """
  MCP adapter for System 4 intelligence operations.
  Bridges external MCP tools into VSM environmental scanning and future planning.
  """
  
  use GenServer
  require Logger
  
  alias Vsmcp.Systems.System4
  alias Vsmcp.MCP.{Client, CapabilityRegistry, ToolChain}

  # Intelligence source registration
  defmodule IntelligenceSource do
    @enforce_keys [:id, :name, :type, :mcp_server]
    defstruct [:id, :name, :type, :mcp_server, :tools, :scan_pattern, :analysis_chain, :metadata]
  end

  # Client API
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  def register_intelligence_source(adapter \\ __MODULE__, source_def) do
    GenServer.call(adapter, {:register_intelligence_source, source_def})
  end

  def scan_with_mcp(adapter \\ __MODULE__, context) do
    GenServer.call(adapter, {:scan_with_mcp, context}, 60_000)
  end

  def analyze_with_chain(adapter \\ __MODULE__, data, chain_name) do
    GenServer.call(adapter, {:analyze_with_chain, data, chain_name}, 60_000)
  end

  def list_intelligence_sources(adapter \\ __MODULE__) do
    GenServer.call(adapter, :list_intelligence_sources)
  end

  # Register common intelligence sources
  def register_common_sources(adapter \\ __MODULE__) do
    # GitHub intelligence
    register_intelligence_source(adapter, %{
      name: "github_intelligence",
      type: :code_trends,
      mcp_server: "github-mcp",
      tools: ["search_repos", "get_trending", "analyze_activity"],
      scan_pattern: :weekly,
      analysis_chain: "github_trend_analysis"
    })
    
    # News and media intelligence  
    register_intelligence_source(adapter, %{
      name: "news_intelligence",
      type: :market_signals,
      mcp_server: "news-mcp",
      tools: ["search_articles", "get_headlines", "sentiment_analysis"],
      scan_pattern: :daily,
      analysis_chain: "market_signal_detection"
    })
    
    # Data source intelligence
    register_intelligence_source(adapter, %{
      name: "data_intelligence",
      type: :data_patterns,
      mcp_server: "bigquery-mcp",
      tools: ["query_datasets", "analyze_trends", "detect_anomalies"],
      scan_pattern: :continuous,
      analysis_chain: "data_pattern_recognition"
    })
    
    # API ecosystem intelligence
    register_intelligence_source(adapter, %{
      name: "api_intelligence", 
      type: :api_landscape,
      mcp_server: "api-discovery-mcp",
      tools: ["discover_apis", "analyze_endpoints", "track_changes"],
      scan_pattern: :monthly,
      analysis_chain: "api_ecosystem_mapping"
    })
    
    # Security intelligence
    register_intelligence_source(adapter, %{
      name: "security_intelligence",
      type: :threat_detection,
      mcp_server: "security-mcp",
      tools: ["scan_vulnerabilities", "threat_feed", "risk_assessment"],
      scan_pattern: :realtime,
      analysis_chain: "threat_analysis"
    })
  end

  # Server Callbacks
  
  @impl true
  def init(opts) do
    client = opts[:client] || Client
    capability_registry = opts[:capability_registry] || CapabilityRegistry
    tool_chain = opts[:tool_chain] || ToolChain
    
    # Create analysis chains
    create_analysis_chains(tool_chain)
    
    # Schedule periodic scans
    schedule_next_scan()
    
    {:ok, %{
      sources: %{},
      scan_results: %{},
      client: client,
      capability_registry: capability_registry,
      tool_chain: tool_chain,
      metrics: %{
        sources_registered: 0,
        scans_performed: 0,
        insights_generated: 0,
        predictions_made: 0
      }
    }}
  end

  @impl true
  def handle_call({:register_intelligence_source, source_def}, _from, state) do
    source = create_intelligence_source(source_def)
    
    # Register capabilities for each tool
    Enum.each(source.tools, fn tool ->
      capability_def = %{
        name: "s4_intel_#{source.name}_#{tool}",
        type: :intelligence,
        source: %{type: :s4_adapter, adapter: __MODULE__},
        interface: %{
          handler: create_intel_handler(source, tool, state)
        },
        metadata: %{
          intelligence_type: source.type,
          mcp_server: source.mcp_server,
          tool: tool
        }
      }
      
      CapabilityRegistry.register_capability(state.capability_registry, capability_def)
    end)
    
    new_sources = Map.put(state.sources, source.id, source)
    new_metrics = %{state.metrics | sources_registered: state.metrics.sources_registered + 1}
    
    Logger.info("Registered intelligence source: #{source.name}")
    
    {:reply, {:ok, source.id}, %{state | sources: new_sources, metrics: new_metrics}}
  end

  @impl true
  def handle_call({:scan_with_mcp, context}, _from, state) do
    # Perform environmental scan using all registered MCP sources
    scan_results = state.sources
    |> Map.values()
    |> Enum.map(fn source ->
      Task.async(fn ->
        scan_source(source, context, state)
      end)
    end)
    |> Enum.map(&Task.await(&1, 30_000))
    |> Enum.reject(&is_nil/1)
    
    # Aggregate results
    aggregated = aggregate_scan_results(scan_results)
    
    # Feed to System 4
    System4.scan_environment(%{
      signals: aggregated.signals,
      context: Map.merge(context, %{mcp_scan: true})
    })
    
    new_metrics = %{state.metrics | scans_performed: state.metrics.scans_performed + 1}
    
    {:reply, {:ok, aggregated}, %{state | metrics: new_metrics}}
  end

  @impl true
  def handle_call({:analyze_with_chain, data, chain_name}, _from, state) do
    # Execute analysis chain
    case ToolChain.execute_chain(state.tool_chain, chain_name, %{data: data}) do
      {:ok, execution_id} ->
        # Wait for completion (simplified - would use async callback)
        Process.sleep(1000)
        
        case ToolChain.get_execution(state.tool_chain, execution_id) do
          {:ok, %{status: :completed, results: results}} ->
            insights = extract_insights(results)
            
            # Generate predictions
            {:ok, predictions} = System4.predict_future("6months")
            
            # Suggest adaptations
            adaptations = Enum.map(insights, fn insight ->
              {:ok, adaptation} = System4.suggest_adaptation(insight)
              adaptation
            end)
            
            new_metrics = %{state.metrics | 
              insights_generated: state.metrics.insights_generated + length(insights),
              predictions_made: state.metrics.predictions_made + 1
            }
            
            result = %{
              insights: insights,
              predictions: predictions,
              adaptations: adaptations
            }
            
            {:reply, {:ok, result}, %{state | metrics: new_metrics}}
            
          {:ok, %{status: :failed, errors: errors}} ->
            {:reply, {:error, {:chain_failed, errors}}, state}
            
          _ ->
            {:reply, {:error, :chain_timeout}, state}
        end
        
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:list_intelligence_sources, _from, state) do
    sources = state.sources
    |> Map.values()
    |> Enum.map(fn source ->
      %{
        id: source.id,
        name: source.name,
        type: source.type,
        mcp_server: source.mcp_server,
        tools_count: length(source.tools),
        scan_pattern: source.scan_pattern
      }
    end)
    
    {:reply, sources, state}
  end

  @impl true
  def handle_info(:perform_periodic_scan, state) do
    # Perform scans based on source patterns
    sources_to_scan = state.sources
    |> Map.values()
    |> Enum.filter(&should_scan_now?/1)
    
    Enum.each(sources_to_scan, fn source ->
      Task.start_link(fn ->
        scan_source(source, %{periodic: true}, state)
      end)
    end)
    
    schedule_next_scan()
    {:noreply, state}
  end

  # Private Functions
  
  defp create_intelligence_source(source_def) do
    %IntelligenceSource{
      id: generate_source_id(source_def),
      name: source_def.name,
      type: source_def.type,
      mcp_server: source_def.mcp_server,
      tools: source_def.tools || [],
      scan_pattern: source_def[:scan_pattern] || :daily,
      analysis_chain: source_def[:analysis_chain],
      metadata: source_def[:metadata] || %{}
    }
  end

  defp generate_source_id(source_def) do
    "intel_source_#{source_def.name}_#{:erlang.phash2(source_def)}"
  end

  defp create_intel_handler(source, tool, state) do
    fn params ->
      execute_intelligence_tool(source, tool, params, state)
    end
  end

  defp execute_intelligence_tool(source, tool, params, state) do
    # Ensure connection to MCP server
    case ensure_mcp_connection(source.mcp_server, state) do
      {:ok, server_id} ->
        # Call the tool
        case Client.call_tool(state.client, server_id, tool, params) do
          {:ok, result} ->
            # Transform to intelligence format
            intel = transform_to_intelligence(result, source, tool)
            {:ok, intel}
            
          error ->
            error
        end
        
      error ->
        error
    end
  end

  defp ensure_mcp_connection(server_name, state) do
    # Similar to System1Adapter
    case Client.list_servers(state.client) do
      servers when is_list(servers) ->
        case Enum.find(servers, &(&1.name == server_name)) do
          %{id: server_id} -> {:ok, server_id}
          nil -> connect_to_mcp_server(server_name, state)
        end
        
      _ ->
        connect_to_mcp_server(server_name, state)
    end
  end

  defp connect_to_mcp_server(server_name, state) do
    case Client.discover_servers(state.client, server_name) do
      {:ok, [server | _]} ->
        Client.connect(state.client, server)
        
      _ ->
        {:error, {:server_not_found, server_name}}
    end
  end

  defp scan_source(source, context, state) do
    Logger.info("Scanning intelligence source: #{source.name}")
    
    # Execute each tool in the source
    results = Enum.map(source.tools, fn tool ->
      case execute_intelligence_tool(source, tool, context, state) do
        {:ok, intel} -> intel
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    
    %{
      source: source.name,
      type: source.type,
      timestamp: DateTime.utc_now(),
      intelligence: results
    }
  end

  defp aggregate_scan_results(scan_results) do
    # Aggregate intelligence from all sources
    all_signals = scan_results
    |> Enum.flat_map(fn result ->
      result.intelligence
      |> Enum.map(&convert_to_signal(&1, result.type))
    end)
    
    # Categorize signals
    %{
      signals: all_signals,
      opportunities: Enum.filter(all_signals, &(&1.type == :opportunity)),
      threats: Enum.filter(all_signals, &(&1.type == :threat)),
      trends: extract_trends(all_signals),
      summary: %{
        total_signals: length(all_signals),
        sources_scanned: length(scan_results),
        timestamp: DateTime.utc_now()
      }
    }
  end

  defp convert_to_signal(intel, source_type) do
    %{
      type: categorize_signal(intel, source_type),
      description: intel[:description] || format_intel(intel),
      source: intel[:source] || source_type,
      confidence: intel[:confidence] || calculate_confidence(intel),
      impact: intel[:impact] || estimate_impact(intel),
      data: intel
    }
  end

  defp categorize_signal(intel, source_type) do
    cond do
      source_type == :threat_detection -> :threat
      intel[:sentiment] && intel[:sentiment] < -0.5 -> :threat
      intel[:growth] && intel[:growth] > 0.2 -> :opportunity
      intel[:risk_score] && intel[:risk_score] > 0.7 -> :threat
      true -> :neutral
    end
  end

  defp format_intel(intel) do
    # Format intelligence data into description
    case intel do
      %{title: title} -> title
      %{name: name} -> "Signal: #{name}"
      %{event: event} -> "Event detected: #{event}"
      _ -> "Intelligence signal detected"
    end
  end

  defp calculate_confidence(intel) do
    # Simple confidence calculation
    cond do
      intel[:confidence] -> intel[:confidence]
      intel[:score] -> intel[:score]
      intel[:certainty] -> intel[:certainty]
      true -> 0.5
    end
  end

  defp estimate_impact(intel) do
    # Estimate potential impact
    cond do
      intel[:impact] -> intel[:impact]
      intel[:severity] -> map_severity_to_impact(intel[:severity])
      intel[:magnitude] -> intel[:magnitude]
      true -> :medium
    end
  end

  defp map_severity_to_impact(severity) do
    case severity do
      s when s in [:critical, :high] -> :high
      s when s in [:medium, :moderate] -> :medium
      _ -> :low
    end
  end

  defp extract_trends(signals) do
    # Group signals by patterns
    signals
    |> Enum.group_by(& &1.source)
    |> Enum.map(fn {source, source_signals} ->
      %{
        source: source,
        signal_count: length(source_signals),
        dominant_type: most_common_type(source_signals),
        average_confidence: average_confidence(source_signals)
      }
    end)
  end

  defp most_common_type(signals) do
    signals
    |> Enum.frequencies_by(& &1.type)
    |> Enum.max_by(fn {_type, count} -> count end)
    |> elem(0)
  end

  defp average_confidence(signals) do
    confidences = Enum.map(signals, & &1.confidence)
    Enum.sum(confidences) / length(confidences)
  end

  defp transform_to_intelligence(result, source, tool) do
    # Transform MCP tool result to intelligence format
    base_intel = %{
      source: source.name,
      tool: tool,
      timestamp: DateTime.utc_now(),
      raw_data: result
    }
    
    # Add tool-specific transformations
    case tool do
      "search_repos" ->
        Map.merge(base_intel, extract_repo_intelligence(result))
        
      "get_trending" ->
        Map.merge(base_intel, extract_trending_intelligence(result))
        
      "sentiment_analysis" ->
        Map.merge(base_intel, extract_sentiment_intelligence(result))
        
      "detect_anomalies" ->
        Map.merge(base_intel, extract_anomaly_intelligence(result))
        
      "threat_feed" ->
        Map.merge(base_intel, extract_threat_intelligence(result))
        
      _ ->
        Map.merge(base_intel, %{data: result})
    end
  end

  defp extract_repo_intelligence(result) do
    repos = result["items"] || []
    
    %{
      title: "Repository trends",
      metrics: %{
        total_repos: length(repos),
        avg_stars: average_stars(repos),
        languages: extract_languages(repos)
      },
      growth: calculate_growth_rate(repos)
    }
  end

  defp extract_trending_intelligence(result) do
    %{
      title: "Trending topics",
      trends: result["trends"] || [],
      momentum: result["momentum"] || 0
    }
  end

  defp extract_sentiment_intelligence(result) do
    %{
      sentiment: result["sentiment"] || 0,
      confidence: result["confidence"] || 0.5,
      keywords: result["keywords"] || []
    }
  end

  defp extract_anomaly_intelligence(result) do
    %{
      anomalies: result["anomalies"] || [],
      severity: result["severity"] || :low,
      description: "Anomalies detected in data patterns"
    }
  end

  defp extract_threat_intelligence(result) do
    %{
      threats: result["threats"] || [],
      risk_score: result["risk_score"] || 0,
      impact: :high,
      type: :threat
    }
  end

  defp average_stars(repos) do
    if length(repos) > 0 do
      total = Enum.sum(Enum.map(repos, & &1["stargazers_count"] || 0))
      total / length(repos)
    else
      0
    end
  end

  defp extract_languages(repos) do
    repos
    |> Enum.map(& &1["language"])
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
  end

  defp calculate_growth_rate(repos) do
    # Simplified growth calculation
    recent = Enum.count(repos, fn repo ->
      case DateTime.from_iso8601(repo["created_at"] || "") do
        {:ok, created, _} ->
          DateTime.diff(DateTime.utc_now(), created, :day) < 30
        _ ->
          false
      end
    end)
    
    recent / max(length(repos), 1)
  end

  defp extract_insights(results) do
    # Extract actionable insights from analysis results
    results
    |> Map.values()
    |> Enum.flat_map(fn result ->
      case result do
        %{insights: insights} -> insights
        %{recommendations: recs} -> Enum.map(recs, &insight_from_recommendation/1)
        _ -> []
      end
    end)
  end

  defp insight_from_recommendation(rec) do
    %{
      type: :opportunity,
      description: rec,
      confidence: 0.7,
      impact: :medium
    }
  end

  defp create_analysis_chains(tool_chain) do
    # Create predefined analysis chains
    
    # GitHub trend analysis
    ToolChain.create_chain(tool_chain, %{
      name: "github_trend_analysis",
      description: "Analyze GitHub repository trends",
      steps: [
        %{
          id: "search",
          tool: "github.search_repos",
          source: {:external, "github-mcp"},
          args: %{sort: "stars", order: "desc"}
        },
        %{
          id: "analyze",
          tool: "vsm.s4.predict",
          source: :local,
          args: %{horizon: "3months"},
          transform: &transform_github_to_prediction/2
        }
      ]
    })
    
    # Market signal detection
    ToolChain.create_chain(tool_chain, %{
      name: "market_signal_detection",
      description: "Detect market signals from news",
      steps: [
        %{
          id: "gather_news",
          tool: "news.search_articles",
          source: {:external, "news-mcp"}
        },
        %{
          id: "sentiment",
          tool: "news.sentiment_analysis",
          source: {:external, "news-mcp"},
          transform: &extract_article_ids/2
        },
        %{
          id: "interpret",
          tool: "vsm.s4.suggest_adaptation",
          source: :local,
          transform: &convert_sentiment_to_signal/2
        }
      ]
    })
  end

  defp transform_github_to_prediction(result, _context) do
    %{
      data_source: "github",
      trends: result
    }
  end

  defp extract_article_ids(result, context) do
    articles = context["gather_news"]["articles"] || []
    %{article_ids: Enum.map(articles, & &1["id"])}
  end

  defp convert_sentiment_to_signal(result, context) do
    sentiment = context["sentiment"]["average"] || 0
    
    %{
      type: if(sentiment > 0, do: :opportunity, else: :threat),
      description: "Market sentiment: #{sentiment}",
      confidence: abs(sentiment)
    }
  end

  defp should_scan_now?(source) do
    # Determine if source should be scanned based on pattern
    case source.scan_pattern do
      :continuous -> true
      :realtime -> true
      :daily -> :rand.uniform() < 0.1  # 10% chance each check
      :weekly -> :rand.uniform() < 0.01 # 1% chance
      :monthly -> :rand.uniform() < 0.001 # 0.1% chance
      _ -> false
    end
  end

  defp schedule_next_scan do
    Process.send_after(self(), :perform_periodic_scan, 60_000) # Check every minute
  end
end