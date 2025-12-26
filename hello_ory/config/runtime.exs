import Config

config :hello_ory, :hydra,
  admin_api_base_url: "http://127.0.0.1:4445",
  admin_api_bearer_token: "_______________YOUR_HYDRA_ADMIN_API_BEARER_TOKEN________________",
  public_api_base_url: "http://127.0.0.1:4444"

config :hello_ory, :client,
  # To create an OAuth client ID and secret, see `../../README.md`
  oauth_client_id: System.get_env("CLIENT_OAUTH_CLIENT_ID"),
  oauth_client_secret: System.get_env("CLIENT_OAUTH_CLIENT_SECRET")

config :hello_ory, :server,
  # To create an OAuth client ID and secret, see `../../README.md`
  oauth_client_id: System.get_env("SERVER_OAUTH_CLIENT_ID"),
  oauth_client_secret: System.get_env("SERVER_OAUTH_CLIENT_SECRET"),
  port: String.to_integer(System.get_env("PORT", "8000"))
