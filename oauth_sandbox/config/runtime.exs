import Config

config :oauth_sandbox, :elixir_server, port: String.to_integer(System.get_env("PORT", "8000"))

config :oauth_sandbox, :keycloak,
  base_url: "http://127.0.0.1:8080",
  realm: "my-realm"

config :oauth_sandbox, :ory_hydra,
  admin_api_base_url: "http://127.0.0.1:4445",
  admin_api_bearer_token: "_______________YOUR_HYDRA_ADMIN_API_BEARER_TOKEN________________",
  public_api_base_url: "http://127.0.0.1:4444"

# Import local runtime config file
local_runtime_config_file_path = Path.join(__DIR__, "runtime.local.exs")

if File.exists?(local_runtime_config_file_path) do
  IO.puts("Importing local runtime config from file `#{local_runtime_config_file_path}`...")

  Code.eval_file(local_runtime_config_file_path)
else
  raise "expected to find local runtime config file at `#{local_runtime_config_file_path}`"
end
