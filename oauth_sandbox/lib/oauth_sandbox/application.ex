defmodule OauthSandbox.Application do
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      {OauthSandbox.AuthClients.Keycloak.Token.Strategy, time_interval: 2_000},
      {Plug.Cowboy, scheme: :http, plug: OauthSandbox.Router, options: [port: get_server_port()]}
    ]

    opts = [strategy: :one_for_one, name: OauthSandbox.Supervisor]

    log_diagnostic_info()

    Supervisor.start_link(children, opts)
  end

  defp get_server_port, do: OauthSandbox.fetch_config!(:elixir_server, :port)

  defp log_diagnostic_info do
    Logger.debug("Configured auth client: #{inspect(OauthSandbox.fetch_config!(:auth_client))}")
    Logger.debug("HTTP server listening on port #{get_server_port()}...")

    for context <- [:elixir_client, :elixir_server],
        key <- [:oauth_client_id, :oauth_client_secret] do
      if Application.get_env(:oauth_sandbox, context) |> get_in([key]) == nil do
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
