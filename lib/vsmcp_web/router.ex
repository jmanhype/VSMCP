defmodule VsmcpWeb.Router do
  use VsmcpWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {VsmcpWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", VsmcpWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/dashboard", DashboardLive
    live "/systems", SystemsLive
    live "/telegram", TelegramLive
  end

  # API Routes for VSM Systems
  scope "/api", VsmcpWeb do
    pipe_through :api

    # System status endpoints
    get "/status", ApiController, :status
    get "/systems/:system_id/status", ApiController, :system_status
    
    # VSM operations
    post "/systems/1/execute", System1Controller, :execute
    post "/systems/2/coordinate", System2Controller, :coordinate
    post "/systems/3/audit", System3Controller, :audit
    post "/systems/4/scan", System4Controller, :scan
    post "/systems/5/policy", System5Controller, :set_policy
    
    # Variety management
    get "/variety/calculate", VarietyController, :calculate
    post "/variety/acquire", VarietyController, :acquire
    
    # MCP tool endpoints
    get "/mcp/tools", McpController, :list_tools
    post "/mcp/tools/call", McpController, :call_tool
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:vsmcp, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: VsmcpWeb.Telemetry
    end
  end
end