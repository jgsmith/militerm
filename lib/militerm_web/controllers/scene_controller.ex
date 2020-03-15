defmodule MilitermWeb.SceneController do
  use MilitermWeb, :controller

  alias Militerm.Game
  alias Militerm.Game.Scene

  def new(conn, %{"area_id" => area_id} = _params) do
    area = area_id |> Game.get_area!() |> Militerm.Config.repo().preload([:domain])
    changeset = Game.change_scene(%Scene{})

    render(conn, "new.html",
      changeset: changeset,
      area: area,
      data: %{},
      data_errors: %{},
      archetypes: archetype_list(area.domain.plug, area.plug),
      components: component_list()
    )
  end

  def create(conn, %{"area_id" => area_id, "scene" => scene_params}) do
    area = area_id |> Game.get_area!() |> Militerm.Config.repo().preload([:domain])

    with {:ok, components} <- parse_components(scene_params),
         {:ok, scene} <- Game.create_scene(area, Map.put(scene_params, "components", components)) do
      conn
      |> put_flash(:info, "Scene created successfully.")
      |> redirect(to: AdminRoutes.area_path(conn, :show, area))
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        # errors aren't the YAML
        render(conn, "new.html",
          data: component_sources(scene_params),
          data_errors: %{},
          area: area,
          changeset: changeset,
          archetypes: archetype_list(area.domain.plug, area.plug),
          components: component_list()
        )

      {:error, %{} = data_errors} ->
        render(conn, "new.html",
          data: component_sources(scene_params),
          data_errors: data_errors,
          area: area,
          changeset: Game.change_scene(scene_params),
          archetypes: archetype_list(area.domain.plug, area.plug),
          components: component_list()
        )
    end
  end

  def show(conn, %{"id" => id}) do
    scene = id |> Game.get_scene!() |> Militerm.Config.repo().preload(area: :domain)
    entity_id = Enum.join(["scene", scene.area.domain.plug, scene.area.plug, scene.plug], ":")
    data = component_sources(entity_id)

    render(conn, "show.html", scene: scene, data: data, components: component_list())
  end

  def edit(conn, %{"id" => id}) do
    scene = id |> Game.get_scene!() |> Militerm.Config.repo().preload(area: :domain)
    changeset = Game.change_scene(scene)
    entity_id = Enum.join(["scene", scene.area.domain.plug, scene.area.plug, scene.plug], ":")
    data = component_sources(entity_id)

    render(conn, "edit.html",
      scene: scene,
      changeset: changeset,
      data: data,
      data_errors: %{},
      archetypes: archetype_list(scene.area.domain.plug, scene.area.plug),
      components: component_list()
    )
  end

  def update(conn, %{"id" => id, "scene" => scene_params}) do
    scene = id |> Game.get_scene!() |> Militerm.Config.repo().preload(area: :domain)

    with {:ok, components} <- parse_components(scene_params),
         {:ok, scene} <- Game.update_scene(scene, Map.put(scene_params, "components", components)) do
      conn
      |> put_flash(:info, "Scene updated successfully.")
      |> redirect(to: AdminRoutes.scene_path(conn, :show, scene))
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        # errors aren't the YAML
        render(conn, "edit.html",
          scene: scene,
          data: component_sources(scene_params),
          data_errors: %{},
          changeset: changeset,
          archetypes: archetype_list(scene.area.domain.plug, scene.area.plug),
          components: component_list()
        )

      {:error, %{} = data_errors} ->
        render(conn, "edit.html",
          scene: scene,
          data: component_sources(scene_params),
          data_errors: data_errors,
          changeset: Game.change_scene(scene, scene_params),
          archetypes: archetype_list(scene.area.domain.plug, scene.area.plug),
          components: component_list()
        )
    end
  end

  def delete(conn, %{"id" => id}) do
    scene = Game.get_scene!(id)
    {:ok, _scene} = Game.delete_scene(scene)

    conn
    |> put_flash(:info, "Scene deleted successfully.")
    |> redirect(to: AdminRoutes.area_path(conn, :show, scene.area_id))
  end

  def archetype_list(domain, area) do
    Militerm.Systems.Archetypes.list_archetypes()
    |> Enum.filter(fn archetype ->
      (archetype in ["std:scene", domain <> ":scene", domain <> area <> ":scene"] or
         String.starts_with?(archetype, "std:scene:") or
         String.starts_with?(archetype, domain <> ":scene:") or
         String.starts_with?(archetype, domain <> ":" <> area <> ":scene:")) and
        has_right_trait?(archetype, "scene")
    end)
  end

  def has_right_trait?(archetype, trait) do
    true
    #     with %{} = definition <- Militerm.Services.Archtypes.get(archetype) do
    #       Militerm.Systems.Archetypes.trait(definition, archetype, trait, %{})
    # `   else
    #       _ -> false
    #     end`
  end

  def with_components(scene_params) do
    components =
      component_list()
      |> Enum.map(fn component ->
        %{
          component: to_string(component),
          text: Map.get(scene_params, component, Map.get(scene_params, to_string(component), ""))
        }
      end)
      |> Enum.reject(fn
        %{text: ""} -> true
        _ -> false
      end)

    scene_params =
      scene_params
      |> Map.drop(component_list())
      |> Map.put("source", components)
  end

  def component_sources(entity_id) when is_binary(entity_id) do
    data =
      entity_id
      |> Militerm.Components.Entity.get_components()
      |> Map.take(component_list())
      |> Enum.map(fn {k, v} ->
        {
          k,
          v
          |> Militerm.Util.Yaml.write_to_string()
        }
      end)
      |> Enum.into(%{})

    component_list()
    |> Enum.map(fn component ->
      {component, Map.get(data, component, "")}
    end)
    |> Enum.into(%{})
  end

  def component_sources(%{} = params) do
    component_list()
    |> Enum.map(fn component ->
      {component, Map.get(params, to_string(component), "")}
    end)
    |> Enum.into(%{})
  end

  def parse_components(scene_params) do
    {success, error} =
      scene_params
      |> component_sources
      |> Enum.reduce({%{}, %{}}, fn {component, source}, {success, error} ->
        case YamlElixir.read_from_string(source) do
          {:ok, data} -> {Map.put(success, component, data), error}
          {:error, %{message: message}} -> {success, Map.put(error, component, message)}
        end
      end)

    if map_size(error) == 0, do: {:ok, success}, else: {:error, error}
  end

  def component_list() do
    Militerm.Config.components()
    |> Map.drop(~w[location entity]a)
    |> Map.drop(ephemeral_components())
    |> Map.keys()
    |> Enum.sort_by(&to_string/1)
  end

  def ephemeral_components() do
    Militerm.Config.components()
    |> Enum.filter(fn {k, v} -> v.ephemeral? end)
    |> Enum.map(&elem(&1, 0))
  end
end
