# VSMCP - Viable System Model with Model Context Protocol

A fresh implementation of Stafford Beer's Viable System Model (VSM) with dynamic capability acquisition through the Model Context Protocol (MCP).

## Overview

VSMCP implements a complete cybernetic control system based on VSM principles:

- **System 1**: Operational units that perform primary activities
- **System 2**: Coordination and anti-oscillation between units
- **System 3**: Control, optimization, and resource allocation
- **System 4**: Intelligence, environmental scanning, and adaptation
- **System 5**: Policy, identity, and strategic decision-making

## Features

- ✅ Full VSM implementation with all 5 systems
- ✅ Real-time variety calculation using Ashby's Law
- ✅ Consciousness interface for meta-cognitive reflection
- ✅ MCP integration for dynamic capability acquisition
- ✅ Phoenix PubSub for inter-system communication
- ✅ Comprehensive telemetry and monitoring

## Installation

```bash
# Clone the repository
git clone https://github.com/your-org/vsmcp.git
cd vsmcp

# Install dependencies
mix deps.get

# Run tests
mix test

# Start the system
iex -S mix
```

## Usage

```elixir
# Get system status
Vsmcp.status()

# Analyze variety gaps
Vsmcp.analyze_variety()

# Make a strategic decision
context = %{
  issue: "Resource allocation",
  demands: %{computational: 0.8, memory: 0.6},
  signals: [%{type: :opportunity, impact: :high}]
}
Vsmcp.make_decision(context)

# Query consciousness interface
Vsmcp.reflect("What are my current limitations?")
```

## Architecture

The system is built with OTP principles:

```
Application Supervisor
├── Telemetry
├── Phoenix.PubSub
├── Core Supervisor
│   └── Variety Calculator
├── System 1 Supervisor
├── System 2 Supervisor
├── System 3 Supervisor
├── System 4 Supervisor
├── System 5 Supervisor
├── Consciousness Supervisor
├── MCP Server Manager
└── Integration Manager
```

## Configuration

Configure the system in `config/config.exs`:

```elixir
config :vsmcp,
  variety_check_interval: 60_000,
  pubsub_name: Vsmcp.PubSub
```

## Development

```bash
# Run code quality checks
mix quality

# Generate documentation
mix docs

# Run development server
iex -S mix
```

## Testing

```bash
# Run all tests
mix test

# Run tests with coverage
mix test --cover
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Stafford Beer for the Viable System Model
- W. Ross Ashby for the Law of Requisite Variety
- Anthropic for the Model Context Protocol
- The Elixir community for excellent tools and libraries

