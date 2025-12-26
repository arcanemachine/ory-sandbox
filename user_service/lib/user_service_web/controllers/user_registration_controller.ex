defmodule UserServiceWeb.UserRegistrationController do
  use UserServiceWeb, :controller

  # Step 1: Redirect to Kratos to initialize the registration flow
  def register(conn, params) when not is_map_key(params, "flow") do
    redirect(conn, external: "#{get_kratos_base_url()}/self-service/registration/browser")
  end

  # Step 2: Fetch (or re-fetch) the registration flow from Kratos and render the form
  def register(conn, %{"flow" => flow_id}) do
    case fetch_registration_flow(conn, flow_id) do
      {:ok, flow} ->
        kratos_csrf_token =
          flow
          |> get_flow_ui_node_by_name("csrf_token")
          |> get_in(["attributes", "value"])

        email_value = get_flow_ui_node_by_name(flow, "traits.email")["attributes"]["value"]

        render(conn, :new,
          page_title: "Register User",
          error_messages: get_error_messages(flow),
          form: Phoenix.Component.to_form(%{"traits.email" => email_value}),
          form_action_url: flow["ui"]["action"],
          kratos_csrf_token: kratos_csrf_token
        )

      _result ->
        # The flow is expired or invalid. Restart the flow
        redirect(conn, to: ~p"/users/register")
    end
  end

  def register_error(conn, params) do
    conn |> text("Registration error: #{JSON.encode!(params)}")
  end

  def register_success(conn, _params) do
    conn |> text("Registration completed successfully")
  end

  defp fetch_registration_flow(conn, flow_id) do
    headers = [{"cookie", get_req_header(conn, "cookie")}]
    url = "#{get_kratos_base_url()}/self-service/registration/flows"

    request = Req.new(url: url, headers: headers, params: [id: flow_id])

    case Req.get(request) do
      {:ok, %Req.Response{status: 200, body: body}} -> {:ok, body}
      result -> {:error, result}
    end
  end

  defp get_error_messages(flow) do
    ui_messages = (flow["ui"]["messages"] || []) |> Enum.map(& &1["text"])

    ui_node_messages =
      (flow["ui"]["nodes"] || [])
      |> Enum.flat_map(fn node ->
        node_name = node["attributes"]["name"]
        messages = node["messages"]

        messages |> Enum.map(fn %{"text" => message_text} -> "#{node_name}: #{message_text}" end)
      end)

    ui_messages ++ ui_node_messages
  end

  defp get_flow_ui_node_by_name(flow, name) do
    (flow["ui"]["nodes"] || [])
    |> Enum.find(fn %{"attributes" => %{"name" => node_name}} ->
      node_name == name
    end)
  end

  defp get_kratos_base_url,
    do: Application.fetch_env!(:user_service, :ory_kratos) |> Keyword.fetch!(:base_url)
end
