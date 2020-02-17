defmodule MilitermWeb.AreaControllerTest do
  use MilitermWeb.ConnCase

  alias Militerm.Game

  @create_attrs %{description: "some description", name: "some name", plug: "some-name"}
  @update_attrs %{
    description: "some updated description",
    name: "some updated name",
    plug: "some-updated-name"
  }
  @invalid_attrs %{description: nil, name: nil, plug: nil}

  @domain_create_attrs %{description: "some description", name: "some name", plug: "some-name"}

  def fixture(:domain) do
    {:ok, domain} = Game.create_domain(@domain_create_attrs)
    domain
  end

  def fixture(:area) do
    domain = fixture(:domain)
    {:ok, area} = Game.create_area(domain, @create_attrs)
    area
  end

  def fixture(:area, domain) do
    {:ok, area} = Game.create_area(domain, @create_attrs)
    area
  end

  # describe "index" do
  #   setup [:create_domain]
  #
  #   test "lists all areas", %{conn: conn, domain: domain} do
  #     conn = get(conn, AdminRoutes.domain_area_path(conn, :index, domain))
  #     assert html_response(conn, 200) =~ "Listing Areas"
  #   end
  # end

  describe "new area" do
    setup [:create_domain]

    test "renders form", %{conn: conn, domain: domain} do
      conn = get(conn, AdminRoutes.domain_area_path(conn, :new, domain))
      assert html_response(conn, 200) =~ "New Area"
    end
  end

  describe "create area" do
    setup [:create_domain]

    test "redirects to show when data is valid", %{conn: conn, domain: domain} do
      conn = post(conn, AdminRoutes.domain_area_path(conn, :create, domain), area: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == AdminRoutes.area_path(conn, :show, id)

      conn = get(conn, AdminRoutes.area_path(conn, :show, id))
      assert html_response(conn, 200) =~ "Show Area"
    end

    test "renders errors when data is invalid", %{conn: conn, domain: domain} do
      conn = post(conn, AdminRoutes.domain_area_path(conn, :create, domain), area: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Area"
    end
  end

  describe "edit area" do
    setup [:create_area_and_domain]

    test "renders form for editing chosen area", %{conn: conn, area: area, domain: domain} do
      conn = get(conn, AdminRoutes.area_path(conn, :edit, area))
      assert html_response(conn, 200) =~ "Edit Area"
    end
  end

  describe "update area" do
    setup [:create_area_and_domain]

    test "redirects when data is valid", %{conn: conn, area: area, domain: domain} do
      conn = put(conn, AdminRoutes.area_path(conn, :update, area), area: @update_attrs)

      assert redirected_to(conn) == AdminRoutes.area_path(conn, :show, area)

      conn = get(conn, AdminRoutes.area_path(conn, :show, area))
      assert html_response(conn, 200) =~ "some updated description"
    end

    test "renders errors when data is invalid", %{conn: conn, area: area, domain: domain} do
      conn = put(conn, AdminRoutes.area_path(conn, :update, area), area: @invalid_attrs)

      assert html_response(conn, 200) =~ "Edit Area"
    end
  end

  describe "delete area" do
    setup [:create_area_and_domain]

    test "deletes chosen area", %{conn: conn, area: area, domain: domain} do
      conn = delete(conn, AdminRoutes.area_path(conn, :delete, area))
      assert redirected_to(conn) == AdminRoutes.domain_path(conn, :show, domain)

      assert_error_sent 404, fn ->
        get(conn, AdminRoutes.area_path(conn, :show, area))
      end
    end
  end

  defp create_domain(_) do
    domain = fixture(:domain)
    {:ok, domain: domain}
  end

  defp create_area_and_domain(_) do
    domain = fixture(:domain)
    area = fixture(:area, domain)
    {:ok, area: area, domain: domain}
  end
end
