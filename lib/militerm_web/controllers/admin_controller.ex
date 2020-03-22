defmodule MilitermWeb.AdminController do
  use MilitermWeb, :controller

  alias Militerm.Game
  alias Militerm.Game.Domain

  def index(conn, _params) do
    domains = Game.list_domains()
    render(conn, "index.html", domains: domains)
  end
end
