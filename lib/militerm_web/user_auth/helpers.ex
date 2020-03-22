defmodule MilitermWeb.UserAuth.Helpers do
  alias MilitermWeb.UserAuth.Guardian

  def current_user(conn) do
    Guardian.Plug.current_resource(conn)
  end

  def authenticated?(conn) do
    !is_nil(current_user(conn))
  end

  def admin?(conn) do
    case current_user(conn) do
      %{is_admin: flag} -> flag
      _ -> false
    end
  end
end
