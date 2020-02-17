defmodule MilitermWeb.AreaController do
  use MilitermWeb, :controller

  alias Militerm.Game
  alias Militerm.Game.Area

  def new(conn, %{"domain_id" => domain_id} = _params) do
    domain = Game.get_domain!(domain_id)
    changeset = Game.change_area(%Area{})
    render(conn, "new.html", changeset: changeset, domain: domain)
  end

  def create(conn, %{"domain_id" => domain_id, "area" => area_params}) do
    domain = Game.get_domain!(domain_id)

    case Game.create_area(domain, area_params) do
      {:ok, area} ->
        conn
        |> put_flash(:info, "Area created successfully.")
        |> redirect(to: AdminRoutes.area_path(conn, :show, area))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset, domain: domain)
    end
  end

  def show(conn, %{"id" => id}) do
    area = id |> Game.get_area!() |> Militerm.Config.repo().preload([:domain, :scenes])
    render(conn, "show.html", area: area)
  end

  def edit(conn, %{"id" => id}) do
    area = id |> Game.get_area!() |> Militerm.Config.repo().preload(:domain)
    changeset = Game.change_area(area)
    render(conn, "edit.html", area: area, changeset: changeset)
  end

  def update(conn, %{"id" => id, "area" => area_params}) do
    area = id |> Game.get_area!() |> Militerm.Config.repo().preload(:domain)

    case Game.update_area(area, area_params) do
      {:ok, area} ->
        conn
        |> put_flash(:info, "Area updated successfully.")
        |> redirect(to: AdminRoutes.area_path(conn, :show, area))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", area: area, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    area = id |> Game.get_area!() |> Militerm.Config.repo().preload(:domain)
    {:ok, _area} = Game.delete_area(area)

    conn
    |> put_flash(:info, "Area deleted successfully.")
    |> redirect(to: AdminRoutes.domain_path(conn, :show, area.domain.id))
  end
end
