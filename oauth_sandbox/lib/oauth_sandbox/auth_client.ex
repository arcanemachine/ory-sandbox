defmodule OauthSandbox.AuthClient do
  @moduledoc """
  The AuthClient behavior.

  This module delegates function calls to the configured auth client (e.g.
  `OauthSandbox.AuthClient.Ory`).
  """

  @doc "Check if an access token is valid."
  @callback access_token_is_valid?(access_token :: String.t()) :: boolean()

  @doc "Fetch a new access token from the auth server."
  @callback fetch_access_token(
              client_id :: String.t(),
              client_secret :: String.t(),
              opts :: keyword()
            ) :: {:ok, map()} | {:error, any()}
  def fetch_access_token(client_id, client_secret, opts \\ []),
    do: get_impl().fetch_access_token(client_id, client_secret, opts)

  defp get_impl, do: Application.get_env(:oauth_sandbox, :auth_client, OauthSandbox.AuthClients.Ory)
end
