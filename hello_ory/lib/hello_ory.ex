defmodule HelloOry do
  @moduledoc """
  This project allows you to run a simple client and server that implements an OAuth 2.0 "client
  credentials" workflow, allowing for machine-to-machine authentication and authorization.

  This module contains two different types of functions:
    - High-level helper functions that verify this workflow with the least amount of effort
    - Low-level functions for manually creating and using OAuth 2.0 client credentials

  ## Examples

  > #### Tip {: .tip}
  >
  > Before continuing, make sure that you have started the Compose service (which manages the
  > Ory stack applications) and configured this Elixir application with OAuth client credentials.
  > (You will need 2 sets of credentials: one for the Elixir HTTP server, and one for the IEx
  > "client".)

  ### High-level helper functions

  Access the unprotected route on the Elixir HTTP server (no access token required):

      iex> HelloOry.send_request_to_unprotected_endpoint()
      {:ok, %Req.Response{status: 200, body: "Hello, world!\n"}}

  Attempt to access the protected route on the Elixir HTTP server with an invalid token:

      iex> HelloOry.send_request_to_protected_endpoint("invalid-token")
      {:ok, %Req.Response{status: 401, body: "401 Unauthorized\n"}}

  Get an access token via the Hydra public API:

      iex> access_token = HelloOry.get_access_token_for_elixir_client()
      "ory_at_0000000000000000000000000000000000000000000.0000000000000000000000000000000000000000000"

  Use the access token to access the protected route on the Elixir HTTP server:

      iex> HelloOry.send_request_to_protected_endpoint(access_token)
      {:ok, %Req.Response{status: 200, body: "Access granted!\n"}}

  ### Lower-level functions

  Create an OAuth 2.0 client via the Hydra admin API (this part is not strictly necessary if you
  followed the instructions in the project README file, also the functionality is duplicated by
  the shell script at `../../create-client-credentials-grant.sh`):

      iex> {:ok, create_client_credentials_grant_response_body} =
      ...>   HelloOry.create_client_credentials_grant()
      {:ok, %{"client_id" => "00000000-0000-0000-0000-000000000000", ...}}

  Use this response to fetch an access token:

      iex> {:ok, fetch_access_token_response_body} =
      ...>   HelloOry.fetch_access_token(create_client_credentials_grant_response_body)
      {:ok, %{"access_token" => "ory_at_000000...", ...}}

  Introspect the access token via the Hydra public API (the Elixir HTTP server does this to verify
  the token):

      iex> HelloOry.introspect_access_token(
      ...>   create_client_credentials_grant_response_body,
      ...>   fetch_access_token_response_body
      ...> )
      {:ok, %{"active" => true, ...}}

  Use the access token to access the protected URL route:

      iex> HelloOry.send_request_to_protected_endpoint(access_token)
      {:ok, %Req.Response{status: 200, body: "Access granted!\n"}}
  """

  require Logger

  @audience ["my-server"]
  @scope "secrets:read"

  ## High-level helper functions

  @doc "A helper function that fetches a new, valid Hydra access token for our Elixir client."
  def get_access_token_for_elixir_client(opts \\ []) do
    scope = Keyword.get(opts, :scope, @scope)

    client_oauth_client_id = fetch_config!(:client, :oauth_client_id)
    client_oauth_client_secret = fetch_config!(:client, :oauth_client_secret)

    case fetch_access_token(client_oauth_client_id, client_oauth_client_secret, opts) do
      {:ok, %{"access_token" => access_token}} ->
        access_token

      {:error, {:ok, %Req.Response{body: %{"error" => "invalid_scope"}}}} ->
        Logger.warning(
          "The given OAuth client credentials do not have the required scope \"#{scope}\"."
        )

        nil

      result ->
        Logger.warning(
          "Received an unexpected response when attempting to get access token for Elixir client."
        )

        result |> IO.inspect(syntax_colors: IO.ANSI.syntax_colors())

        nil
    end
  end

  @doc "Make a request to the protected endpoint in `HelloOry.Router` using an `access_token`."
  @spec send_request_to_protected_endpoint(String.t() | nil) ::
          {:ok, Req.Response.t()} | {:error, any()}
  def send_request_to_protected_endpoint(access_token)

  def send_request_to_protected_endpoint(nil), do: {:error, :invalid_token}

  def send_request_to_protected_endpoint(access_token) do
    Req.new(
      url: "http://127.0.0.1:#{fetch_config!(:server, :port)}/protected",
      auth: {:bearer, access_token}
    )
    |> Req.get()
    |> then(fn
      {:ok, %Req.Response{status: 200} = resp} -> {:ok, resp}
      {:ok, %Req.Response{} = resp} -> {:error, resp}
      result -> {:error, result}
    end)
  end

  @doc "Make a request to the unprotected endpoint in `HelloOry.Router`."
  @spec send_request_to_unprotected_endpoint :: :ok | {:error, any()}
  def send_request_to_unprotected_endpoint do
    Req.get("http://127.0.0.1:#{fetch_config!(:server, :port)}/")
    |> then(fn
      {:ok, %Req.Response{status: 200} = resp} -> {:ok, resp}
      {:ok, %Req.Response{} = resp} -> {:error, resp}
      result -> {:error, result}
    end)
  end

  ## Low-level functions

  @doc """
  Create an OAuth client credentials grant for machine-to-machine authentication via the Hydra
  admin API.

  This function can be used instead of `../../create-client-credentials-grant.sh` when generating
  new client ID/secret pairs.
  """
  @spec create_client_credentials_grant(keyword()) :: {:ok, map()} | {:error, any()}
  def create_client_credentials_grant(opts \\ []) do
    audience = Keyword.get(opts, :audience, @audience)
    scope = Keyword.get(opts, :scope, @scope)

    Req.new(
      url: "#{fetch_config!(:hydra, :admin_api_base_url)}/admin/clients",
      auth: {:bearer, fetch_config!(:hydra, :admin_api_bearer_token)},
      json: %{
        # access_token_strategy: "jwt", # Use JWT for stateless auth
        grant_types: ["client_credentials"],
        audience: audience,
        scope: scope,
        token_endpoint_auth_method: "client_secret_post"
      }
    )
    |> Req.post()
    |> then(fn
      {:ok, %Req.Response{status: 201} = resp} -> {:ok, resp.body}
      result -> {:error, result}
    end)
  end

  @doc "Fetch a new access token via the Hydra public API."
  @spec fetch_access_token(map()) :: {:ok, map()} | {:error, any()}
  def fetch_access_token(
        %{"client_id" => client_id, "client_secret" => client_secret} =
          _create_client_credentials_grant_response_body
      ) do
    fetch_access_token(client_id, client_secret)
  end

  def fetch_access_token(client_id, client_secret, opts \\ []) do
    audience = Keyword.get(opts, :audience, @audience)
    scope = Keyword.get(opts, :scope, @scope)

    Req.new(
      url: "#{fetch_config!(:hydra, :public_api_base_url)}/oauth2/token",
      auth: {:bearer, client_secret},
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

  @doc "Introspect the contents of an `/oauth2/token` response via the Hydra public API."
  def introspect_access_token(
        %{"client_id" => client_id, "client_secret" => client_secret} =
          _create_client_credentials_grant_response_body,
        %{"access_token" => access_token} =
          _fetch_access_token_response_body
      ) do
    introspect_access_token(client_id, client_secret, access_token)
  end

  @doc "Introspect the contents of an `/oauth2/token` response via the Hydra public API."
  def introspect_access_token(client_id, client_secret, access_token) do
    Req.new(
      url: "#{fetch_config!(:hydra, :admin_api_base_url)}/admin/oauth2/introspect",
      auth: {:basic, "#{client_id}:#{client_secret}"},
      form: [token: access_token]
    )
    |> Req.post()
    |> then(fn
      {:ok, %Req.Response{status: 200} = resp} ->
        Logger.debug(
          "Hydra returned fresh introspection data which is guaranteed to be up-to-date."
        )

        {:ok, resp.body}

      result ->
        Logger.warning("""
        Got an unexpected response from the Hydra server which does not contain an access token.\
        """)

        {:error, result}
    end)
  end

  ## Other helper functions

  @doc """
  Fetch a config item for a given `context` and `key`.

  ## Examples

      iex> HelloOry.fetch_config!(:hydra, :admin_api_base_url)
      "http://127.0.0.1:4445"
  """
  def fetch_config!(context, key),
    do: Application.fetch_env!(:hello_ory, context) |> Keyword.fetch!(key)
end
