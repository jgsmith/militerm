defmodule Militerm.GameTest do
  use Militerm.DataCase

  alias Militerm.Game

  describe "domains" do
    alias Militerm.Game.Domain

    @valid_attrs %{description: "some description", name: "some name", plug: "some-name"}
    @update_attrs %{
      description: "some updated description",
      name: "some updated name",
      plug: "some-updated-name"
    }
    @invalid_attrs %{description: nil, name: nil, plug: nil}

    def domain_fixture(attrs \\ %{}) do
      {:ok, domain} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Game.create_domain()

      domain
    end

    test "list_domains/0 returns all domains" do
      domain = domain_fixture()
      assert Game.list_domains() == [domain]
    end

    test "get_domain!/1 returns the domain with given id" do
      domain = domain_fixture()
      assert Game.get_domain!(domain.id) == domain
    end

    test "create_domain/1 with valid data creates a domain" do
      assert {:ok, %Domain{} = domain} = Game.create_domain(@valid_attrs)
      assert domain.description == "some description"
      assert domain.name == "some name"
      assert domain.plug == "some-name"
    end

    test "create_domain/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Game.create_domain(@invalid_attrs)
    end

    test "update_domain/2 with valid data updates the domain" do
      domain = domain_fixture()
      assert {:ok, %Domain{} = domain} = Game.update_domain(domain, @update_attrs)
      assert domain.description == "some updated description"
      assert domain.name == "some updated name"
      assert domain.plug == "some-updated-name"
    end

    test "update_domain/2 with invalid data returns error changeset" do
      domain = domain_fixture()
      assert {:error, %Ecto.Changeset{}} = Game.update_domain(domain, @invalid_attrs)
      assert domain == Game.get_domain!(domain.id)
    end

    test "delete_domain/1 deletes the domain" do
      domain = domain_fixture()
      assert {:ok, %Domain{}} = Game.delete_domain(domain)
      assert_raise Ecto.NoResultsError, fn -> Game.get_domain!(domain.id) end
    end

    test "change_domain/1 returns a domain changeset" do
      domain = domain_fixture()
      assert %Ecto.Changeset{} = Game.change_domain(domain)
    end
  end

  describe "areas" do
    alias Militerm.Game.Area

    @valid_attrs %{description: "some description", name: "some name", plug: "some-name"}
    @update_attrs %{
      description: "some updated description",
      name: "some updated name",
      plug: "some-updated-name"
    }
    @invalid_attrs %{description: nil, name: nil, plug: nil}

    def area_fixture(attrs \\ %{}) do
      domain = Map.get_lazy(attrs, :domain, &domain_fixture/0)

      {:ok, area} =
        attrs
        |> Enum.into(@valid_attrs)
        |> (&Game.create_area(domain, &1)).()

      area
    end

    test "list_areas/0 returns all areas" do
      area = area_fixture()
      assert Game.list_areas() == [area]
    end

    test "get_area!/1 returns the area with given id" do
      area = area_fixture()
      assert Game.get_area!(area.id) == area
    end

    test "create_area/1 with valid data creates a area" do
      assert {:ok, %Area{} = area} = Game.create_area(domain_fixture(), @valid_attrs)
      assert area.description == "some description"
      assert area.name == "some name"
      assert area.plug == "some-name"
    end

    test "create_area/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Game.create_area(domain_fixture(), @invalid_attrs)
    end

    test "update_area/2 with valid data updates the area" do
      area = area_fixture()
      assert {:ok, %Area{} = area} = Game.update_area(area, @update_attrs)
      assert area.description == "some updated description"
      assert area.name == "some updated name"
      assert area.plug == "some-updated-name"
    end

    test "update_area/2 with invalid data returns error changeset" do
      area = area_fixture()
      assert {:error, %Ecto.Changeset{}} = Game.update_area(area, @invalid_attrs)
      assert area == Game.get_area!(area.id)
    end

    test "delete_area/1 deletes the area" do
      area = area_fixture()
      assert {:ok, %Area{}} = Game.delete_area(area)
      assert_raise Ecto.NoResultsError, fn -> Game.get_area!(area.id) end
    end

    test "change_area/1 returns a area changeset" do
      area = area_fixture()
      assert %Ecto.Changeset{} = Game.change_area(area)
    end
  end

  describe "scenes" do
    alias Militerm.Game.Scene

    @valid_attrs %{
      archetype: "some archetype",
      plug: "some-name",
      source: [%{component: "detail", text: "default:\n  short: \"some detail\"\n"}]
    }
    @update_attrs %{
      archetype: "some updated archetype",
      plug: "some-updated-name",
      source: [%{component: "detail", text: "default:\n  short: \"some updated detail\"\n"}]
    }
    @invalid_attrs %{archetype: nil, plug: nil, source: [%{component: "detail", text: "sdj:"}]}

    def scene_fixture(attrs \\ %{}) do
      area = Map.get_lazy(attrs, :area, &area_fixture/0)

      {:ok, scene} =
        attrs
        |> Enum.into(@valid_attrs)
        |> (&Game.create_scene(area, &1)).()

      scene
    end

    test "list_scenes/0 returns all scenes" do
      scene = scene_fixture()
      assert Game.list_scenes() == [scene]
    end

    test "get_scene!/1 returns the scene with given id" do
      scene = scene_fixture()
      assert Game.get_scene!(scene.id) == scene
    end

    test "create_scene/1 with valid data creates a scene" do
      assert {:ok, %Scene{} = scene} = Game.create_scene(area_fixture(), @valid_attrs)
      assert scene.archetype == "some archetype"
      assert scene.plug == "some-name"
    end

    test "create_scene/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Game.create_scene(area_fixture(), @invalid_attrs)
    end

    test "update_scene/2 with valid data updates the scene" do
      scene = scene_fixture()
      assert {:ok, %Scene{} = scene} = Game.update_scene(scene, @update_attrs)
      assert scene.archetype == "some updated archetype"
      assert scene.plug == "some-updated-name"
    end

    test "update_scene/2 with invalid data returns error changeset" do
      scene = scene_fixture()
      assert {:error, %Ecto.Changeset{}} = Game.update_scene(scene, @invalid_attrs)
      assert scene == Game.get_scene!(scene.id)
    end

    test "delete_scene/1 deletes the scene" do
      scene = scene_fixture()
      assert {:ok, %Scene{}} = Game.delete_scene(scene)
      assert_raise Ecto.NoResultsError, fn -> Game.get_scene!(scene.id) end
    end

    test "change_scene/1 returns a scene changeset" do
      scene = scene_fixture()
      assert %Ecto.Changeset{} = Game.change_scene(scene)
    end
  end
end
