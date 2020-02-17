defmodule MilitermWeb.SceneControllerTest do
  use MilitermWeb.ConnCase

  alias Militerm.Game

  @create_attrs %{
    archetype: "some archetype",
    plug: "some-name",
    detail: "default:\n  short: a quiet room\n"
  }
  @update_attrs %{archetype: "some updated archetype", plug: "some-updated-name", source: %{}}
  @invalid_attrs %{archetype: nil, plug: nil, source: nil}

  @create_domain_attrs %{name: "some domain", plug: "some-domain", description: "description"}
  @create_area_attrs %{name: "some area", plug: "some-area", description: "description"}

  def fixture(:domain) do
    {:ok, domain} = Game.create_domain(@create_domain_attrs)
    domain
  end

  def fixture(:area) do
    {:ok, area} = Game.create_area(fixture(:domain), @create_area_attrs)
    area
  end

  def fixture(:scene) do
    {:ok, scene} = Game.create_scene(fixture(:area), @create_attrs)
    scene
  end

  describe "index" do
    setup [:create_area]

    test "lists all scenes", %{conn: conn, area: area} do
      conn = get(conn, AdminRoutes.area_path(conn, :show, area))
      assert html_response(conn, 200) =~ "Scenes"
    end
  end

  describe "new scene" do
    setup [:create_area]

    test "renders form", %{conn: conn, area: area} do
      conn = get(conn, AdminRoutes.area_scene_path(conn, :new, area))
      assert html_response(conn, 200) =~ "New Scene"
    end
  end

  describe "create scene" do
    setup [:create_area]

    test "redirects to show when data is valid", %{conn: conn, area: area} do
      conn = post(conn, AdminRoutes.area_scene_path(conn, :create, area), scene: @create_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == AdminRoutes.area_path(conn, :show, area)

      conn = get(conn, AdminRoutes.area_path(conn, :show, id))
      assert html_response(conn, 200) =~ @create_attrs.plug
    end

    test "renders errors when data is invalid", %{conn: conn, area: area} do
      conn = post(conn, AdminRoutes.area_scene_path(conn, :create, area), scene: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Scene"
    end
  end

  describe "edit scene" do
    setup [:create_scene]

    test "renders form for editing chosen scene", %{conn: conn, scene: scene} do
      conn = get(conn, AdminRoutes.scene_path(conn, :edit, scene))
      assert html_response(conn, 200) =~ "Edit Scene"
    end
  end

  describe "update scene" do
    setup [:create_scene]

    test "redirects when data is valid", %{conn: conn, scene: scene} do
      conn = put(conn, AdminRoutes.scene_path(conn, :update, scene), scene: @update_attrs)
      assert redirected_to(conn) == AdminRoutes.scene_path(conn, :show, scene)

      conn = get(conn, AdminRoutes.scene_path(conn, :show, scene))
      assert html_response(conn, 200) =~ "some updated archetype"
    end

    test "renders errors when data is invalid", %{conn: conn, scene: scene} do
      conn = put(conn, AdminRoutes.scene_path(conn, :update, scene), scene: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Scene"
    end
  end

  describe "delete scene" do
    setup [:create_scene]

    test "deletes chosen scene", %{conn: conn, scene: scene} do
      conn = delete(conn, AdminRoutes.scene_path(conn, :delete, scene))
      assert redirected_to(conn) == AdminRoutes.area_path(conn, :show, scene.area_id)

      assert_error_sent 404, fn ->
        get(conn, AdminRoutes.scene_path(conn, :show, scene))
      end
    end
  end

  defp create_scene(_) do
    scene = fixture(:scene)
    {:ok, scene: scene}
  end

  defp create_area(_) do
    area = fixture(:area)
    {:ok, area: area}
  end
end
