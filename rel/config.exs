# Release configuration for VSMCP

~w(rel plugins *.exs)
|> Path.join()
|> Path.wildcard()
|> Enum.map(&Code.eval_file(&1))

use Distillery.Releases.Config,
    default_release: :default,
    default_environment: Mix.env()

# For a full list of config options for both releases
# and environments, visit https://hexdocs.pm/distillery/config/distillery.html

# Environment configuration
environment :dev do
  set dev_mode: true
  set include_erts: false
  set cookie: :"vsmcp_dev_cookie"
  set vm_args: "rel/vm.args.dev"
  set config_providers: [
    {Config.Reader, {:system, "RELEASE_ROOT", "/config/config.exs"}}
  ]
end

environment :prod do
  set include_erts: true
  set include_src: false
  set cookie: :"${VSMCP_COOKIE}"
  set vm_args: "rel/vm.args.prod"
  set pre_start_hooks: "rel/hooks/pre_start"
  set post_start_hooks: "rel/hooks/post_start"
  set config_providers: [
    {Config.Reader, {:system, "RELEASE_ROOT", "/config/config.exs"}}
  ]
  
  # Daemon mode configuration
  set daemon_mode: true
  set output_dir: "rel/vsmcp"
  
  # Systemd integration
  set systemd: [
    app: :vsmcp,
    service_name: "vsmcp",
    working_directory: "/opt/vsmcp",
    user: "vsmcp",
    group: "vsmcp",
    restart: :on_failure,
    restart_sec: 5,
    limit_nofile: 65536
  ]
end

# Release configuration
release :vsmcp do
  set version: current_version(:vsmcp)
  set applications: [
    :runtime_tools,
    :crypto,
    :ssl,
    :inets,
    :logger,
    vsmcp: :permanent
  ]
  
  # Custom commands for CLI control
  set commands: [
    start: "rel/commands/start.sh",
    stop: "rel/commands/stop.sh",
    status: "rel/commands/status.sh",
    health: "rel/commands/health.sh",
    variety_report: "rel/commands/variety_report.sh",
    mcp_capabilities: "rel/commands/mcp_capabilities.sh",
    console: "rel/commands/console.sh",
    remote_console: "rel/commands/remote_console.sh",
    daemon: "rel/commands/daemon.sh",
    daemon_stop: "rel/commands/daemon_stop.sh"
  ]
  
  # Overlays for configuration files
  set overlays: [
    {:copy, "rel/config/config.exs", "config/config.exs"},
    {:copy, "rel/config/runtime.exs", "config/runtime.exs"},
    {:template, "rel/config/vm.args.eex", "releases/<%= release_version %>/vm.args"},
    {:template, "rel/config/sys.config.eex", "releases/<%= release_version %>/sys.config"},
    {:copy, "rel/scripts/startup.sh", "bin/startup.sh"},
    {:copy, "rel/scripts/shutdown.sh", "bin/shutdown.sh"},
    {:copy, "rel/scripts/health_check.sh", "bin/health_check.sh"}
  ]
  
  # Plugins for enhanced functionality
  plugin Distillery.Releases.Plugin.Conform
end