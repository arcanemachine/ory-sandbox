defmodule OauthSandbox.AuthClients.Ory do
  @moduledoc """
  The `OauthSandbox.AuthClient` implementation for Ory.

  ## Using the OAuth client credentials workflow

  Create an OAuth 2.0 client (this part is not strictly necessary if you followed the instructions
  in the project README file, also the functionality is duplicated by the shell script at
  `../../../create-client-credentials-grant.sh`):

      iex> {:ok, create_client_credentials_grant_response_body} =
      ...>   OauthSandbox.AuthClients.SomeClient.create_client_credentials_grant()
      {:ok, %{"client_id" => "00000000-0000-0000-0000-000000000000", ...}}

  Use this response to fetch an access token:

      iex> {:ok, fetch_access_token_response_body} =
      ...>   OauthSandbox.AuthClients.SomeClient.fetch_access_token(
      ...>     create_client_credentials_grant_response_body
      ...>   )
      {:ok, %{"access_token" => "ory_at_000000...", ...}}

  Introspect the access token:

      iex> OauthSandbox.AuthClients.SomeClient.introspect_access_token(
      ...>   create_client_credentials_grant_response_body,
      ...>   fetch_access_token_response_body
      ...> )
      {:ok, %{"active" => true, ...}}

  Use the access token to arcess the protected URL route:

      iex> OauthSandbox.send_request_to_protected_endpoint(access_token)
      {:ok, %Req.Response{status: 200, body: "Access granted!\n"}}
  """

  @behaviour OauthSandbox.AuthClient

  alias OauthSandbox.Constants, as: C
  require Logger

  @doc """
  Fetch an Ory Hydra config value.

  ## Examples

      iex> OauthSandbox.AuthClient.Ory.fetch_config!(:admin_api_base_url)
      "http://127.0.0.1:4445"
  """
  def fetch_config!(key),
    do: Application.fetch_env!(:oauth_sandbox, :ory_hydra) |> Keyword.fetch!(key)

  ## AuthClient

  @impl true
  def access_token_is_valid?(access_token) do
    elixir_server_oauth_client_id =
      OauthSandbox.fetch_config!(:elixir_server, :oauth_client_id)

    elixir_server_oauth_client_secret =
      OauthSandbox.fetch_config!(:elixir_server, :oauth_client_secret)

    with {:ok, introspected_access_token} <-
           introspect_access_token(
             elixir_server_oauth_client_id,
             elixir_server_oauth_client_secret,
             access_token
           ),
         true <- introspected_access_token_is_active?(introspected_access_token),
         true <- introspected_access_token_has_expected_client_id?(introspected_access_token),
         true <- introspected_access_token_has_expected_audience?(introspected_access_token),
         true <- introspected_access_token_has_expected_scope?(introspected_access_token) do
      true
    else
      _ ->
        false
    end
  end

  @doc "Create a new OAuth client using the Client Credentials grant."
  def create_client_credentials_grant(opts \\ []) do
    audience = Keyword.get(opts, :audience, [C.elixir_server_expected_oauth_audience()])
    scope = Keyword.get(opts, :scope, C.elixir_server_expected_oauth_scope())

    Req.new(
      url: "#{fetch_config!(:admin_api_base_url)}/admin/clients",
      auth: {:bearer, fetch_config!(:admin_api_bearer_token)},
      json: %{
        # access_token_strategy: "jwt", # Use JWT for stateless auth (Hydra defaults to non-JWT)
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

  @doc "Fetch an access token using the `create_client_credentials_grant_response_body`."
  def fetch_access_token(
        %{"client_id" => client_id, "client_secret" => client_secret} =
          _create_client_credentials_grant_response_body
      ) do
    fetch_access_token(client_id, client_secret)
  end

  @impl true
  def fetch_access_token(client_id, client_secret, opts \\ []) do
    audience = Keyword.get(opts, :audience, [C.elixir_server_expected_oauth_audience()])
    scope = Keyword.get(opts, :scope, C.elixir_server_expected_oauth_scope())

    Req.new(
      url: "#{fetch_config!(:public_api_base_url)}/oauth2/token",
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

  @doc "Use the introspection endpoint to examine the contents of an access token."
  def introspect_access_token(
        %{"client_id" => client_id, "client_secret" => client_secret} =
          _create_client_credentials_grant_response_body,
        %{"access_token" => access_token} =
          _fetch_access_token_response_body
      ) do
    introspect_access_token(client_id, client_secret, access_token)
  end

  @doc "Use the introspection endpoint to examine the contents of an access token."
  def introspect_access_token(client_id, client_secret, access_token) do
    Req.new(
      url: "#{fetch_config!(:admin_api_base_url)}/admin/oauth2/introspect",
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

  defp introspected_access_token_has_expected_audience?(
         %{"aud" => audiences} = _introspected_access_token
       ) do
    expected_audience = C.elixir_server_expected_oauth_audience()

    if audiences |> Enum.any?(&(&1 == expected_audience)) do
      Logger.debug("The access token has the expected audience.")

      true
    else
      Logger.warning("""
      Got an access token without the required audience. Got `#{inspect(audiences)}`, but \
      expected one of the values to be \"#{expected_audience}\".\
      """)

      false
    end
  end

  defp introspected_access_token_has_expected_client_id?(
         %{"client_id" => client_id} = _introspected_access_token
       ) do
    expected_client_id = OauthSandbox.fetch_config!(:elixir_client, :oauth_client_id)

    if client_id == expected_client_id do
      Logger.debug("The access token has the expected client ID.")

      true
    else
      Logger.warning("""
      The access token has an unexpected client ID. Got \"#{client_id}\", but expected \
      \"#{expected_client_id}\".\
      """)

      false
    end
  end

  defp introspected_access_token_has_expected_scope?(
         %{"scope" => scopes} = _introspected_access_token
       ) do
    expected_scope = C.elixir_server_expected_oauth_scope()

    if scopes |> String.split() |> Enum.any?(&(&1 == expected_scope)) do
      Logger.debug("The access token has the expected scope.")

      true
    else
      Logger.warning("""
      Got an access token without the required scope. Expected scope to contain the \
      configured value: \"#{expected_scope}\"\
      """)

      false
    end
  end

  defp introspected_access_token_is_active?(introspected_access_token) do
    case introspected_access_token do
      %{"active" => true} ->
        Logger.debug("The access token is valid and not expired.")

        true

      %{"active" => false} ->
        Logger.warning("""
        Got an inactive (invalid or expired) access token. (Client token may also have an \
        audience that is not included in the HTTP server's client credentials grant.)\
        """)

        false
    end
  end
end
