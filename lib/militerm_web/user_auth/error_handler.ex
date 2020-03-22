defmodule MilitermWeb.UserAuth.ErrorHandler do
  import Plug.Conn

  @behaviour Guardian.Plug.ErrorHandler

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, {type, _reason}, _opts) do
    conn
    |> Phoenix.Controller.redirect(to: "/auth/grapevine")
  end
end
