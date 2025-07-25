#!/bin/bash
# Generate variety gap report for VSM

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Output format (json, text, or detailed)
FORMAT=${1:-text}

echo "VSM Variety Gap Analysis"
echo "======================="
echo ""

# Generate the report
REPORT=$("$RELEASE_ROOT/bin/vsmcp" rpc "
  alias Vsmcp.VSM.{VarietyAnalyzer, CapabilityRegistry}
  
  # Get current system variety
  system_variety = VarietyAnalyzer.analyze_system_variety()
  
  # Get environment variety (required)
  env_variety = VarietyAnalyzer.analyze_environment_variety()
  
  # Calculate gaps
  gaps = VarietyAnalyzer.identify_variety_gaps(system_variety, env_variety)
  
  # Get recommendations
  recommendations = VarietyAnalyzer.recommend_capabilities(gaps)
  
  # Get current MCP capabilities
  mcp_capabilities = CapabilityRegistry.list_capabilities()
  
  # Format based on requested format
  case \"$FORMAT\" of
    \"json\" ->
      Jason.encode!(%{
        timestamp: DateTime.utc_now(),
        system_variety: system_variety,
        environment_variety: env_variety,
        variety_gaps: gaps,
        recommendations: recommendations,
        current_capabilities: mcp_capabilities,
        analysis: %{
          gap_count: length(gaps),
          coverage_percentage: VarietyAnalyzer.calculate_coverage(system_variety, env_variety),
          critical_gaps: Enum.filter(gaps, & &1.severity == :critical)
        }
      }, pretty: true)
      
    \"detailed\" ->
      \"\"\"
      Detailed Variety Analysis
      ========================
      
      System Variety Score: #{system_variety.score}/100
      Environment Complexity: #{env_variety.complexity}
      Coverage: #{VarietyAnalyzer.calculate_coverage(system_variety, env_variety)}%
      
      Critical Gaps:
      #{gaps |> Enum.filter(& &1.severity == :critical) |> Enum.map(& \"  - #{&1.name}: #{&1.description}\") |> Enum.join(\"\n\")}
      
      High Priority Gaps:
      #{gaps |> Enum.filter(& &1.severity == :high) |> Enum.map(& \"  - #{&1.name}: #{&1.description}\") |> Enum.join(\"\n\")}
      
      Current MCP Capabilities (#{length(mcp_capabilities)}):
      #{mcp_capabilities |> Enum.map(& \"  - #{&1.name} (#{&1.type})\") |> Enum.join(\"\n\")}
      
      Recommendations:
      #{recommendations |> Enum.with_index(1) |> Enum.map(fn {r, i} -> \"  #{i}. #{r.action}: #{r.capability}\" end) |> Enum.join(\"\n\")}
      \"\"\"
      
    _ ->
      \"\"\"
      Summary Report
      ==============
      
      Variety Gaps Detected: #{length(gaps)}
      Critical: #{gaps |> Enum.count(& &1.severity == :critical)}
      High: #{gaps |> Enum.count(& &1.severity == :high)}
      Medium: #{gaps |> Enum.count(& &1.severity == :medium)}
      Low: #{gaps |> Enum.count(& &1.severity == :low)}
      
      System Coverage: #{VarietyAnalyzer.calculate_coverage(system_variety, env_variety)}%
      
      Top Recommendations:
      #{recommendations |> Enum.take(5) |> Enum.with_index(1) |> Enum.map(fn {r, i} -> \"  #{i}. #{r.action}: #{r.capability}\" end) |> Enum.join(\"\n\")}
      
      Use '--detailed' or '--json' for full report
      \"\"\"
  end
" 2>&1)

if [[ $? -eq 0 ]]; then
    echo "$REPORT"
else
    echo "Error generating variety report:"
    echo "$REPORT"
    exit 1
fi

# Save report to file if requested
if [[ "$2" == "--save" ]]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    REPORT_FILE="$RELEASE_ROOT/reports/variety_report_$TIMESTAMP.$FORMAT"
    mkdir -p "$RELEASE_ROOT/reports"
    echo "$REPORT" > "$REPORT_FILE"
    echo ""
    echo "Report saved to: $REPORT_FILE"
fi

exit 0