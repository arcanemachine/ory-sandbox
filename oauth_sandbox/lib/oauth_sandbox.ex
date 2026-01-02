defmodule OauthSandbox do
  @moduledoc """
  This project implements a simple IEx client and HTTP server that manages an OAuth 2.0 "client
  credentials" workflow, allowing for machine-to-machine authentication and authorization.

  This module contains high-level helper functions that implement this workflow with the least
  amount of effort. For lower-level functionality, see the `OauthSandbox.AuthClient` implementation
  for the desired provider (e.g. `OauthSandbox.AuthClients`).

  ## Examples

  > #### Tip {: .tip}
  >
  > Before following the examples, make sure that you have started the desired Compose service for
  > the auth server (e.g. Keycloak, Ory) and configured this Elixir application with valid OAuth
  > client credentials for the running server.
  >
  > Remember, you need 2 sets of credentials: one for the Elixir HTTP server, and one for the IEx
  > "client". For more info, see `../../README.md`.

  ### High-level helper functions

  Access the unprotected route on the Elixir HTTP server (no access token required):

      iex> OauthSandbox.send_request_to_unprotected_endpoint()
      {:ok, %Req.Response{status: 200, body: "Hello, world!\n"}}

  Attempt to access the protected route on the Elixir HTTP server with an invalid token:

      iex> OauthSandbox.send_request_to_protected_endpoint("invalid-token")
      {:ok, %Req.Response{status: 401, body: "401 Unauthorized\n"}}

  Get an access token via the configured auth server:

      iex> access_token = OauthSandbox.fetch_access_token_for_elixir_client(OauthSandbox.AuthClients.Ory)
      "ory_at_0000000000000000000000000000000000000000000.0000000000000000000000000000000000000000000"

  Use the access token to access the protected route on the Elixir HTTP server:

      iex> OauthSandbox.send_request_to_protected_endpoint(access_token)
      {:ok, %Req.Response{status: 200, body: "Access granted!\n"}}

  """

  require Logger

  ## High-level helper functions

  @doc """
  A helper function that fetches a new, valid OAuth access token for our Elixir client, using the
  configured OAuth provider.

  ## Examples

      iex> OauthSandbox.fetch_access_token_for_elixir_client()
      {:ok,
       "ory_at_0000000000000000000000000000000000000000000.0000000000000000000000000000000000000000000"}
  """
  @spec fetch_access_token_for_elixir_client(keyword()) :: {:ok, String.t()} | {:error, any()}
  def fetch_access_token_for_elixir_client(opts \\ []) do
    auth_client = __MODULE__.fetch_config!(:auth_client)
    elixir_client_oauth_client_id = fetch_config!(:elixir_client, :oauth_client_id)
    elixir_client_oauth_client_secret = fetch_config!(:elixir_client, :oauth_client_secret)

    case auth_client.fetch_access_token(
           elixir_client_oauth_client_id,
           elixir_client_oauth_client_secret,
           opts
         ) do
      {:ok, %{"access_token" => access_token}} -> {:ok, access_token}
      result -> {:error, result}
    end
  end

  @doc "Make a request to the protected endpoint in `OauthSandbox.Router` using an `access_token`."
  @spec send_request_to_protected_endpoint(String.t() | nil) ::
          {:ok, Req.Response.t()} | {:error, any()}
  def send_request_to_protected_endpoint(access_token)

  def send_request_to_protected_endpoint(nil), do: {:error, :invalid_token}

  def send_request_to_protected_endpoint(access_token) do
    Req.new(
      url: "http://127.0.0.1:#{fetch_config!(:elixir_server, :port)}/protected",
      auth: {:bearer, access_token}
    )
    |> Req.get()
    |> then(fn
      {:ok, %Req.Response{status: 200} = resp} -> {:ok, resp}
      {:ok, %Req.Response{} = resp} -> {:error, resp}
      result -> {:error, result}
    end)
  end

  @doc "Make a request to the unprotected endpoint in `OauthSandbox.Router`."
  @spec send_request_to_unprotected_endpoint :: :ok | {:error, any()}
  def send_request_to_unprotected_endpoint do
    Req.get("http://127.0.0.1:#{fetch_config!(:elixir_server, :port)}/")
    |> then(fn
      {:ok, %Req.Response{status: 200} = resp} -> {:ok, resp}
      {:ok, %Req.Response{} = resp} -> {:error, resp}
      result -> {:error, result}
    end)
  end

  ## Other helper functions

  @doc """
  Fetch an item from the top-level application context.

  ## Examples

      iex> OauthSandbox.fetch_config!(:auth_client)
      OauthSandbox.AuthClient.Ory
  """
  def fetch_config!(key), do: Application.fetch_env!(:oauth_sandbox, key)

  @doc """
  Fetch a config item for a given `context` and `key`.

  ## Examples

      iex> OauthSandbox.fetch_config!(:elixir_server, :port)
      8000
  """
  def fetch_config!(context, key),
    do: Application.fetch_env!(:oauth_sandbox, context) |> Keyword.fetch!(key)
end
