defmodule MilitermWeb.DomainController do
  use MilitermWeb, :controller

  alias Militerm.Game
  alias Militerm.Game.Domain

  def index(conn, _params) do
    domains = Game.list_domains()
    render(conn, "index.html", domains: domains)
  end

  def new(conn, _params) do
    changeset = Game.change_domain(%Domain{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"domain" => domain_params}) do
    case Game.create_domain(domain_params) do
      {:ok, domain} ->
        conn
        |> put_flash(:info, "Domain created successfully.")
        |> redirect(to: AdminRoutes.domain_path(conn, :show, domain))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    domain = id |> Game.get_domain!() |> Militerm.Config.repo().preload(:areas)
    render(conn, "show.html", domain: domain)
  end

  def edit(conn, %{"id" => id}) do
    domain = Game.get_domain!(id)
    changeset = Game.change_domain(domain)
    render(conn, "edit.html", domain: domain, changeset: changeset)
  end

  def update(conn, %{"id" => id, "domain" => domain_params}) do
    domain = Game.get_domain!(id)

    case Game.update_domain(domain, domain_params) do
      {:ok, domain} ->
        conn
        |> put_flash(:info, "Domain updated successfully.")
        |> redirect(to: AdminRoutes.domain_path(conn, :show, domain))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", domain: domain, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    domain = Game.get_domain!(id)
    {:ok, _domain} = Game.delete_domain(domain)

    conn
    |> put_flash(:info, "Domain deleted successfully.")
    |> redirect(to: AdminRoutes.domain_path(conn, :index))
  end
end
