defmodule MilitermWeb.AuthController do
  use MilitermWeb, :controller

  plug Ueberauth
  alias Ueberauth.Strategy.Helpers

  alias MilitermWeb.UserAuth.Guardian

  def request(conn, _params) do
    conn
    |> put_flash(:error, "There was an error authenticating.")
    |> redirect(to: "/")
  end

  def delete(conn, _params) do
    conn
    |> Guardian.Plug.sign_out()
    |> clear_session()
    |> redirect(to: "/")
  end

  def callback(%{assigns: %{ueberauth_failure: failure}} = conn, _params) do
    message =
      failure.errors
      |> Enum.map(& &1.message)
      |> Enum.join(", ")

    conn
    |> put_flash(:error, message)
    |> redirect(to: "/")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    case Militerm.Accounts.user_from_grapevine(auth) do
      {:ok, user} ->
        conn
        # |> put_session(:current_user, user.id)
        |> Guardian.Plug.sign_in(user)
        |> redirect(to: "/")

      {:error, _} ->
        conn
        |> put_flash(:error, "There was an error authenticating.")
        |> redirect(to: "/")
    end
  end
end
