defmodule Militerm.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Militerm.Config

  alias Ecto.Multi

  alias Militerm.Accounts.{Group, GroupMembership, User}

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    Config.repo().all(User)
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Config.repo().get!(User, id)

  def get_user(nil), do: nil

  def get_user(id), do: Config.repo().get(User, id)

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Config.repo().insert()
  end

  def create_user!(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Config.repo().insert!()
  end

  def user_from_grapevine(auth) do
    params = %{
      uid: auth.uid,
      name: auth.info.name,
      email: auth.info.email
    }

    # look by uid first, then by email
    params
    |> maybe_find_user_by(:uid)
    |> maybe_find_user_by(params, :email)
    |> maybe_create_or_update_user(params)
    |> maybe_add_admin_group_to_user()
  end

  defp maybe_find_user_by(opts, field) do
    maybe_find_user_by(nil, opts, field)
  end

  defp maybe_find_user_by(nil, opts, key) do
    value = Map.get(opts, key)

    User
    |> where([u], field(u, ^key) == ^value)
    |> Config.repo().one()
  end

  defp maybe_find_user_by(user, _, _), do: user

  defp maybe_create_or_update_user(nil, params) do
    params = Map.put(params, :is_admin, no_users?())
    create_user(params)
  end

  defp maybe_create_or_update_user(user, params) do
    update_user(user, params)
  end

  def no_users?() do
    User
    |> limit(1)
    |> Config.repo().one
    |> is_nil
  end

  def maybe_add_admin_group_to_user({:ok, %User{id: user_id, is_admin: true}} = result) do
    case get_group_by_name("admin") do
      %{id: group_id} ->
        %GroupMembership{}
        |> GroupMembership.changeset(%{user_id: user_id, group_id: group_id})
        |> Config.repo().insert!()

        result

      _ ->
        result
    end
  end

  def maybe_add_admin_group_to_user(result), do: result

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Config.repo().update()
  end

  @doc """
  Deletes a User.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user) do
    Config.repo().delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{source: %User{}}

  """
  def change_user(%User{} = user) do
    User.changeset(user, %{})
  end

  alias Militerm.Accounts.Character

  @doc """
  Returns the list of characters.

  ## Examples

      iex> list_characters()
      [%Character{}, ...]

  """
  def list_characters(opts \\ []) do
    opts
    |> add_constraint(Character)
    |> Config.repo().all()
  end

  @doc """
  Gets a single character.

  Raises `Ecto.NoResultsError` if the Character does not exist.

  ## Examples

      iex> get_character!(123)
      %Character{}

      iex> get_character!(456)
      ** (Ecto.NoResultsError)

  """
  def get_character!(opts) do
    opts
    |> add_constraint(Character)
    |> Config.repo().one!()
  end

  def get_character(opts) do
    opts
    |> add_constraint(Character)
    |> Config.repo().one()
  end

  @doc """
  Creates a character.

  This also creates an entity to represent the character in the game.

  ## Examples

      iex> create_character(%{field: value})
      {:ok, %Character{}}

      iex> create_character(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_character(attrs \\ %{}) do
    character_archetype = get_character_archetype(attrs)

    entity_id = character_archetype <> "#" <> UUID.uuid4()

    attrs =
      attrs
      |> Enum.map(fn {k, v} -> {to_string(k), v} end)
      |> Enum.into(%{})
      |> Map.put("entity_id", entity_id)

    create_character_entity(entity_id, character_archetype, attrs)

    result =
      %Character{}
      |> Character.changeset(attrs)
      |> Config.repo().insert

    case result do
      {:ok, character} = done ->
        done

      {:error, _} = error ->
        remove_character_entity(entity_id)
        error
    end
  end

  defp create_character_entity(entity_id, archetype, attrs) do
    Militerm.Entities.Thing.create(entity_id, archetype, get_character_start_data(attrs))
    {_, thing} = loc = get_character_start_location(attrs)
    # ensure it's loaded
    Militerm.Systems.Entity.whereis(thing)
    Militerm.Systems.Location.place({:thing, entity_id}, loc)
    Militerm.Systems.Entity.hibernate({:thing, entity_id})
  end

  defp remove_character_entity(entity_id) do
    Militerm.Entities.Thing.delete(entity_id)
  end

  @doc """
  Updates a character.

  ## Examples

      iex> update_character(character, %{field: new_value})
      {:ok, %Character{}}

      iex> update_character(character, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_character(%Character{} = character, attrs) do
    character
    |> Character.changeset(attrs)
    |> Config.repo().update()
  end

  @doc """
  Deletes a Character.

  ## Examples

      iex> delete_character(character)
      {:ok, %Character{}}

      iex> delete_character(character)
      {:error, %Ecto.Changeset{}}

  """
  def delete_character(%Character{} = character) do
    Config.repo().delete(character)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking character changes.

  ## Examples

      iex> change_character(character)
      %Ecto.Changeset{source: %Character{}}

  """
  def change_character(%Character{} = character) do
    Character.changeset(character, %{})
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

  alias Militerm.Accounts.Group

  @doc """
  Returns the list of groups.

  ## Examples

      iex> list_groups()
      [%Group{}, ...]

  """
  def list_groups do
    Config.repo().all(Group)
  end

  @doc """
  Gets a single group.

  Raises `Ecto.NoResultsError` if the Group does not exist.

  ## Examples

      iex> get_group!(123)
      %Group{}

      iex> get_group!(456)
      ** (Ecto.NoResultsError)

  """
  def get_group!(id), do: Config.repo().get!(Group, id)

  def get_group_by_name(name) do
    Group
    |> where([g], g.name == ^name)
    |> Config.repo().one()
  end

  @doc """
  Creates a group.

  ## Examples

      iex> create_group(%{field: value})
      {:ok, %Group{}}

      iex> create_group(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_group(attrs \\ %{}) do
    %Group{}
    |> Group.changeset(attrs)
    |> Config.repo().insert()
  end

  @doc """
  Updates a group.

  ## Examples

      iex> update_group(group, %{field: new_value})
      {:ok, %Group{}}

      iex> update_group(group, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_group(%Group{} = group, attrs) do
    group
    |> Group.changeset(attrs)
    |> Config.repo().update()
  end

  @doc """
  Deletes a group.

  ## Examples

      iex> delete_group(group)
      {:ok, %Group{}}

      iex> delete_group(group)
      {:error, %Ecto.Changeset{}}

  """
  def delete_group(%Group{} = group) do
    Config.repo().delete(group)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking group changes.

  ## Examples

      iex> change_group(group)
      %Ecto.Changeset{source: %Group{}}

  """
  def change_group(%Group{} = group) do
    Group.changeset(group, %{})
  end

  def is_group_allowed?(entity_id, group_name) do
    result =
      Character
      |> join(:left, [c], g in assoc(c, :groups))
      |> where([c, g], c.entity_id == ^entity_id and g.name == ^group_name)
      |> limit(1)
      |> Config.repo().one()

    !is_nil(result)
  end

  def get_character_archetype(attrs) do
    case Militerm.Config.character_archetype() do
      binary when is_binary(binary) -> binary
      {m, f} -> apply(m, f, [attrs])
      {m, f, a} -> apply(m, f, a ++ [attrs])
      _ -> "std:character"
    end
  end

  def get_character_start_location(attrs) do
    case Militerm.Config.character_start_location() do
      binary when is_binary(binary) ->
        {"in", {:thing, binary, "default"}}

      {entity_id, coord} when is_binary(entity_id) ->
        {"in", {:thing, entity_id, coord}}

      {prep, entity_id, coord} when is_binary(prep) and is_binary(entity_id) ->
        {prep, {:thing, entity_id, coord}}

      {m, f} ->
        apply(m, f, [attrs])

      {m, f, a} ->
        apply(m, f, a ++ [attrs])

      _ ->
        {"in", {:thing, "scene:start:start:start", "default"}}
    end
  end

  def get_character_start_data(attrs) do
    case Militerm.Config.character_start_data() do
      %{} = data ->
        data

      {m, f} ->
        apply(m, f, [attrs])

      {m, f, a} ->
        apply(m, f, a ++ [attrs])

      _ ->
        {nominative, objective, possessive} =
          case attrs["gender"] do
            "male" -> {"he", "him", "his"}
            "female" -> {"she", "her", "her"}
            "neuter" -> {"hi", "hir", "hir"}
            _ -> {"they", "them", "their"}
          end

        %{
          identity: %{
            "name" => attrs["cap_name"],
            "nominative" => nominative,
            "objective" => objective,
            "possessive" => possessive
          },
          detail: %{
            "default" => %{
              "nouns" => [attrs["name"]],
              "short" => attrs["cap_name"],
              "adjectives" => []
            }
          }
        }
    end
  end
end
