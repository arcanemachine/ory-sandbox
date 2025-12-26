defmodule UserServiceWeb.PageController do
  use UserServiceWeb, :controller

  def home(conn, _params) do
    conn
    |> assign(:page_title, "Home")
    |> render(:home)
  end
end
