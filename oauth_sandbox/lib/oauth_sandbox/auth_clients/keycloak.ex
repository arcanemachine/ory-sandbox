defmodule OauthSandbox.AuthClients.Keycloak do
  @moduledoc "The `OauthSandbox.AuthClient` implementation for Keycloak."

  @behaviour OauthSandbox.AuthClient

  alias OauthSandbox.Constants, as: C
  alias OauthSandbox.AuthClients.Keycloak.Token

  require Logger

  @doc """
  Fetch a Keycloak config value.

  ## Examples

      iex> OauthSandbox.AuthClient.Keycloak.fetch_config!(:base_url)
      "http://127.0.0.1:8080"
  """
  def fetch_config!(key),
    do: Application.fetch_env!(:oauth_sandbox, :keycloak) |> Keyword.fetch!(key)

  ## AuthClient

  @impl true
  def access_token_is_valid?(access_token) do
    case Token.verify_and_validate(access_token) do
      {:ok, _claims} -> true
      _ -> false
    end
  end

  @impl true
  def fetch_access_token(client_id, client_secret, opts \\ []) do
    audience = Keyword.get(opts, :audience, [C.elixir_server_expected_oauth_audience()])
    scope = Keyword.get(opts, :scope, C.elixir_server_expected_oauth_scope())

    Req.new(
      url:
        "#{fetch_config!(:base_url)}/realms/#{fetch_config!(:realm)}/protocol/openid-connect/token",
      form:
        [
          grant_type: "client_credentials",
          client_id: client_id,
          client_secret: client_secret,
          scope: scope
        ]
        |> then(fn form_params ->
          # Put an 'audience' form param for each audience item
          audience
          |> Enum.reduce(form_params, fn audience_item, acc_form_params ->
            acc_form_params ++ [audience: audience_item]
          end)
        end)
    )
    |> Req.post()
    |> then(fn
      {:ok, %Req.Response{status: 200} = resp} -> {:ok, resp.body}
      result -> {:error, result}
    end)
  end
end
