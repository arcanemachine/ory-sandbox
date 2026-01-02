defmodule OauthSandbox.Router do
  @moduledoc "The main Plug router."

  use Plug.Router
  require Logger

  plug :match
  plug :dispatch

  get "/" do
    send_resp(conn, 200, "Hello, world!\n")
  end

  get "/protected" do
    auth_client = OauthSandbox.fetch_config!(:auth_client)

    case conn |> get_req_header("authorization") do
      ["Bearer " <> access_token] ->
        if auth_client.access_token_is_valid?(access_token) do
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

  defp handle_unauthorized_request(conn),
    do: conn |> send_resp(401, "401 Unauthorized\n") |> halt()
end
