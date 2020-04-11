defmodule MilitermWeb.AdminController do
  use MilitermWeb, :controller

  alias Militerm.Game
  alias Militerm.Game.Domain

  def index(conn, _params) do
    render(conn, "index.html", domains: [])
  end
end
