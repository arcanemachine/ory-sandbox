defmodule HelloOry.Router do
  @moduledoc "The main Plug router."

  use Plug.Router
  require Logger

  @expected_audience "my-server"
  @expected_scope "secrets:read"

  plug :match
  plug :dispatch

  get "/" do
    send_resp(conn, 200, "Hello, world!\n")
  end

  get "/protected" do
    case conn |> get_req_header("authorization") do
      ["Bearer " <> access_token] ->
        if access_token_is_valid?(access_token) do
          send_resp(conn, 200, "Access granted!\n")
        else
          conn |> handle_unauthorized_request()
        end

      _ ->
        conn |> handle_unauthorized_request()
    end
  end

  match _ do
    send_resp(conn, 404, "404 Not found\n")
  end

  defp access_token_is_valid?(access_token) do
    server_oauth_client_id = HelloOry.fetch_config!(:server, :oauth_client_id)
    server_oauth_client_secret = HelloOry.fetch_config!(:server, :oauth_client_secret)

    with {:ok, introspected_access_token} <-
           HelloOry.introspect_access_token(
             server_oauth_client_id,
             server_oauth_client_secret,
             access_token
           ),
         true <- introspected_access_token_is_active?(introspected_access_token),
         true <- introspected_access_token_has_expected_client_id?(introspected_access_token),
         true <- introspected_access_token_has_expected_audience?(introspected_access_token),
         true <- introspected_access_token_has_expected_scope?(introspected_access_token) do
      true
    else
      _result ->
        false
    end
  end

  defp handle_unauthorized_request(conn),
    do: conn |> send_resp(401, "401 Unauthorized\n") |> halt()

  defp introspected_access_token_has_expected_audience?(
         %{"aud" => audiences} = _introspected_access_token
       ) do
    if audiences |> Enum.any?(&(&1 == @expected_audience)) do
      Logger.debug("The access token has the expected audience.")

      true
    else
      Logger.warning("""
      Got an access token without the required audience. Got `#{inspect(audiences)}`, but \
      expected one of the values to be \"#{@expected_audience}\".\
      """)

      false
    end
  end

  defp introspected_access_token_has_expected_client_id?(
         %{"client_id" => client_id} = _introspected_access_token
       ) do
    expected_client_id = HelloOry.fetch_config!(:client, :oauth_client_id)

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
    if scopes |> String.split() |> Enum.any?(&(&1 == @expected_scope)) do
      Logger.debug("The access token has the expected scope.")

      true
    else
      Logger.warning("""
      Got an access token without the required scope. Expected scope to contain the \
      configured value: \"#{@expected_scope}\"\
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
