# Contributing to VSMCP

Thank you for your interest in contributing to VSMCP! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Setup](#development-setup)
4. [How to Contribute](#how-to-contribute)
5. [Coding Standards](#coding-standards)
6. [Testing Guidelines](#testing-guidelines)
7. [Documentation](#documentation)
8. [Pull Request Process](#pull-request-process)
9. [Issue Guidelines](#issue-guidelines)
10. [Community](#community)

## Code of Conduct

By participating in this project, you agree to abide by our Code of Conduct:

- **Be Respectful**: Treat everyone with respect. No harassment, discrimination, or inappropriate behavior.
- **Be Collaborative**: Work together towards common goals. Share knowledge and help others.
- **Be Professional**: Keep discussions focused on technical merit and project improvement.
- **Be Inclusive**: Welcome contributors from all backgrounds and experience levels.

## Getting Started

1. **Fork the Repository**: Click the "Fork" button on GitHub
2. **Clone Your Fork**: 
   ```bash
   git clone https://github.com/YOUR_USERNAME/vsmcp.git
   cd vsmcp
   ```
3. **Add Upstream Remote**:
   ```bash
   git remote add upstream https://github.com/viable-systems/vsmcp.git
   ```
4. **Create a Branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Setup

### Prerequisites

- Elixir 1.17+ with OTP 26+
- RabbitMQ 3.13+ (for AMQP features)
- PostgreSQL 14+ (for persistent state)
- Docker (optional, for containerized development)

### Environment Setup

```bash
# Install dependencies
mix deps.get
mix compile

# Setup development database (if using PostgreSQL)
mix ecto.create
mix ecto.migrate

# Run tests to verify setup
mix test

# Start development server
iex -S mix
```

### Development Tools

```bash
# Install development dependencies
mix archive.install hex phx_new
mix escript.install hex livebook

# Install code quality tools
mix archive.install hex credo
mix archive.install hex dialyxir

# Setup git hooks (optional but recommended)
cp .githooks/* .git/hooks/
chmod +x .git/hooks/*
```

## How to Contribute

### Types of Contributions

1. **Bug Fixes**: Fix issues reported in GitHub Issues
2. **Features**: Implement new functionality
3. **Documentation**: Improve or add documentation
4. **Tests**: Add missing tests or improve test coverage
5. **Performance**: Optimize code for better performance
6. **Refactoring**: Improve code quality and maintainability

### Contribution Workflow

1. **Check Issues**: Look for open issues or create a new one
2. **Discuss**: Comment on the issue to discuss your approach
3. **Implement**: Write code following our standards
4. **Test**: Ensure all tests pass and add new ones
5. **Document**: Update relevant documentation
6. **Submit**: Create a pull request

## Coding Standards

### Elixir Style Guide

We follow the [Elixir Style Guide](https://github.com/christopheradams/elixir_style_guide) with these specific requirements:

```elixir
# Module structure
defmodule Vsmcp.Systems.System1 do
  @moduledoc """
  Comprehensive module documentation explaining purpose,
  responsibilities, and usage examples.
  """

  use GenServer
  require Logger

  # Type specifications
  @type state :: %{
    units: map(),
    variety: float(),
    config: map()
  }

  # Module attributes
  @default_timeout 5_000
  @max_retries 3

  # Public API
  @doc """
  Starts a System 1 operational unit.

  ## Parameters
    - name: Unique identifier for the unit
    - config: Configuration map

  ## Examples
      iex> Vsmcp.Systems.System1.start_link(name: :unit_a)
      {:ok, #PID<0.123.0>}
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  # Callbacks
  @impl true
  def init(opts) do
    state = %{
      units: %{},
      variety: 0.0,
      config: Keyword.get(opts, :config, %{})
    }
    
    {:ok, state}
  end

  # Private functions
  defp calculate_variety(units) do
    # Implementation
  end
end
```

### Code Quality Requirements

1. **Format**: All code must be formatted with `mix format`
2. **Credo**: Must pass `mix credo --strict`
3. **Dialyzer**: Must pass `mix dialyzer`
4. **Documentation**: All public functions must have `@doc` tags
5. **Type Specs**: Use `@spec` for public functions
6. **Tests**: Maintain >90% test coverage

### Naming Conventions

```elixir
# Modules: CamelCase
defmodule Vsmcp.Systems.System1 do

# Functions and variables: snake_case
def calculate_variety(input_data) do
  processed_data = transform(input_data)
  
# Constants: SCREAMING_SNAKE_CASE (as module attributes)
@MAX_VARIETY_GAP 100
@DEFAULT_TIMEOUT 5_000

# Atoms: snake_case
:system_operational
:variety_exceeded

# Process names: descriptive atoms
{:via, Registry, {Vsmcp.Registry, {:system1, unit_id}}}
```

### Error Handling

```elixir
# Use tagged tuples for results
def process_data(input) do
  case validate(input) do
    :ok -> {:ok, transform(input)}
    {:error, reason} -> {:error, reason}
  end
end

# Use with statements for sequential operations
def complex_operation(params) do
  with {:ok, validated} <- validate(params),
       {:ok, processed} <- process(validated),
       {:ok, result} <- finalize(processed) do
    {:ok, result}
  else
    {:error, reason} -> {:error, reason}
  end
end

# Always handle all cases
case operation() do
  {:ok, result} -> handle_success(result)
  {:error, :timeout} -> handle_timeout()
  {:error, reason} -> handle_general_error(reason)
end
```

## Testing Guidelines

### Test Structure

```elixir
defmodule Vsmcp.Systems.System5Test do
  use ExUnit.Case, async: true
  
  # Use describe blocks for grouping
  describe "policy decisions" do
    setup do
      # Setup code specific to this describe block
      {:ok, system5} = start_supervised(Vsmcp.Systems.System5)
      %{system5: system5}
    end
    
    test "makes optimal decisions under normal conditions", %{system5: system5} do
      # Arrange
      context = build_context(:normal)
      
      # Act
      decision = Vsmcp.Systems.System5.decide(system5, context)
      
      # Assert
      assert decision.confidence > 0.8
      assert decision.action in [:maintain, :optimize]
    end
    
    test "handles crisis situations appropriately", %{system5: system5} do
      # Test implementation
    end
  end
end
```

### Testing Best Practices

1. **Unit Tests**: Test individual functions in isolation
2. **Integration Tests**: Test system interactions
3. **Property Tests**: Use StreamData for property-based testing
4. **Async Tests**: Use `async: true` when possible
5. **Test Helpers**: Create helpers in `test/support/`
6. **Fixtures**: Use `test/fixtures/` for test data

### Coverage Requirements

- Minimum 90% overall coverage
- 100% coverage for critical paths (VSM systems)
- Use `mix test --cover` to check coverage
- Use `mix coveralls.html` for detailed reports

## Documentation

### Documentation Standards

1. **Module Documentation**: Every module must have `@moduledoc`
2. **Function Documentation**: Public functions need `@doc`
3. **Examples**: Include usage examples in docs
4. **Type Specs**: Document types with `@type`
5. **Diagrams**: Use ASCII art or Mermaid for complex flows

### Documentation Updates

When contributing, update:
- API documentation in code
- README.md for user-facing changes
- ARCHITECTURE.md for architectural changes
- CHANGELOG.md for all changes
- Migration guides for breaking changes

## Pull Request Process

### Before Submitting

1. **Update from Upstream**:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Run Quality Checks**:
   ```bash
   mix format
   mix credo --strict
   mix dialyzer
   mix test
   mix docs
   ```

3. **Update Documentation**:
   - Add/update relevant documentation
   - Update CHANGELOG.md
   - Add migration guide if needed

### PR Guidelines

1. **Title Format**: Use conventional commits
   - `feat: Add new MCP capability discovery`
   - `fix: Resolve variety calculation error`
   - `docs: Update deployment guide`
   - `test: Add System 4 integration tests`
   - `refactor: Simplify variety calculator`

2. **Description Template**:
   ```markdown
   ## Description
   Brief description of changes

   ## Motivation
   Why these changes are needed

   ## Changes Made
   - Change 1
   - Change 2

   ## Testing
   How the changes were tested

   ## Breaking Changes
   List any breaking changes

   ## Checklist
   - [ ] Tests pass
   - [ ] Documentation updated
   - [ ] CHANGELOG.md updated
   - [ ] Code formatted
   - [ ] Credo passes
   ```

3. **PR Size**: Keep PRs focused and reasonable in size
   - Ideal: < 400 lines changed
   - Large features: Split into multiple PRs

### Review Process

1. **Automated Checks**: CI must pass
2. **Code Review**: At least one maintainer review
3. **Discussion**: Address feedback constructively
4. **Updates**: Push changes to the same branch
5. **Merge**: Maintainer merges when approved

## Issue Guidelines

### Creating Issues

Use issue templates for:
- **Bug Reports**: Describe the bug, steps to reproduce, expected behavior
- **Feature Requests**: Describe the feature, use cases, proposed solution
- **Questions**: Ask in discussions first, create issue if needed

### Issue Labels

- `bug`: Something isn't working
- `enhancement`: New feature or request
- `documentation`: Documentation improvements
- `good first issue`: Good for newcomers
- `help wanted`: Extra attention needed
- `performance`: Performance improvements
- `security`: Security vulnerabilities

## Community

### Communication Channels

- **GitHub Discussions**: For questions and discussions
- **Discord**: Real-time chat (link in README)
- **GitHub Issues**: For bugs and features
- **Twitter**: @vsmcp for updates

### Getting Help

1. Check documentation first
2. Search existing issues
3. Ask in GitHub Discussions
4. Join Discord for real-time help

### Recognition

Contributors are recognized in:
- CONTRIBUTORS.md file
- Release notes
- Project documentation
- Community highlights

## VSM-Specific Contributions

### System Enhancements

When contributing to VSM systems:

1. **Understand VSM Theory**: Read Beer's works
2. **Maintain Recursion**: Preserve fractal nature
3. **Respect Autonomy**: Don't over-centralize
4. **Consider Variety**: Impact on variety management
5. **Test Interactions**: System interdependencies

### MCP Integration

For MCP-related contributions:

1. **Follow MCP Spec**: Adhere to protocol standards
2. **Security First**: Validate all external tools
3. **Capability Documentation**: Document new capabilities
4. **Integration Tests**: Test with real MCP servers
5. **Error Handling**: Graceful degradation

## Legal

By contributing, you agree that your contributions will be licensed under the same license as the project (MIT License).

## Thank You!

Your contributions make VSMCP better for everyone. We appreciate your time, effort, and expertise!

---

<p align="center">
  <i>"The purpose of a system is what it does"</i> - Stafford Beer
</p>