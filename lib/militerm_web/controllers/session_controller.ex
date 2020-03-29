defmodule MilitermWeb.SessionController do
  use MilitermWeb, :controller

  alias Militerm.Accounts

  def auth_session(conn, %{"session_id" => session_id} = _params) do
    # let the session service know who logged in for this session
    %{id: user_id} = current_user(conn)

    case Militerm.Services.Session.authenticate_session(session_id, user_id) do
      :ok ->
        conn
        # |> put_flash()
        |> redirect(to: "/")

      :error ->
        render(conn, "try-again.html")
    end
  end
end
