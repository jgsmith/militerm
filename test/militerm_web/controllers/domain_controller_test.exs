defmodule MilitermWeb.DomainControllerTest do
  use MilitermWeb.ConnCase

  alias Militerm.Game

  @create_attrs %{description: "some description", name: "some name", plug: "some-name"}
  @update_attrs %{
    description: "some updated description",
    name: "some updated name",
    plug: "some-updated-name"
  }
  @invalid_attrs %{description: nil, name: nil, plug: nil}

  def fixture(:domain) do
    {:ok, domain} = Game.create_domain(@create_attrs)
    domain
  end

  describe "index" do
    test "lists all domains", %{conn: conn} do
      conn = get(conn, AdminRoutes.domain_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Domains"
    end
  end

  describe "new domain" do
    test "renders form", %{conn: conn} do
      conn = get(conn, AdminRoutes.domain_path(conn, :new))
      assert html_response(conn, 200) =~ "New Domain"
    end
  end

  describe "create domain" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, AdminRoutes.domain_path(conn, :create), domain: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == AdminRoutes.domain_path(conn, :show, id)

      conn = get(conn, AdminRoutes.domain_path(conn, :show, id))
      assert html_response(conn, 200) =~ "Show Domain"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, AdminRoutes.domain_path(conn, :create), domain: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Domain"
    end
  end

  describe "edit domain" do
    setup [:create_domain]

    test "renders form for editing chosen domain", %{conn: conn, domain: domain} do
      conn = get(conn, AdminRoutes.domain_path(conn, :edit, domain))
      assert html_response(conn, 200) =~ "Edit Domain"
    end
  end

  describe "update domain" do
    setup [:create_domain]

    test "redirects when data is valid", %{conn: conn, domain: domain} do
      conn = put(conn, AdminRoutes.domain_path(conn, :update, domain), domain: @update_attrs)
      assert redirected_to(conn) == AdminRoutes.domain_path(conn, :show, domain)

      conn = get(conn, AdminRoutes.domain_path(conn, :show, domain))
      assert html_response(conn, 200) =~ "some updated description"
    end

    test "renders errors when data is invalid", %{conn: conn, domain: domain} do
      conn = put(conn, AdminRoutes.domain_path(conn, :update, domain), domain: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Domain"
    end
  end

  describe "delete domain" do
    setup [:create_domain]

    test "deletes chosen domain", %{conn: conn, domain: domain} do
      conn = delete(conn, AdminRoutes.domain_path(conn, :delete, domain))
      assert redirected_to(conn) == AdminRoutes.domain_path(conn, :index)

      assert_error_sent 404, fn ->
        get(conn, AdminRoutes.domain_path(conn, :show, domain))
      end
    end
  end

  defp create_domain(_) do
    domain = fixture(:domain)
    {:ok, domain: domain}
  end
end
