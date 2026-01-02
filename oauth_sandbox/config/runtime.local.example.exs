import Config

config :oauth_sandbox, auth_client: OauthSandbox.AuthClients.Ory

config :oauth_sandbox, :elixir_client,
  oauth_client_id: "your_elixir_client_oauth_client_id",
  oauth_client_secret: "your_elixir_client_oauth_client_secret"

config :oauth_sandbox, :elixir_server,
  oauth_client_id: "your_elixir_server_oauth_client_id",
  oauth_client_secret: "your_elixir_server_oauth_client_secret"
