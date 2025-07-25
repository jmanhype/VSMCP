defmodule Vsmcp.Release do
  @moduledoc """
  Release tasks for VSMCP.
  Used for database migrations, seed data, and other release-time operations.
  """

  require Logger

  @app :vsmcp

  @doc """
  Run database migrations
  """
  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  @doc """
  Rollback database migrations
  """
  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  @doc """
  Seed the database with initial data
  """
  def seed do
    load_app()
    
    # Add seed data logic here
    Logger.info("Seeding database...")
    
    # Example: Create default MCP servers
    create_default_mcp_servers()
    
    # Example: Create default VSM configurations
    create_default_vsm_configs()
    
    Logger.info("Database seeding complete")
  end

  @doc """
  Initialize the system on first run
  """
  def init_system do
    load_app()
    
    Logger.info("Initializing VSMCP system...")
    
    # Run migrations
    migrate()
    
    # Seed initial data
    seed()
    
    # Verify system components
    verify_system_components()
    
    Logger.info("VSMCP system initialization complete")
  end

  @doc """
  Health check for release
  """
  def health_check do
    load_app()
    
    case Vsmcp.CLI.health_check() do
      {:ok, message} ->
        IO.puts("✓ #{message}")
        System.halt(0)
        
      {:error, message, failures} ->
        IO.puts("✗ #{message}")
        Enum.each(failures, fn {check, _status, details} ->
          IO.puts("  - #{check}: #{details}")
        end)
        System.halt(1)
    end
  end

  @doc """
  Create a database backup
  """
  def backup_database(path \\ nil) do
    load_app()
    
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    backup_path = path || "/tmp/vsmcp_backup_#{timestamp}.sql"
    
    for repo <- repos() do
      config = repo.config()
      database = Keyword.get(config, :database)
      username = Keyword.get(config, :username)
      hostname = Keyword.get(config, :hostname, "localhost")
      
      cmd = "pg_dump -h #{hostname} -U #{username} -d #{database} -f #{backup_path}"
      
      case System.cmd("sh", ["-c", cmd], stderr_to_stdout: true) do
        {_, 0} ->
          Logger.info("Database backup created: #{backup_path}")
          {:ok, backup_path}
          
        {error, _} ->
          Logger.error("Database backup failed: #{error}")
          {:error, error}
      end
    end
  end

  @doc """
  Restore database from backup
  """
  def restore_database(backup_path) do
    load_app()
    
    unless File.exists?(backup_path) do
      Logger.error("Backup file not found: #{backup_path}")
      System.halt(1)
    end
    
    for repo <- repos() do
      config = repo.config()
      database = Keyword.get(config, :database)
      username = Keyword.get(config, :username)
      hostname = Keyword.get(config, :hostname, "localhost")
      
      # Drop and recreate database
      drop_cmd = "dropdb -h #{hostname} -U #{username} #{database} --if-exists"
      create_cmd = "createdb -h #{hostname} -U #{username} #{database}"
      restore_cmd = "psql -h #{hostname} -U #{username} -d #{database} -f #{backup_path}"
      
      with {_, 0} <- System.cmd("sh", ["-c", drop_cmd], stderr_to_stdout: true),
           {_, 0} <- System.cmd("sh", ["-c", create_cmd], stderr_to_stdout: true),
           {_, 0} <- System.cmd("sh", ["-c", restore_cmd], stderr_to_stdout: true) do
        Logger.info("Database restored from: #{backup_path}")
        {:ok, backup_path}
      else
        {error, _} ->
          Logger.error("Database restore failed: #{error}")
          {:error, error}
      end
    end
  end

  # Private functions

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
    
    # Ensure SSL is started
    Application.ensure_all_started(:ssl)
    
    # Start repos for migrations
    Enum.each(repos(), fn repo ->
      repo.__adapter__.ensure_all_started(repo.config(), :temporary)
      {:ok, _} = repo.start_link(pool_size: 2)
    end)
  end

  defp create_default_mcp_servers do
    # This is placeholder logic - implement based on your actual data model
    Logger.info("Creating default MCP servers...")
    
    # Example MCP servers to create
    default_servers = [
      %{
        name: "filesystem",
        type: :builtin,
        description: "File system operations",
        capabilities: ["read", "write", "delete", "list"]
      },
      %{
        name: "git",
        type: :builtin,
        description: "Git repository operations",
        capabilities: ["clone", "commit", "push", "pull", "branch"]
      },
      %{
        name: "sqlite",
        type: :external,
        description: "SQLite database operations",
        capabilities: ["query", "insert", "update", "delete", "schema"]
      }
    ]
    
    # Insert logic here based on your actual schema
    :ok
  end

  defp create_default_vsm_configs do
    # This is placeholder logic - implement based on your actual data model
    Logger.info("Creating default VSM configurations...")
    
    # Example VSM configurations
    default_configs = [
      %{
        name: "system1",
        description: "Operations management",
        variety_score: 0
      },
      %{
        name: "system2",
        description: "Coordination",
        variety_score: 0
      },
      %{
        name: "system3",
        description: "Control and audit",
        variety_score: 0
      },
      %{
        name: "system4",
        description: "Intelligence",
        variety_score: 0
      },
      %{
        name: "system5",
        description: "Policy and identity",
        variety_score: 0
      }
    ]
    
    # Insert logic here based on your actual schema
    :ok
  end

  defp verify_system_components do
    Logger.info("Verifying system components...")
    
    components = [
      {:amqp, "Message broker"},
      {:phoenix_pubsub, "PubSub system"},
      {:telemetry, "Telemetry system"},
      {:gen_stage, "Flow processing"}
    ]
    
    Enum.each(components, fn {app, name} ->
      case Application.ensure_all_started(app) do
        {:ok, _} ->
          Logger.info("✓ #{name} verified")
          
        {:error, reason} ->
          Logger.error("✗ #{name} failed: #{inspect(reason)}")
      end
    end)
  end
end