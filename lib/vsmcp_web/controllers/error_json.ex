defmodule VsmcpWeb.ErrorJSON do
  # If you want to customize a particular status code,
  # you may add your own clauses, such as:
  #
  # def render("500.json", _assigns) do
  #   %{errors: %{detail: "Internal Server Error"}}
  # end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.json" becomes
  # "Not Found".
  def render(template, _assigns) do
    %{
      errors: %{
        detail: Phoenix.Controller.status_message_from_template(template),
        code: extract_status_code(template),
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        subsystem: "vsmcp_web"
      }
    }
  end

  defp extract_status_code(template) do
    template
    |> String.split(".")
    |> List.first()
    |> String.to_integer()
  rescue
    _ -> 500
  end
end