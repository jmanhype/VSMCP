defmodule VsmcpWeb.CoreComponents do
  @moduledoc """
  Provides core UI components for VSMCP with cybernetic VSM theming.
  
  This module contains reusable Phoenix components styled with a 
  cybernetic control system aesthetic inspired by Stafford Beer's 
  Viable System Model.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  import VsmcpWeb.Gettext

  @doc """
  Renders a VSM-styled navigation link.
  """
  attr :href, :string, required: true
  attr :active, :boolean, default: false
  slot :inner_block, required: true

  def nav_link(assigns) do
    ~H"""
    <.link
      href={@href}
      class={[
        "flex items-center space-x-2 px-3 py-2 rounded-lg transition-all duration-200",
        "border border-transparent hover:border-green-500/50",
        @active && "bg-green-500/20 border-green-500/50 text-green-400",
        !@active && "text-green-400/70 hover:text-green-400 hover:bg-green-500/10"
      ]}
    >
      <%= render_slot(@inner_block) %>
    </.link>
    """
  end

  @doc """
  Renders a VSM system status card.
  """
  attr :system, :integer, required: true
  attr :name, :string, required: true
  attr :status, :string, default: "operational"
  attr :metrics, :map, default: %{}
  attr :color, :string, default: "green"

  def system_card(assigns) do
    ~H"""
    <div class="relative group">
      <div class="absolute inset-0 bg-gradient-to-r from-{@color}-500/20 to-transparent rounded-lg blur-xl group-hover:blur-2xl transition-all duration-300"></div>
      <div class="relative bg-black/80 border border-{@color}-500/30 rounded-lg p-6 hover:border-{@color}-500/60 transition-all duration-300">
        <div class="flex items-start justify-between mb-4">
          <div>
            <h3 class="text-lg font-semibold text-{@color}-400 flex items-center space-x-2">
              <span class="w-8 h-8 bg-{@color}-500/20 rounded-full flex items-center justify-center text-sm font-bold">
                S<%= @system %>
              </span>
              <span><%= @name %></span>
            </h3>
            <p class="text-sm text-gray-400 mt-1">System <%= @system %></p>
          </div>
          <div class="flex items-center space-x-2">
            <div class={"w-2 h-2 rounded-full #{status_color(@status)} animate-pulse"}></div>
            <span class="text-xs text-gray-400 uppercase"><%= @status %></span>
          </div>
        </div>
        
        <div class="space-y-3">
          <%= for {key, value} <- @metrics do %>
            <div class="flex items-center justify-between text-sm">
              <span class="text-gray-400"><%= humanize(key) %></span>
              <span class="font-mono text-{@color}-400"><%= format_metric(value) %></span>
            </div>
          <% end %>
        </div>
        
        <div class="mt-4 pt-4 border-t border-{@color}-500/20">
          <div class="vsm-data-flow h-1 rounded-full bg-{@color}-500/20"></div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a VSM control panel.
  """
  attr :title, :string, required: true
  attr :class, :string, default: nil
  slot :actions, doc: "Panel action buttons"
  slot :inner_block, required: true

  def panel(assigns) do
    ~H"""
    <div class={["vsm-panel", @class]}>
      <div class="bg-black/90 border border-green-500/30 rounded-lg overflow-hidden">
        <div class="bg-gradient-to-r from-green-500/10 to-blue-500/10 px-6 py-4 border-b border-green-500/30">
          <div class="flex items-center justify-between">
            <h2 class="text-lg font-semibold text-green-400 vsm-glow">
              <%= @title %>
            </h2>
            <div :if={@actions} class="flex items-center space-x-2">
              <%= render_slot(@actions) %>
            </div>
          </div>
        </div>
        <div class="p-6">
          <%= render_slot(@inner_block) %>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a cybernetic button.
  """
  attr :type, :string, default: "button"
  attr :variant, :string, default: "primary"
  attr :size, :string, default: "md"
  attr :rest, :global, include: ~w(disabled form name value)
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "inline-flex items-center justify-center font-medium rounded-lg transition-all duration-200",
        "border focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-black",
        button_variant(@variant),
        button_size(@size)
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  @doc """
  Renders a VSM metric display.
  """
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :unit, :string, default: nil
  attr :trend, :string, default: nil
  attr :color, :string, default: "green"

  def metric(assigns) do
    ~H"""
    <div class="bg-black/60 border border-{@color}-500/20 rounded-lg p-4">
      <div class="text-sm text-gray-400 mb-1"><%= @label %></div>
      <div class="flex items-baseline space-x-2">
        <span class="text-2xl font-bold text-{@color}-400 font-mono">
          <%= format_metric(@value) %>
        </span>
        <span :if={@unit} class="text-sm text-gray-400"><%= @unit %></span>
        <span :if={@trend} class={trend_class(@trend)}>
          <%= trend_icon(@trend) %>
        </span>
      </div>
    </div>
    """
  end

  @doc """
  Renders flash notices.
  """
  attr :id, :string, default: "flash", doc: "the optional id of flash container"
  attr :flash, :map, required: true, doc: "the map of flash messages to display"
  attr :title, :string, default: nil

  def flash(assigns) do
    ~H"""
    <div
      :if={@flash != %{}}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      phx-hook="Flash"
      class={[
        "fixed top-4 right-4 z-50 p-4 rounded-lg border cursor-pointer",
        "transform transition-all duration-300 ease-out",
        flash_class(@kind)
      ]}
    >
      <div class="flex items-start space-x-3">
        <div class="flex-shrink-0">
          <%= flash_icon(@kind) %>
        </div>
        <div class="flex-1">
          <p :if={@title} class="font-semibold mb-1"><%= @title %></p>
          <p class="text-sm"><%= Phoenix.Flash.get(@flash, @kind) %></p>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a group of flash messages.
  """
  attr :flash, :map, required: true

  def flash_group(assigns) do
    ~H"""
    <.flash kind={:info} flash={@flash} />
    <.flash kind={:error} flash={@flash} />
    """
  end

  @doc """
  Renders a simple form.
  """
  attr :for, :any, required: true, doc: "the datastructure for the form"
  attr :as, :any, default: nil, doc: "the server side parameter to collect all input under"
  attr :rest, :global, include: ~w(action method phx-change phx-submit)
  slot :inner_block, required: true

  def simple_form(assigns) do
    ~H"""
    <.form for={@for} as={@as} {@rest}>
      <div class="space-y-6">
        <%= render_slot(@inner_block) %>
      </div>
    </.form>
    """
  end

  @doc """
  Renders an input with cybernetic styling.
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any
  attr :type, :string, default: "text"
  attr :field, Phoenix.HTML.FormField
  attr :errors, :list, default: []
  attr :rest, :global, include: ~w(autocomplete disabled placeholder readonly required)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(field.errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.value, do: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div>
      <.label for={@id}><%= @label %></.label>
      <textarea
        id={@id}
        name={@name}
        class={[
          "mt-2 block w-full rounded-lg bg-black/60 border-green-500/30",
          "text-green-400 placeholder-green-400/30",
          "focus:border-green-500 focus:ring-green-500/50",
          "sm:text-sm sm:leading-6",
          @errors != [] && "border-red-500/50 focus:border-red-500"
        ]}
        {@rest}
      ><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div>
      <.label for={@id}><%= @label %></.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          "mt-2 block w-full rounded-lg bg-black/60 border-green-500/30",
          "text-green-400 placeholder-green-400/30",
          "focus:border-green-500 focus:ring-green-500/50",
          "sm:text-sm sm:leading-6",
          @errors != [] && "border-red-500/50 focus:border-red-500"
        ]}
        {@rest}
      />
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  @doc """
  Renders a label.
  """
  attr :for, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class="block text-sm font-medium text-green-400/90">
      <%= render_slot(@inner_block) %>
    </label>
    """
  end

  @doc """
  Renders errors for inputs.
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="mt-2 text-sm text-red-400">
      <%= render_slot(@inner_block) %>
    </p>
    """
  end

  @doc """
  Renders a modal with cybernetic styling.
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div id={@id} phx-mounted={@show && show_modal(@id)} phx-remove={hide_modal(@id)} class="relative z-50 hidden">
      <div id={"#{@id}-backdrop"} class="fixed inset-0 bg-black/90 transition-opacity" aria-hidden="true" />
      <div class="fixed inset-0 overflow-y-auto">
        <div class="flex min-h-full items-center justify-center p-4 sm:p-0">
          <div
            id={"#{@id}-content"}
            phx-click-away={@on_cancel}
            phx-window-keydown={@on_cancel}
            phx-key="escape"
            class="relative transform overflow-hidden rounded-lg bg-black border border-green-500/50 text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-lg vsm-glow"
          >
            <div class="bg-black px-4 pb-4 pt-5 sm:p-6 sm:pb-4">
              <%= render_slot(@inner_block) %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  ## Helper Functions

  defp status_color("operational"), do: "bg-green-500"
  defp status_color("degraded"), do: "bg-yellow-500"
  defp status_color("critical"), do: "bg-red-500"
  defp status_color(_), do: "bg-gray-500"

  defp button_variant("primary") do
    [
      "bg-green-500/20 border-green-500/50 text-green-400",
      "hover:bg-green-500/30 hover:border-green-500",
      "focus:ring-green-500/50"
    ]
  end

  defp button_variant("secondary") do
    [
      "bg-blue-500/20 border-blue-500/50 text-blue-400",
      "hover:bg-blue-500/30 hover:border-blue-500",
      "focus:ring-blue-500/50"
    ]
  end

  defp button_variant("danger") do
    [
      "bg-red-500/20 border-red-500/50 text-red-400",
      "hover:bg-red-500/30 hover:border-red-500",
      "focus:ring-red-500/50"
    ]
  end

  defp button_variant(_), do: button_variant("primary")

  defp button_size("sm"), do: "px-3 py-1.5 text-sm"
  defp button_size("md"), do: "px-4 py-2 text-sm"
  defp button_size("lg"), do: "px-6 py-3 text-base"
  defp button_size(_), do: button_size("md")

  defp format_metric(value) when is_float(value), do: Float.round(value, 2)
  defp format_metric(value) when is_integer(value) and value > 999 do
    cond do
      value > 999_999 -> "#{Float.round(value / 1_000_000, 1)}M"
      value > 999 -> "#{Float.round(value / 1_000, 1)}K"
      true -> to_string(value)
    end
  end
  defp format_metric(value), do: to_string(value)

  defp humanize(atom) when is_atom(atom) do
    atom
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp trend_class("up"), do: "text-green-400"
  defp trend_class("down"), do: "text-red-400"
  defp trend_class(_), do: "text-gray-400"

  defp trend_icon("up"), do: "↑"
  defp trend_icon("down"), do: "↓"
  defp trend_icon(_), do: "→"

  defp flash_class(:info), do: "bg-blue-500/20 border-blue-500/50 text-blue-400"
  defp flash_class(:error), do: "bg-red-500/20 border-red-500/50 text-red-400"
  defp flash_class(_), do: "bg-green-500/20 border-green-500/50 text-green-400"

  defp flash_icon(:info) do
    ~s(<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
      <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
    </svg>)
  end

  defp flash_icon(:error) do
    ~s(<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
      <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
    </svg>)
  end

  def show_modal(id) do
    JS.show(
      to: "##{id}",
      time: 300,
      display: "inline-block",
      transition: {"transition-all transform ease-out duration-300", "opacity-0 scale-90", "opacity-100 scale-100"}
    )
    |> JS.show(
      to: "##{id}-backdrop",
      time: 300,
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
  end

  def hide_modal(id) do
    JS.hide(
      to: "##{id}",
      time: 200,
      transition: {"transition-all transform ease-in duration-200", "opacity-100 scale-100", "opacity-0 scale-90"}
    )
    |> JS.hide(
      to: "##{id}-backdrop", 
      time: 200,
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
  end

  defp hide(js \\ %JS{}, selector) do
    JS.hide(js, to: selector, time: 200, transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"})
  end

  def translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end
end