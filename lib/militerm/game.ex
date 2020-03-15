defmodule Militerm.Game do
  @moduledoc """
  The Game context.
  """

  import Ecto.Query, warn: false
  import Ecto
  alias Militerm.Config

  alias Militerm.Game.Domain

  @doc """
  Returns the list of domains.

  ## Examples

      iex> list_domains()
      [%Domain{}, ...]

  """
  def list_domains do
    Config.repo().all(Domain)
  end

  @doc """
  Gets a single domain.

  Raises `Ecto.NoResultsError` if the Domain does not exist.

  ## Examples

      iex> get_domain!(123)
      %Domain{}

      iex> get_domain!(456)
      ** (Ecto.NoResultsError)

  """
  def get_domain!(id), do: Config.repo().get!(Domain, id)

  @doc """
  Creates a domain.

  ## Examples

      iex> create_domain(%{field: value})
      {:ok, %Domain{}}

      iex> create_domain(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_domain(attrs \\ %{}) do
    %Domain{}
    |> Domain.changeset(attrs)
    |> Config.repo().insert()
  end

  def create_domain!(attrs \\ %{}) do
    %Domain{}
    |> Domain.changeset(attrs)
    |> Config.repo().insert!()
  end

  @doc """
  Updates a domain.

  ## Examples

      iex> update_domain(domain, %{field: new_value})
      {:ok, %Domain{}}

      iex> update_domain(domain, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_domain(%Domain{} = domain, attrs) do
    domain
    |> Domain.changeset(attrs)
    |> Config.repo().update()
  end

  @doc """
  Deletes a Domain.

  ## Examples

      iex> delete_domain(domain)
      {:ok, %Domain{}}

      iex> delete_domain(domain)
      {:error, %Ecto.Changeset{}}

  """
  def delete_domain(%Domain{} = domain) do
    Config.repo().delete(domain)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking domain changes.

  ## Examples

      iex> change_domain(domain)
      %Ecto.Changeset{source: %Domain{}}

  """
  def change_domain(%Domain{} = domain) do
    Domain.changeset(domain, %{})
  end

  alias Militerm.Game.Area

  @doc """
  Returns the list of areas.

  ## Examples

      iex> list_areas()
      [%Area{}, ...]

  """
  def list_areas(opts \\ []) do
    opts
    |> Enum.reduce(Area, &add_constraint/2)
    |> Config.repo().all()
  end

  @doc """
  Gets a single area.

  Raises `Ecto.NoResultsError` if the Area does not exist.

  ## Examples

      iex> get_area!(123)
      %Area{}

      iex> get_area!(456)
      ** (Ecto.NoResultsError)

  """
  def get_area!(id), do: Config.repo().get!(Area, id)

  @doc """
  Creates a area.

  ## Examples

      iex> create_area(%{field: value})
      {:ok, %Area{}}

      iex> create_area(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_area(domain, attrs \\ %{}) do
    domain
    |> build_assoc(:areas)
    |> Area.changeset(attrs)
    |> Config.repo().insert()
  end

  def create_area!(domain, attrs \\ %{}) do
    domain
    |> build_assoc(:areas)
    |> Area.changeset(attrs)
    |> Config.repo().insert!()
  end

  @doc """
  Updates a area.

  ## Examples

      iex> update_area(area, %{field: new_value})
      {:ok, %Area{}}

      iex> update_area(area, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_area(%Area{} = area, attrs) do
    area
    |> Area.changeset(attrs)
    |> Config.repo().update()
  end

  @doc """
  Deletes a Area.

  ## Examples

      iex> delete_area(area)
      {:ok, %Area{}}

      iex> delete_area(area)
      {:error, %Ecto.Changeset{}}

  """
  def delete_area(%Area{} = area) do
    Config.repo().delete(area)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking area changes.

  ## Examples

      iex> change_area(area)
      %Ecto.Changeset{source: %Area{}}

  """
  def change_area(%Area{} = area) do
    Area.changeset(area, %{})
  end

  defp add_constraint({key, value}, query) do
    where(query, [q], field(q, ^key) == ^value)
  end

  defp add_constraint(list, query) when is_list(list) do
    Enum.reduce(list, query, &add_constraint/2)
  end

  defp add_constraint(id, query) when is_binary(id) or is_number(id) do
    where(query, [q], q.id == ^id)
  end

  alias Militerm.Game.Scene

  @doc """
  Returns the list of scenes.

  ## Examples

      iex> list_scenes()
      [%Scene{}, ...]

  """
  def list_scenes(opts \\ []) do
    opts
    |> Enum.reduce(Scene, &add_constraint/2)
    |> Config.repo().all()
  end

  @doc """
  Gets a single scene.

  Raises `Ecto.NoResultsError` if the Scene does not exist.

  ## Examples

      iex> get_scene!(123)
      %Scene{}

      iex> get_scene!(456)
      ** (Ecto.NoResultsError)

  """
  def get_scene!(id), do: Config.repo().get!(Scene, id)

  @doc """
  Creates a scene.

  ## Examples

      iex> create_scene(area, %{field: value})
      {:ok, %Scene{}}

      iex> create_scene(area, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_scene(area, attrs \\ %{}) do
    area
    |> build_assoc(:scenes)
    |> Scene.changeset(attrs)
    |> Config.repo().insert()
    |> create_scene_entity(attrs)
  end

  defp create_scene_entity({:ok, scene} = success, attrs) do
    scene = scene |> Config.repo().preload(area: :domain)
    entity_id = Enum.join(["scene", scene.area.domain.plug, scene.area.plug, scene.plug], ":")

    data = Map.get(attrs, "components", Map.get(attrs, :components, %{}))

    Militerm.Entities.Scene.create(entity_id, scene.archetype, data)
    success
  end

  defp create_scene_entity(result, _), do: result

  @doc """
  Updates a scene.

  ## Examples

      iex> update_scene(scene, %{field: new_value})
      {:ok, %Scene{}}

      iex> update_scene(scene, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_scene(%Scene{} = scene, attrs) do
    scene
    |> Scene.changeset(attrs)
    |> Config.repo().update()
    |> update_scene_entity(attrs)
  end

  defp update_scene_entity({:ok, scene} = success, attrs) do
    # if we don't have an entity yet, we just create it
    scene = scene |> Config.repo().preload(area: :domain)
    entity_id = Enum.join(["scene", scene.area.domain.plug, scene.area.plug, scene.plug], ":")

    if is_nil(Militerm.Components.Entity.module(entity_id)) do
      create_scene_entity(success, attrs)
    else
      Militerm.Components.Entity.set_archetype(entity_id, scene.archetype)

      data = Map.get(attrs, "components", Map.get(attrs, :components, %{}))

      Militerm.Components.Entity.update_components(entity_id, data)
    end

    success
  end

  defp update_scene_entity(result, _), do: result

  @doc """
  Deletes a Scene.

  ## Examples

      iex> delete_scene(scene)
      {:ok, %Scene{}}

      iex> delete_scene(scene)
      {:error, %Ecto.Changeset{}}

  """
  def delete_scene(%Scene{} = scene) do
    Config.repo().delete(scene)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking scene changes.

  ## Examples

      iex> change_scene(scene)
      %Ecto.Changeset{source: %Scene{}}

  """
  def change_scene(%Scene{} = scene) do
    Scene.changeset(scene, %{})
  end
end
