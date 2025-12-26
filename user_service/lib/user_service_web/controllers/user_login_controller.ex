defmodule UserServiceWeb.UserLoginController do
  use UserServiceWeb, :controller

  # Step 1: Redirect to Kratos to initialize the registration flow
  def register(_conn, params) when not is_map_key(params, "flow") do
    # redirect(conn, external: "#{get_hydra_base_url()}/")
  end

  # defp get_kratos_base_url,
  #   do: Application.fetch_env!(:user_service, :ory_hydra) |> Keyword.fetch!(:base_url)
end
