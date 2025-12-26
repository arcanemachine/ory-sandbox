defmodule HelloOry.Application do
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      {Plug.Cowboy, scheme: :http, plug: HelloOry.Router, options: [port: get_server_port()]}
    ]

    opts = [strategy: :one_for_one, name: HelloOry.Supervisor]

    log_diagnostic_info()

    Supervisor.start_link(children, opts)
  end

  defp get_server_port, do: HelloOry.fetch_config!(:server, :port)

  defp log_diagnostic_info do
    Logger.debug("HTTP server listening on port #{get_server_port()}...")

    for context <- [:client, :server],
        key <- [:oauth_client_id, :oauth_client_secret] do
      if Application.get_env(:hello_ory, context) |> get_in([key]) == nil do
        Logger.warning("""
        The application configuration for the context `:#{context}` and key `:#{key}` must not \
        be empty. Requests to the Elixir HTTP server will not succeed unless these items are \
        configured. For more info, see the runtime config.\
        """)
      end
    end

    :ok
  end
end
